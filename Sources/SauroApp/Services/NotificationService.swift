import Foundation
import UserNotifications

enum NotificationService {
    static let undoActionID = "UNDO_EVENT"
    static let categoryID = "EVENT_ADDED"
    static var isSupportedInCurrentRuntime: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    static func configureCategories() {
        guard isSupportedInCurrentRuntime else { return }
        let undoAction = UNNotificationAction(
            identifier: undoActionID,
            title: "撤销添加",
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: categoryID,
            actions: [undoAction],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    static func requestPermission() async throws {
        guard isSupportedInCurrentRuntime else { return }
        let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        if !granted {
            throw NSError(domain: "Notification", code: 1, userInfo: [NSLocalizedDescriptionKey: "Notification permission denied."])
        }
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        guard isSupportedInCurrentRuntime else { return .notDetermined }
        return await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus)
            }
        }
    }

    static func sendAddedNotification(for event: DetectedEvent, eventIdentifier: String) async {
        guard isSupportedInCurrentRuntime else { return }
        let content = UNMutableNotificationContent()
        content.title = "已添加新日程"
        content.body = "\(event.title) 已写入 Apple Calendar"
        content.sound = .default
        content.categoryIdentifier = categoryID
        content.userInfo = ["eventIdentifier": eventIdentifier]

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(request)
    }
}
