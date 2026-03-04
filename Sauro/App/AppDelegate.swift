import AppKit
import UserNotifications
import os

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private static let logger = Logger(subsystem: "cc.sauro", category: "AppDelegate")
    private var coordinator: PipelineCoordinator?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)

        let notificationManager = NotificationManager()

        guard Bundle.main.bundleIdentifier != nil else {
            Self.logger.warning("Running without app bundle — notifications disabled.")
            return
        }

        UNUserNotificationCenter.current().delegate = self
        notificationManager.registerCategories()

        Task {
            try? await notificationManager.requestAuthorization()
        }
    }

    func setCoordinator(_ coordinator: PipelineCoordinator) {
        self.coordinator = coordinator
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping @Sendable () -> Void
    ) {
        if response.actionIdentifier == NotificationManager.undoActionIdentifier {
            let userInfo = response.notification.request.content.userInfo
            if let recordID = userInfo[NotificationManager.recordIDKey] as? String {
                Task { @MainActor [weak self] in
                    await self?.coordinator?.undoRecord(withIDString: recordID)
                }
            }
        }
        completionHandler()
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping @Sendable (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
