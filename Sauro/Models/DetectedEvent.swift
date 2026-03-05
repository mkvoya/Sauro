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

    func sanitized() -> DetectedEvent {
        var copy = self
        if copy.title.count > 200 {
            copy.title = String(copy.title.prefix(200))
        }
        if let notes = copy.notes, notes.count > 2000 {
            copy.notes = String(notes.prefix(2000))
        }
        if copy.isAllDay {
            copy.startDate = Calendar.current.startOfDay(for: copy.startDate)
            copy.endDate = copy.endDate.map { Calendar.current.startOfDay(for: $0).addingTimeInterval(86400) }
                ?? copy.startDate.addingTimeInterval(86400)
        }
        if let endDate = copy.endDate, endDate < copy.startDate {
            copy.endDate = nil
        }
        return copy
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
