import Foundation

struct DetectedEvent: Codable, Hashable {
    let title: String
    let startISO8601: String
    let endISO8601: String
    let location: String?
    let notes: String?

    var startDate: Date? {
        ISO8601DateFormatter.withFractional.date(from: startISO8601)
            ?? ISO8601DateFormatter.basic.date(from: startISO8601)
    }

    var endDate: Date? {
        ISO8601DateFormatter.withFractional.date(from: endISO8601)
            ?? ISO8601DateFormatter.basic.date(from: endISO8601)
    }

    var fingerprint: String {
        [title.lowercased(), startISO8601, endISO8601, location ?? ""].joined(separator: "|")
    }
}

enum EventExtractionError: Error {
    case invalidResponse
}

extension ISO8601DateFormatter {
    static let withFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let basic: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
