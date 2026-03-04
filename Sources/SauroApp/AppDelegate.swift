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

        guard response.actionIdentifier == NotificationService.undoActionID else {
            return
        }

        if let eventIdentifier = response.notification.request.content.userInfo["eventIdentifier"] as? String {
            Task { @MainActor in
                coordinator?.undoCalendarEvent(eventIdentifier: eventIdentifier)
            }
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
