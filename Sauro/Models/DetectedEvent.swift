import Foundation

struct DetectedEvent: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var title: String
    var startDate: Date
    var endDate: Date?
    var location: String?
    var notes: String?
    var isAllDay: Bool
    var confidence: Double

    var deduplicationKey: String {
        let dateString = ISO8601DateFormatter().string(from: startDate)
        return "\(title.lowercased())|\(dateString)"
    }

    init(
        id: UUID = UUID(),
        title: String,
        startDate: Date,
        endDate: Date? = nil,
        location: String? = nil,
        notes: String? = nil,
        isAllDay: Bool = false,
        confidence: Double = 1.0
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.location = location
        self.notes = notes
        self.isAllDay = isAllDay
        self.confidence = confidence
    }
}
