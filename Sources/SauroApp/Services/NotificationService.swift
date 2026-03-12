import Foundation
import UserNotifications

enum NotificationService {
    static let undoActionID = "UNDO_EVENT"
    static let addActionID = "ADD_EVENT"
    static let ignoreActionID = "IGNORE_EVENT"
    static let addedCategoryID = "EVENT_ADDED"
    static let detectedCategoryID = "EVENT_DETECTED"
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
        let addAction = UNNotificationAction(
            identifier: addActionID,
            title: "添加",
            options: [.foreground]
        )
        let ignoreAction = UNNotificationAction(
            identifier: ignoreActionID,
            title: "忽略",
            options: []
        )
        let addedCategory = UNNotificationCategory(
            identifier: addedCategoryID,
            actions: [undoAction],
            intentIdentifiers: [],
            options: []
        )
        let detectedCategory = UNNotificationCategory(
            identifier: detectedCategoryID,
            actions: [addAction, ignoreAction],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([addedCategory, detectedCategory])
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
        content.categoryIdentifier = addedCategoryID
        content.userInfo = eventUserInfo(for: event, extra: ["eventIdentifier": eventIdentifier])

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    static func sendDetectedNotification(for event: DetectedEvent) async {
        guard isSupportedInCurrentRuntime else { return }
        let content = UNMutableNotificationContent()
        content.title = "发现可能的新日程"
        content.body = event.title
        content.sound = .default
        content.categoryIdentifier = detectedCategoryID
        content.userInfo = eventUserInfo(for: event)

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    static func detectedEvent(from userInfo: [AnyHashable: Any]) -> DetectedEvent? {
        guard
            let title = userInfo["title"] as? String,
            let startISO8601 = userInfo["startISO8601"] as? String,
            let endISO8601 = userInfo["endISO8601"] as? String
        else {
            return nil
        }
        let location = userInfo["location"] as? String
        let notes = userInfo["notes"] as? String
        return DetectedEvent(title: title, startISO8601: startISO8601, endISO8601: endISO8601, location: location, notes: notes)
    }

    private static func eventUserInfo(for event: DetectedEvent, extra: [String: Any] = [:]) -> [AnyHashable: Any] {
        var info: [AnyHashable: Any] = [
            "title": event.title,
            "startISO8601": event.startISO8601,
            "endISO8601": event.endISO8601
        ]
        if let location = event.location { info["location"] = location }
        if let notes = event.notes { info["notes"] = notes }
        for (k, v) in extra {
            info[k] = v
        }
        return info
    }
}
