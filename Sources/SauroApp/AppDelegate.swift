import AppKit
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    weak var coordinator: AppCoordinator?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard NotificationService.isSupportedInCurrentRuntime else { return }
        UNUserNotificationCenter.current().delegate = self
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        defer { completionHandler() }

        let userInfo = response.notification.request.content.userInfo
        switch response.actionIdentifier {
        case NotificationService.undoActionID:
            if let eventIdentifier = userInfo["eventIdentifier"] as? String {
                Task { @MainActor in
                    coordinator?.undoCalendarEvent(eventIdentifier: eventIdentifier)
                }
            }
        case NotificationService.addActionID:
            if let event = NotificationService.detectedEvent(from: userInfo) {
                Task { @MainActor in
                    coordinator?.confirmAddEventFromNotification(event)
                }
            }
        case NotificationService.ignoreActionID:
            if let event = NotificationService.detectedEvent(from: userInfo) {
                Task { @MainActor in
                    coordinator?.ignoreEventFromNotification(event)
                }
            }
        default:
            break
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
