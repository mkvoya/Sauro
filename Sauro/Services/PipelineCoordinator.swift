import Foundation
import os
import ApplicationServices

@MainActor
@Observable
final class PipelineCoordinator {
    private static let logger = Logger(subsystem: "cc.sauro", category: "Pipeline")

    let screenCapture = ScreenCaptureService()
    let ocrEngine = OCREngine()
    let calendarManager = CalendarManager()
    let notificationManager = NotificationManager()
    let deduplicator = EventDeduplicator()
    let ocrDeduplicator = OCRDeduplicator()
    let settings: AppSettings

    var isRunning = false
    var recentDetections: [DetectionRecord] = [] {
        didSet { saveRecentDetections() }
    }
    var lastError: String?

    private var pipelineTask: Task<Void, Never>?
    private var consecutiveFailures = 0
    private let maxBackoffSeconds: Double = 300
    private var dailyAPICallCount = 0
    private var dailyAPICallDate: Date?
    private static let detectionsFileURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Sauro", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("recent_detections.json")
    }()

    init(settings: AppSettings) {
        self.settings = settings
        self.recentDetections = Self.loadRecentDetections()
    }

    private static func loadRecentDetections() -> [DetectionRecord] {
        guard let data = try? Data(contentsOf: detectionsFileURL),
              let records = try? JSONDecoder().decode([DetectionRecord].self, from: data) else {
            return []
        }
        return records
    }

    private func saveRecentDetections() {
        guard let data = try? JSONEncoder().encode(recentDetections) else { return }
        try? data.write(to: Self.detectionsFileURL, options: .atomic)
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        lastError = nil

        pipelineTask = Task { [weak self] in
            guard let self else { return }

            do {
                try await self.calendarManager.requestAccess()
            } catch {
                self.lastError = error.localizedDescription
                self.pipelineLog("Calendar access failed: \(error.localizedDescription)", level: .error)
            }

            while !Task.isCancelled {
                if self.settings.isEnabled {
                    await self.runOnce()
                }
                let backoff = self.consecutiveFailures > 0
                    ? min(self.maxBackoffSeconds, Double(1 << min(self.consecutiveFailures, 8)))
                    : 0
                let sleepInterval = self.settings.captureInterval + backoff
                if backoff > 0 {
                    self.pipelineLog("Backing off for \(Int(backoff))s after \(self.consecutiveFailures) failures", level: .debug)
                }
                try? await Task.sleep(for: .seconds(sleepInterval))
            }
        }
    }

    func stop() {
        pipelineTask?.cancel()
        pipelineTask = nil
        isRunning = false
    }

    func undoRecord(withID recordID: UUID) async {
        guard let index = recentDetections.firstIndex(where: { $0.id == recordID }) else { return }
        let record = recentDetections[index]
        if let eventID = record.calendarEventIdentifier {
            do {
                try await calendarManager.deleteEvent(withIdentifier: eventID)
                recentDetections[index].status = .undone
                await deduplicator.remove(record.event)
                pipelineLog("Undid event: \(record.event.title)", level: .info)
            } catch {
                pipelineLog("Failed to undo event: \(error.localizedDescription)", level: .error)
            }
        }
    }

    func undoRecord(withIDString idString: String) async {
        guard let uuid = UUID(uuidString: idString) else { return }
        await undoRecord(withID: uuid)
    }

    func dismissRecord(withID recordID: UUID) async {
        guard let index = recentDetections.firstIndex(where: { $0.id == recordID }) else { return }
        let record = recentDetections[index]
        if let eventID = record.calendarEventIdentifier {
            try? await calendarManager.deleteEvent(withIdentifier: eventID)
        }
        recentDetections[index].status = .dismissed
        await deduplicator.markSeen(record.event)
        pipelineLog("Dismissed event: \(record.event.title)", level: .info)
    }

    private func makeLLMProvider() -> any LLMProvider {
        switch settings.llmProvider {
        case .ollama:
            return OllamaProvider(model: settings.ollamaModel)
        case .openAI:
            let baseURL = URL(string: settings.openAIBaseURL) ?? URL(string: "https://api.openai.com")!
            return OpenAIProvider(baseURL: baseURL, apiKey: settings.openAIAPIKey, model: settings.openAIModel)
        }
    }

    private func isScreenLocked() -> Bool {
        guard let dict = CGSessionCopyCurrentDictionary() as? [String: Any] else { return false }
        return dict["CGSSessionScreenIsLocked"] as? Bool ?? false
    }

    private func checkAndResetDailyCounter() {
        let today = Calendar.current.startOfDay(for: Date())
        if let lastDate = dailyAPICallDate, Calendar.current.isDate(lastDate, inSameDayAs: today) {
            return
        }
        dailyAPICallCount = 0
        dailyAPICallDate = today
    }

    private func runOnce() async {
        if settings.pauseWhenIdle && isScreenLocked() {
            pipelineLog("Screen locked, skipping cycle", level: .debug)
            return
        }

        do {
            let displayID = settings.selectedDisplayID
            if displayID > 0 {
                await screenCapture.setDisplayID(displayID)
            }

            pipelineLog("Capturing screen...", level: .debug)
            let image = try await screenCapture.captureScreen()

            pipelineLog("Running OCR...", level: .debug)
            let ocrText = try await ocrEngine.recognizeText(from: image)

            guard !ocrText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                pipelineLog("No text detected from OCR", level: .debug)
                return
            }

            let isStable = await ocrDeduplicator.isStable(ocrText)
            guard isStable else {
                pipelineLog("Screen still changing, waiting for stability...", level: .debug)
                return
            }

            let isDuplicateOCR = await ocrDeduplicator.isDuplicate(ocrText)
            await ocrDeduplicator.markSeen(ocrText)
            guard !isDuplicateOCR else {
                pipelineLog("OCR text unchanged, skipping LLM call", level: .debug)
                return
            }

            checkAndResetDailyCounter()
            guard dailyAPICallCount < settings.dailyAPICallLimit else {
                pipelineLog("Daily API call limit reached (\(settings.dailyAPICallLimit))", level: .info)
                return
            }

            let maxOCRLength = 4000
            let truncatedOCR = ocrText.count > maxOCRLength ? String(ocrText.prefix(maxOCRLength)) : ocrText

            let provider = makeLLMProvider()
            dailyAPICallCount += 1
            pipelineLog("Sending to LLM (\(truncatedOCR.count) chars, call #\(dailyAPICallCount) today)...", level: .debug)

            if settings.verboseLogging {
                pipelineLog("[OCR] \(truncatedOCR)", level: .debug)
            }

            let result = try await provider.extractEvents(
                from: truncatedOCR,
                referenceDate: Date()
            )

            if settings.verboseLogging {
                pipelineLog("[Prompt] \(result.promptSent)", level: .debug)
                pipelineLog("[LLM Response] \(result.rawResponse)", level: .debug)
            }

            let now = Date()
            let pastGraceWindow: TimeInterval = -300
            let maxFutureInterval: TimeInterval = 6 * 30 * 24 * 3600

            for var event in result.events {
                guard event.confidence >= settings.confidenceThreshold else {
                    pipelineLog("Event below threshold: \(event.title) (\(event.confidence))", level: .debug)
                    continue
                }

                if event.startDate.timeIntervalSince(now) < pastGraceWindow {
                    pipelineLog("Past event skipped: \(event.title) (\(event.startDate))", level: .debug)
                    continue
                }

                if event.startDate.timeIntervalSince(now) > maxFutureInterval {
                    pipelineLog("Far-future event skipped: \(event.title) (\(event.startDate))", level: .debug)
                    continue
                }

                event = event.sanitized()

                let isDuplicate = await deduplicator.isDuplicate(event)
                guard !isDuplicate else {
                    pipelineLog("Duplicate event skipped: \(event.title)", level: .debug)
                    continue
                }

                await deduplicator.markSeen(event)

                let eventID = try await calendarManager.addEvent(
                    event,
                    toCalendar: settings.targetCalendar
                )

                let record = DetectionRecord(
                    event: event,
                    status: .addedToCalendar,
                    calendarEventIdentifier: eventID
                )

                recentDetections.insert(record, at: 0)
                if recentDetections.count > 50 {
                    recentDetections.removeLast()
                }

                pipelineLog("Added event: \(event.title)", level: .info)

                try await notificationManager.postEventAddedNotification(
                    eventTitle: event.title,
                    eventIdentifier: eventID,
                    recordID: record.id.uuidString
                )
            }

            lastError = nil
            consecutiveFailures = 0
        } catch {
            consecutiveFailures += 1
            pipelineLog("Pipeline error: \(error.localizedDescription)", level: .error)
            lastError = error.localizedDescription
        }
    }

    private func pipelineLog(_ message: String, level: LogLevel) {
        switch level {
        case .debug:
            Self.logger.debug("\(message)")
        case .info:
            Self.logger.info("\(message)")
        case .error:
            Self.logger.error("\(message)")
        }
        AppLogger.shared.log(message, level: level, category: "Pipeline")
    }
}
