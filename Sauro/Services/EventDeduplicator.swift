import Foundation

actor EventDeduplicator {
    private var seenKeys: [String: Date] = [:]
    private let ttl: TimeInterval
    private let fileURL: URL

    init(ttl: TimeInterval = 86400, persistURL: URL? = nil) {
        self.ttl = ttl
        if let url = persistURL {
            self.fileURL = url
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let dir = appSupport.appendingPathComponent("Sauro", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.fileURL = dir.appendingPathComponent("event_dedup.json")
        }
        self.seenKeys = Self.loadFromDisk(url: self.fileURL)
    }

    func isDuplicate(_ event: DetectedEvent) -> Bool {
        cleanupExpired()
        return seenKeys[event.deduplicationKey] != nil
    }

    func markSeen(_ event: DetectedEvent) {
        cleanupExpired()
        seenKeys[event.deduplicationKey] = Date()
        saveToDisk()
    }

    func remove(_ event: DetectedEvent) {
        seenKeys.removeValue(forKey: event.deduplicationKey)
        saveToDisk()
    }

    func reset() {
        seenKeys.removeAll()
        saveToDisk()
    }

    var seenCount: Int {
        seenKeys.count
    }

    private func cleanupExpired() {
        let now = Date()
        seenKeys = seenKeys.filter { _, timestamp in
            now.timeIntervalSince(timestamp) < ttl
        }
    }

    private func saveToDisk() {
        let mapped = seenKeys.mapValues { $0.timeIntervalSince1970 }
        guard let data = try? JSONEncoder().encode(mapped) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private static func loadFromDisk(url: URL) -> [String: Date] {
        guard let data = try? Data(contentsOf: url),
              let mapped = try? JSONDecoder().decode([String: Double].self, from: data) else {
            return [:]
        }
        return mapped.mapValues { Date(timeIntervalSince1970: $0) }
    }
}
