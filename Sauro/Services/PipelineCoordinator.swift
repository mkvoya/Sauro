import Foundation
import os

@MainActor
@Observable
final class PipelineCoordinator {
    private static let logger = Logger(subsystem: "cc.sauro", category: "Pipeline")

    let screenCapture = ScreenCaptureService()
    let ocrEngine = OCREngine()
    let ollamaProvider = OllamaProvider()
    let calendarManager = CalendarManager()
    let notificationManager = NotificationManager()
    let deduplicator = EventDeduplicator()
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
                Self.logger.error("Calendar access failed: \(error.localizedDescription)")
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
                Self.logger.info("Undid event: \(record.event.title)")
            } catch {
                Self.logger.error("Failed to undo event: \(error.localizedDescription)")
            }
        }
    }

    func undoRecord(withIDString idString: String) async {
        guard let uuid = UUID(uuidString: idString) else { return }
        await undoRecord(withID: uuid)
    }

    private func runOnce() async {
        do {
            Self.logger.debug("Capturing screen...")
            let image = try await screenCapture.captureScreen()

            Self.logger.debug("Running OCR...")
            let ocrText = try await ocrEngine.recognizeText(from: image)

            guard !ocrText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                Self.logger.debug("No text detected from OCR")
                return
            }

            Self.logger.debug("Sending to LLM (\(ocrText.count) chars)...")
            let events = try await ollamaProvider.extractEvents(
                from: ocrText,
                referenceDate: Date(),
                model: settings.ollamaModel
            )

            for event in events {
                guard event.confidence >= settings.confidenceThreshold else {
                    Self.logger.debug("Event below threshold: \(event.title) (\(event.confidence))")
                    continue
                }

                let isDuplicate = await deduplicator.isDuplicate(event)
                guard !isDuplicate else {
                    Self.logger.debug("Duplicate event skipped: \(event.title)")
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

                Self.logger.info("Added event: \(event.title)")

                try await notificationManager.postEventAddedNotification(
                    eventTitle: event.title,
                    eventIdentifier: eventID,
                    recordID: record.id.uuidString
                )
            }

            lastError = nil
        } catch {
            Self.logger.error("Pipeline error: \(error.localizedDescription)")
            lastError = error.localizedDescription
        }
    }
}
