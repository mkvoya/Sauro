import Foundation
import EventKit

enum CalendarService {
    static let eventStore = EKEventStore()

    static func authorizationStatus() -> EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    static func requestAccess() async throws {
        if #available(macOS 14.0, *) {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                eventStore.requestFullAccessToEvents { granted, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if granted {
                        continuation.resume(returning: ())
                    } else {
                        continuation.resume(throwing: NSError(domain: "Calendar", code: 1, userInfo: [NSLocalizedDescriptionKey: "Calendar access denied."]))
                    }
                }
            }
        } else {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                eventStore.requestAccess(to: .event) { granted, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if granted {
                        continuation.resume(returning: ())
                    } else {
                        continuation.resume(throwing: NSError(domain: "Calendar", code: 1, userInfo: [NSLocalizedDescriptionKey: "Calendar access denied."]))
                    }
                }
            }
        }
    }

    static func addEvent(_ detected: DetectedEvent) throws -> String {
        guard let start = detected.startDate, let end = detected.endDate else {
            throw NSError(domain: "Calendar", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid event date."])
        }

        let event = EKEvent(eventStore: eventStore)
        event.title = detected.title
        event.startDate = start
        event.endDate = end
        event.location = detected.location
        event.notes = detected.notes
        event.calendar = eventStore.defaultCalendarForNewEvents

        try eventStore.save(event, span: .thisEvent)
        return event.eventIdentifier
    }

    static func removeEvent(eventIdentifier: String) throws {
        guard let event = eventStore.event(withIdentifier: eventIdentifier) else {
            return
        }
        try eventStore.remove(event, span: .thisEvent)
    }
}
