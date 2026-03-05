import Foundation
import os

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
    var recentDetections: [DetectionRecord] = []
    var lastError: String?

    private var pipelineTask: Task<Void, Never>?

    init(settings: AppSettings) {
        self.settings = settings
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
                try? await Task.sleep(for: .seconds(self.settings.captureInterval))
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

    private func makeLLMProvider() -> any LLMProvider {
        switch settings.llmProvider {
        case .ollama:
            return OllamaProvider(model: settings.ollamaModel)
        case .openAI:
            let baseURL = URL(string: settings.openAIBaseURL) ?? URL(string: "https://api.openai.com")!
            return OpenAIProvider(baseURL: baseURL, apiKey: settings.openAIAPIKey, model: settings.openAIModel)
        }
    }

    private func runOnce() async {
        do {
            pipelineLog("Capturing screen...", level: .debug)
            let image = try await screenCapture.captureScreen()

            pipelineLog("Running OCR...", level: .debug)
            let ocrText = try await ocrEngine.recognizeText(from: image)

            guard !ocrText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                pipelineLog("No text detected from OCR", level: .debug)
                return
            }

            let isDuplicateOCR = await ocrDeduplicator.isDuplicate(ocrText)
            await ocrDeduplicator.markSeen(ocrText)
            guard !isDuplicateOCR else {
                pipelineLog("OCR text unchanged, skipping LLM call", level: .debug)
                return
            }

            let provider = makeLLMProvider()
            pipelineLog("Sending to LLM (\(ocrText.count) chars)...", level: .debug)

            if settings.verboseLogging {
                pipelineLog("[OCR] \(ocrText)", level: .debug)
            }

            let result = try await provider.extractEvents(
                from: ocrText,
                referenceDate: Date()
            )

            if settings.verboseLogging {
                pipelineLog("[Prompt] \(result.promptSent)", level: .debug)
                pipelineLog("[LLM Response] \(result.rawResponse)", level: .debug)
            }

            for event in result.events {
                guard event.confidence >= settings.confidenceThreshold else {
                    pipelineLog("Event below threshold: \(event.title) (\(event.confidence))", level: .debug)
                    continue
                }

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
        } catch {
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
