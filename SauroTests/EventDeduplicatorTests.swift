import Testing
import Foundation
@testable import Sauro

@Suite("EventDeduplicator Tests")
struct EventDeduplicatorTests {
    private func makeDeduplicator(ttl: TimeInterval = 86400) -> EventDeduplicator {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        return EventDeduplicator(ttl: ttl, persistURL: tempURL)
    }

    private func makeEvent(title: String = "Test Meeting", startDate: Date = Date()) -> DetectedEvent {
        DetectedEvent(title: title, startDate: startDate)
    }

    @Test("New event is not duplicate")
    func newEventIsNotDuplicate() async {
        let deduplicator = makeDeduplicator()
        let event = makeEvent()
        let isDuplicate = await deduplicator.isDuplicate(event)
        #expect(!isDuplicate)
    }

    @Test("Seen event is duplicate")
    func seenEventIsDuplicate() async {
        let deduplicator = makeDeduplicator()
        let event = makeEvent()
        await deduplicator.markSeen(event)
        let isDuplicate = await deduplicator.isDuplicate(event)
        #expect(isDuplicate)
    }

    @Test("Different events are not duplicates")
    func differentEventsNotDuplicate() async {
        let deduplicator = makeDeduplicator()
        let event1 = makeEvent(title: "Meeting A")
        let event2 = makeEvent(title: "Meeting B")
        await deduplicator.markSeen(event1)
        let isDuplicate = await deduplicator.isDuplicate(event2)
        #expect(!isDuplicate)
    }

    @Test("Same title different time is not duplicate")
    func sameTitleDifferentTimeNotDuplicate() async {
        let deduplicator = makeDeduplicator()
        let now = Date()
        let event1 = makeEvent(startDate: now)
        let event2 = makeEvent(startDate: now.addingTimeInterval(3600))
        await deduplicator.markSeen(event1)
        let isDuplicate = await deduplicator.isDuplicate(event2)
        #expect(!isDuplicate)
    }

    @Test("Remove makes event non-duplicate again")
    func removeAllowsRedetection() async {
        let deduplicator = makeDeduplicator()
        let event = makeEvent()
        await deduplicator.markSeen(event)
        await deduplicator.remove(event)
        let isDuplicate = await deduplicator.isDuplicate(event)
        #expect(!isDuplicate)
    }

    @Test("Reset clears all seen events")
    func resetClearsAll() async {
        let deduplicator = makeDeduplicator()
        await deduplicator.markSeen(makeEvent(title: "A"))
        await deduplicator.markSeen(makeEvent(title: "B"))
        await deduplicator.reset()
        let count = await deduplicator.seenCount
        #expect(count == 0)
    }

    @Test("Expired events are cleaned up")
    func ttlCleanup() async {
        let deduplicator = makeDeduplicator(ttl: 0.1)
        let event = makeEvent()
        await deduplicator.markSeen(event)

        try? await Task.sleep(for: .milliseconds(200))

        let isDuplicate = await deduplicator.isDuplicate(event)
        #expect(!isDuplicate)
    }

    @Test("Deduplication is case insensitive on title")
    func caseInsensitiveTitle() async {
        let deduplicator = makeDeduplicator()
        let now = Date()
        let event1 = makeEvent(title: "Team Meeting", startDate: now)
        let event2 = makeEvent(title: "team meeting", startDate: now)
        await deduplicator.markSeen(event1)
        let isDuplicate = await deduplicator.isDuplicate(event2)
        #expect(isDuplicate)
    }
}
