import Foundation

actor EventDeduplicator {
    private var seenKeys: [String: Date] = [:]
    private let ttl: TimeInterval

    init(ttl: TimeInterval = 86400) {
        self.ttl = ttl
    }

    func isDuplicate(_ event: DetectedEvent) -> Bool {
        cleanupExpired()
        return seenKeys[event.deduplicationKey] != nil
    }

    func markSeen(_ event: DetectedEvent) {
        cleanupExpired()
        seenKeys[event.deduplicationKey] = Date()
    }

    func remove(_ event: DetectedEvent) {
        seenKeys.removeValue(forKey: event.deduplicationKey)
    }

    func reset() {
        seenKeys.removeAll()
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
}
