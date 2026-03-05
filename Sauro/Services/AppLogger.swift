import Foundation

enum LogLevel: String, Sendable {
    case debug
    case info
    case error
}

struct LogEntry: Identifiable, Sendable {
    let id = UUID()
    let timestamp: Date
    let level: LogLevel
    let category: String
    let message: String
}

@MainActor
@Observable
final class AppLogger {
    static let shared = AppLogger()

    private(set) var entries: [LogEntry] = []
    private let maxEntries = 200

    private init() {}

    func log(_ message: String, level: LogLevel = .info, category: String = "General") {
        let entry = LogEntry(timestamp: Date(), level: level, category: category, message: message)
        entries.insert(entry, at: 0)
        if entries.count > maxEntries {
            entries.removeLast(entries.count - maxEntries)
        }
    }

    func clear() {
        entries.removeAll()
    }
}
