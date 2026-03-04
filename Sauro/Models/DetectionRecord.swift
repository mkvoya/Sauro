import Foundation

enum DetectionStatus: String, Codable, Sendable {
    case detected
    case addedToCalendar
    case undone
    case dismissed
}

struct DetectionRecord: Identifiable, Sendable {
    let id: UUID
    let event: DetectedEvent
    var status: DetectionStatus
    let detectedAt: Date
    var calendarEventIdentifier: String?

    init(
        id: UUID = UUID(),
        event: DetectedEvent,
        status: DetectionStatus = .detected,
        detectedAt: Date = Date(),
        calendarEventIdentifier: String? = nil
    ) {
        self.id = id
        self.event = event
        self.status = status
        self.detectedAt = detectedAt
        self.calendarEventIdentifier = calendarEventIdentifier
    }
}
