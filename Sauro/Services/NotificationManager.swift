import UserNotifications
import os

final class NotificationManager: NSObject, Sendable {
    private static let logger = Logger(subsystem: "cc.sauro", category: "Notifications")

    static let categoryIdentifier = "EVENT_ADDED"
    static let undoActionIdentifier = "UNDO_EVENT"
    static let eventIdentifierKey = "eventIdentifier"
    static let recordIDKey = "recordID"

    private var isAvailable: Bool {
        Bundle.main.bundleIdentifier != nil
    }

    func registerCategories() {
        guard isAvailable else {
            Self.logger.warning("Notifications unavailable (no app bundle). Run as .app to enable.")
            return
        }

        let undoAction = UNNotificationAction(
            identifier: Self.undoActionIdentifier,
            title: "Undo Add",
            options: .destructive
        )

        let category = UNNotificationCategory(
            identifier: Self.categoryIdentifier,
            actions: [undoAction],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    func requestAuthorization() async throws {
        guard isAvailable else { return }
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    func postEventAddedNotification(
        eventTitle: String,
        eventIdentifier: String,
        recordID: String
    ) async throws {
        guard isAvailable else {
            Self.logger.info("Notification skipped (no app bundle): \(eventTitle)")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Event Added"
        content.body = "'\(eventTitle)' was added to your calendar."
        content.categoryIdentifier = Self.categoryIdentifier
        content.userInfo = [
            Self.eventIdentifierKey: eventIdentifier,
            Self.recordIDKey: recordID
        ]
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        try await UNUserNotificationCenter.current().add(request)
    }
}
