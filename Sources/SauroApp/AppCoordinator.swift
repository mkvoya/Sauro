import Foundation
import CryptoKit
import AppKit

@MainActor
final class AppCoordinator: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var logs: [AppLog] = []
    @Published var permissionPrompt: PermissionPrompt?
    @Published private(set) var latestOCRText: String = ""
    @Published private(set) var latestLLMRequest: String = ""
    @Published private(set) var latestLLMResponse: String = ""

    private var pollingTask: Task<Void, Never>?
    private let intervalSeconds: UInt64 = 5
    private let llm = LLMService()
    private let settings: AppSettings
    private var lastOCRHash: String?
    private var importedFingerprints = Set<String>()
    private var didLogMissingConfig = false
    private var didPromptScreenPermission = false
    private var isPresentingPermissionAlert = false

    init(settings: AppSettings) {
        self.settings = settings
    }

    func appendLog(_ message: String) {
        logs.insert(AppLog(time: .now, message: message), at: 0)
        if logs.count > 300 {
            logs.removeLast(logs.count - 300)
        }
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
            appendLog("已撤销日程: \(eventIdentifier)")
        } catch {
            appendLog("撤销失败: \(error.localizedDescription)")
        }
    }

    private func processOnce() async {
        let config = LLMService.Configuration(
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

        guard let image = ScreenCaptureService.captureFullScreen() else {
            if !ScreenCaptureService.hasScreenRecordingPermission() && !didPromptScreenPermission {
                didPromptScreenPermission = true
                presentPermissionPrompt(
                    title: "需要屏幕录制权限",
                    message: "请在系统设置中允许 Sauro 的“屏幕录制”，否则无法截图识别日程。",
                    settingsURL: URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
                )
            }
            appendLog("截屏失败。")
            return
        }

        do {
            let lines = try await OCRService.recognizeText(from: image)
            let combinedText = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            latestOCRText = combinedText
            guard !combinedText.isEmpty else {
                appendLog("OCR 未识别到文本。")
                return
            }

            let hash = SHA256.hash(data: Data(combinedText.utf8)).compactMap { String(format: "%02x", $0) }.joined()
            guard hash != lastOCRHash else {
                appendLog("屏幕文本无变化，跳过。")
                return
            }
            lastOCRHash = hash

            let extraction = try await llm.extractEvents(from: combinedText, configuration: config)
            latestLLMRequest = """
            POST \(extraction.debug.endpoint)
            Content-Type: application/json
            Authorization: Bearer [REDACTED]

            \(extraction.debug.requestJSON)
            """
            latestLLMResponse = extraction.debug.responseText

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

                do {
                    let eventIdentifier = try CalendarService.addEvent(event)
                    importedFingerprints.insert(event.fingerprint)
                    appendLog("已添加日程: \(event.title)")
                    await NotificationService.sendAddedNotification(for: event, eventIdentifier: eventIdentifier)
                } catch {
                    appendLog("添加日程失败: \(event.title), \(error.localizedDescription)")
                }
            }
        } catch {
            appendLog("处理失败: \(error.localizedDescription)")
        }
    }

    private func ensureScreenPermissionAtStart() -> Bool {
        if ScreenCaptureService.hasScreenRecordingPermission() {
            didPromptScreenPermission = false
            return true
        }
        let granted = ScreenCaptureService.requestScreenRecordingPermissionIfNeeded()
        if !granted {
            didPromptScreenPermission = true
            presentPermissionPrompt(
                title: "需要屏幕录制权限",
                message: "请在系统设置中允许 Sauro 的“屏幕录制”，然后回到应用点击“开始”。",
                settingsURL: URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
            )
            appendLog("缺少屏幕录制权限。")
            return false
        }
        didPromptScreenPermission = false
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
        showNativePermissionAlert(title: title, message: message, settingsURL: settingsURL)
    }

    private func showNativePermissionAlert(title: String, message: String, settingsURL: URL?) {
        guard !isPresentingPermissionAlert else { return }
        isPresentingPermissionAlert = true

        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = title
            alert.informativeText = message
            if settingsURL != nil {
                alert.addButton(withTitle: "去设置")
                alert.addButton(withTitle: "稍后")
            } else {
                alert.addButton(withTitle: "知道了")
            }

            let response = alert.runModal()
            if response == .alertFirstButtonReturn, let url = settingsURL {
                NSWorkspace.shared.open(url)
            }

            self.isPresentingPermissionAlert = false
        }
    }
}
