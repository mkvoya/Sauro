import Foundation
import CryptoKit

@MainActor
final class AppCoordinator: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var logs: [AppLog] = []
    @Published var permissionPrompt: PermissionPrompt?
    @Published private(set) var terminalLogText: String = ""

    private var pollingTask: Task<Void, Never>?
    private let intervalSeconds: UInt64 = 5
    private let llm = LLMService()
    private let settings: AppSettings
    private var lastOCRHash: String?
    private var importedFingerprints = Set<String>()
    private var processedOCRHashes: Set<String>
    private var blockedOCRHashes: Set<String>
    private var ignoredEventFingerprints: Set<String>
    private var eventSourceOCRHashByEventID: [String: String]
    private var pendingEventsByFingerprint: [String: DetectedEvent]
    private var didLogMissingConfig = false
    private var didLogScreenPermissionMissing = false

    private enum LocalStoreKeys {
        static let processedOCRHashes = "runtime.processedOCRHashes"
        static let blockedOCRHashes = "runtime.blockedOCRHashes"
        static let ignoredEventFingerprints = "runtime.ignoredEventFingerprints"
    }

    init(settings: AppSettings) {
        self.settings = settings
        let defaults = UserDefaults.standard
        self.processedOCRHashes = Set(defaults.stringArray(forKey: LocalStoreKeys.processedOCRHashes) ?? [])
        self.blockedOCRHashes = Set(defaults.stringArray(forKey: LocalStoreKeys.blockedOCRHashes) ?? [])
        self.ignoredEventFingerprints = Set(defaults.stringArray(forKey: LocalStoreKeys.ignoredEventFingerprints) ?? [])
        self.eventSourceOCRHashByEventID = [:]
        self.pendingEventsByFingerprint = [:]
    }

    func appendLog(_ message: String) {
        logs.insert(AppLog(time: .now, message: message), at: 0)
        if logs.count > 300 {
            logs.removeLast(logs.count - 300)
        }
        appendTerminalLine(message)
    }

    func clearTerminalLogs() {
        terminalLogText = ""
        appendLog("已清空实时日志。")
    }

    func initialize() {
        NotificationService.configureCategories()
        if !NotificationService.isSupportedInCurrentRuntime {
            appendLog("当前通过 swift run 启动，系统通知功能已自动禁用。")
        }
        appendLog("应用初始化完成。")
    }

    func start() {
        guard !isRunning else { return }
        guard settings.hasRequiredFields else {
            appendLog("请先在界面填写并保存 API Key / Base URL / Model。")
            return
        }

        guard ensureScreenPermissionAtStart() else { return }

        isRunning = true
        appendLog("开始监听屏幕，每 5 秒扫描一次。")

        pollingTask = Task { @MainActor in
            do {
                try await ensureCalendarPermission()
                try await ensureNotificationPermission()
                appendLog("权限检查通过。")
            } catch {
                appendLog("权限请求失败: \(error.localizedDescription)")
                await stop()
                return
            }

            while !Task.isCancelled {
                await processOnce()
                try? await Task.sleep(nanoseconds: intervalSeconds * 1_000_000_000)
            }
        }
    }

    func stop() async {
        pollingTask?.cancel()
        pollingTask = nil
        isRunning = false
        appendLog("已停止监听。")
    }

    func undoCalendarEvent(eventIdentifier: String) {
        do {
            try CalendarService.removeEvent(eventIdentifier: eventIdentifier)
            if let sourceHash = eventSourceOCRHashByEventID[eventIdentifier] {
                blockedOCRHashes.insert(sourceHash)
                persistHashSets()
                eventSourceOCRHashByEventID.removeValue(forKey: eventIdentifier)
            }
            appendLog("已撤销日程: \(eventIdentifier)")
        } catch {
            appendLog("撤销失败: \(error.localizedDescription)")
        }
    }

    func confirmAddEventFromNotification(_ event: DetectedEvent) {
        addEventAndNotify(event, sourceOCRHash: nil, reason: "用户确认添加")
    }

    func ignoreEventFromNotification(_ event: DetectedEvent) {
        ignoredEventFingerprints.insert(event.fingerprint)
        pendingEventsByFingerprint.removeValue(forKey: event.fingerprint)
        persistHashSets()
        appendLog("用户忽略事件：\(event.title)")
    }

    func clearOCRDedupCache() {
        processedOCRHashes.removeAll()
        blockedOCRHashes.removeAll()
        ignoredEventFingerprints.removeAll()
        lastOCRHash = nil
        eventSourceOCRHashByEventID.removeAll()
        pendingEventsByFingerprint.removeAll()
        persistHashSets()
        appendLog("已清空 OCR 去重缓存。")
    }

    private func processOnce() async {
        appendLog("轮询开始：准备执行截屏 -> OCR -> 日程识别。")
        let config = LLMService.Configuration(
            provider: settings.provider == .ollama ? .ollama : .openAICompatible,
            apiKey: settings.apiKey,
            baseURL: settings.baseURL,
            model: settings.model
        )
        if config.normalizedAPIKey.isEmpty || config.normalizedBaseURL.isEmpty || config.normalizedModel.isEmpty {
            if !didLogMissingConfig {
                appendLog("LLM 配置为空，暂停本轮识别。")
                didLogMissingConfig = true
            }
            return
        }
        didLogMissingConfig = false
        appendLog("当前模型通道：\(settings.provider.displayName)，模型：\(config.normalizedModel)")

        appendLog("开始截屏。")
        guard let image = ScreenCaptureService.captureFullScreen() else {
            if !ScreenCaptureService.hasScreenRecordingPermission() && !didLogScreenPermissionMissing {
                didLogScreenPermissionMissing = true
                appendLog("缺少屏幕录制权限，请在系统设置中授权后重试。")
            }
            appendLog("截屏失败。")
            return
        }
        didLogScreenPermissionMissing = false
        appendLog("截屏成功，开始 OCR。")

        do {
            let lines = try await OCRService.recognizeText(from: image)
            let combinedText = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !combinedText.isEmpty else {
                appendLog("OCR 未识别到文本。")
                return
            }
            appendLog("OCR 完成，文本如下：\n\(combinedText)")

            let filteredText = filterTextForLLM(from: lines)
            guard !filteredText.isEmpty else {
                appendLog("过滤后无有效候选文本，跳过。")
                return
            }
            appendLog("过滤后候选文本如下：\n\(filteredText)")

            let hash = SHA256.hash(data: Data(combinedText.utf8)).compactMap { String(format: "%02x", $0) }.joined()
            guard hash != lastOCRHash else {
                appendLog("屏幕文本无变化，跳过。")
                return
            }
            lastOCRHash = hash
            if blockedOCRHashes.contains(hash) {
                appendLog("该 OCR 内容对应已撤销日程，跳过。")
                return
            }
            if processedOCRHashes.contains(hash) {
                appendLog("该 OCR 内容已处理过，跳过。")
                return
            }
            processedOCRHashes.insert(hash)
            persistHashSets()

            let llmNow = Date()
            let modelInputText = llm.buildModelInputText(from: filteredText, now: llmNow)
            appendLog("要发给大模型的文本如下：\n\(modelInputText)")
            appendLog("发送文本给大模型进行日程提取。")
            let extraction = try await llm.extractEvents(from: filteredText, configuration: config, now: llmNow)
            appendLog("大模型返回如下：\n\(extraction.debug.responseText)")

            if extraction.events.isEmpty {
                appendLog("未发现新日程。")
                return
            }

            for event in extraction.events {
                guard let start = event.startDate, let end = event.endDate, end > start else {
                    appendLog("跳过非法时间事件: \(event.title)")
                    continue
                }

                if importedFingerprints.contains(event.fingerprint) {
                    appendLog("重复事件跳过: \(event.title)")
                    continue
                }
                if ignoredEventFingerprints.contains(event.fingerprint) {
                    appendLog("该事件此前已被用户忽略，跳过: \(event.title)")
                    continue
                }
                if pendingEventsByFingerprint[event.fingerprint] != nil {
                    appendLog("该事件已在待确认通知中，跳过: \(event.title)")
                    continue
                }

                if settings.directAddToCalendar {
                    addEventAndNotify(event, sourceOCRHash: hash, reason: "自动添加")
                } else {
                    pendingEventsByFingerprint[event.fingerprint] = event
                    appendLog("发现候选日程，等待用户确认: \(event.title)")
                    await NotificationService.sendDetectedNotification(for: event)
                }
            }
        } catch {
            appendLog("处理失败: \(error.localizedDescription)")
        }
    }

    private func ensureScreenPermissionAtStart() -> Bool {
        if ScreenCaptureService.hasScreenRecordingPermission() {
            didLogScreenPermissionMissing = false
            return true
        }
        let granted = ScreenCaptureService.requestScreenRecordingPermissionIfNeeded()
        if !granted {
            appendLog("缺少屏幕录制权限。")
            return false
        }
        didLogScreenPermissionMissing = false
        return true
    }

    private func ensureCalendarPermission() async throws {
        switch CalendarService.authorizationStatus() {
        case .fullAccess, .writeOnly:
            return
        case .notDetermined:
            do {
                try await CalendarService.requestAccess()
            } catch {
                presentPermissionPrompt(
                    title: "需要日历权限",
                    message: "请在系统设置中允许 Sauro 访问“日历”，否则无法自动写入 Apple Calendar。",
                    settingsURL: URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")
                )
                throw error
            }
        case .denied, .restricted:
            presentPermissionPrompt(
                title: "需要日历权限",
                message: "请在系统设置中允许 Sauro 访问“日历”，否则无法自动写入 Apple Calendar。",
                settingsURL: URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")
            )
            throw NSError(domain: "Calendar", code: 1, userInfo: [NSLocalizedDescriptionKey: "Calendar access denied."])
        @unknown default:
            throw NSError(domain: "Calendar", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unknown calendar authorization status."])
        }
    }

    private func ensureNotificationPermission() async throws {
        guard NotificationService.isSupportedInCurrentRuntime else { return }

        let current = await NotificationService.authorizationStatus()
        switch current {
        case .authorized, .provisional, .ephemeral:
            return
        case .notDetermined:
            do {
                try await NotificationService.requestPermission()
            } catch {
                presentPermissionPrompt(
                    title: "需要通知权限",
                    message: "请在系统设置中允许 Sauro 通知，才能显示“已添加日程 / 撤销添加”提醒。",
                    settingsURL: URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")
                )
                throw error
            }
        case .denied:
            presentPermissionPrompt(
                title: "需要通知权限",
                message: "请在系统设置中允许 Sauro 通知，才能显示“已添加日程 / 撤销添加”提醒。",
                settingsURL: URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")
            )
            throw NSError(domain: "Notification", code: 1, userInfo: [NSLocalizedDescriptionKey: "Notification permission denied."])
        @unknown default:
            throw NSError(domain: "Notification", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unknown notification authorization status."])
        }
    }

    private func presentPermissionPrompt(title: String, message: String, settingsURL: URL?) {
        permissionPrompt = PermissionPrompt(title: title, message: message, settingsURL: settingsURL)
    }

    private func persistHashSets() {
        let defaults = UserDefaults.standard
        defaults.set(Array(processedOCRHashes), forKey: LocalStoreKeys.processedOCRHashes)
        defaults.set(Array(blockedOCRHashes), forKey: LocalStoreKeys.blockedOCRHashes)
        defaults.set(Array(ignoredEventFingerprints), forKey: LocalStoreKeys.ignoredEventFingerprints)
    }

    private func addEventAndNotify(_ event: DetectedEvent, sourceOCRHash: String?, reason: String) {
        guard let start = event.startDate, let end = event.endDate, end > start else {
            appendLog("添加失败，事件时间不合法: \(event.title)")
            return
        }
        if importedFingerprints.contains(event.fingerprint) {
            appendLog("重复事件跳过: \(event.title)")
            pendingEventsByFingerprint.removeValue(forKey: event.fingerprint)
            return
        }
        do {
            let eventIdentifier = try CalendarService.addEvent(event)
            importedFingerprints.insert(event.fingerprint)
            pendingEventsByFingerprint.removeValue(forKey: event.fingerprint)
            if let sourceOCRHash {
                eventSourceOCRHashByEventID[eventIdentifier] = sourceOCRHash
            }
            appendLog("\(reason)成功，已添加日程: \(event.title)")
            Task {
                await NotificationService.sendAddedNotification(for: event, eventIdentifier: eventIdentifier)
            }
        } catch {
            appendLog("添加日程失败: \(event.title), \(error.localizedDescription)")
        }
    }

    private func appendTerminalLine(_ message: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        let timestamp = formatter.string(from: Date())
        terminalLogText += "[\(timestamp)] \(message)\n"
        if terminalLogText.count > 200_000 {
            terminalLogText = String(terminalLogText.suffix(200_000))
        }
    }

    private func filterTextForLLM(from lines: [String]) -> String {
        let keywords = [
            "会议", "开会", "日程", "提醒", "截止", "ddl", "due", "meeting", "schedule",
            "tomorrow", "today", "pm", "am", "任务", "todo", "appointment", "call"
        ]
        let filtered = lines.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { line in
            if line.isEmpty { return false }
            if line.count < 3 { return false }
            let lower = line.lowercased()
            let hasKeyword = keywords.contains { lower.contains($0) }
            let hasTimeHint = lower.range(of: #"\b\d{1,2}[:：]\d{2}\b"#, options: .regularExpression) != nil
                || lower.range(of: #"\b\d{1,2}\s?(am|pm)\b"#, options: .regularExpression) != nil
                || lower.range(of: #"\b\d{4}-\d{1,2}-\d{1,2}\b"#, options: .regularExpression) != nil
                || lower.range(of: #"\b\d{1,2}/\d{1,2}\b"#, options: .regularExpression) != nil
            return hasKeyword || hasTimeHint
        }
        return filtered.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
