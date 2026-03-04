import EventKit

actor CalendarManager {
    private let eventStore = EKEventStore()

    enum CalendarError: Error, LocalizedError {
        case accessDenied
        case calendarNotFound
        case saveFailed(String)
        case deleteFailed(String)

        var errorDescription: String? {
            switch self {
            case .accessDenied:
                return "Calendar access was denied"
            case .calendarNotFound:
                return "Target calendar not found"
            case .saveFailed(let message):
                return "Failed to save event: \(message)"
            case .deleteFailed(let message):
                return "Failed to delete event: \(message)"
            }
        }
    }

    func requestAccess() async throws {
        let granted = try await eventStore.requestFullAccessToEvents()
        if !granted {
            throw CalendarError.accessDenied
        }
    }

    func availableCalendarTitles() -> [String] {
        eventStore.calendars(for: .event).map(\.title)
    }

    func addEvent(_ detectedEvent: DetectedEvent, toCalendar calendarTitle: String? = nil) async throws -> String {
        let ekEvent = EKEvent(eventStore: eventStore)
        ekEvent.title = detectedEvent.title
        ekEvent.startDate = detectedEvent.startDate
        ekEvent.endDate = detectedEvent.endDate ?? detectedEvent.startDate.addingTimeInterval(3600)
        ekEvent.location = detectedEvent.location
        ekEvent.notes = detectedEvent.notes
        ekEvent.isAllDay = detectedEvent.isAllDay

        if let calendarTitle {
            let calendars = eventStore.calendars(for: .event)
            if let target = calendars.first(where: { $0.title == calendarTitle }) {
                ekEvent.calendar = target
            } else {
                ekEvent.calendar = eventStore.defaultCalendarForNewEvents
            }
        } else {
            ekEvent.calendar = eventStore.defaultCalendarForNewEvents
        }

        do {
            try eventStore.save(ekEvent, span: .thisEvent)
            return ekEvent.eventIdentifier
        } catch {
            throw CalendarError.saveFailed(error.localizedDescription)
        }
    }

    func deleteEvent(withIdentifier identifier: String) async throws {
        guard let event = eventStore.event(withIdentifier: identifier) else {
            return
        }

        do {
            try eventStore.remove(event, span: .thisEvent)
        } catch {
            throw CalendarError.deleteFailed(error.localizedDescription)
        }
    }
}
