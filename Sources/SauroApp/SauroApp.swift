import SwiftUI

@main
struct SauroApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var settings: AppSettings
    @StateObject private var coordinator: AppCoordinator

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        let appSettings = AppSettings()
        _settings = StateObject(wrappedValue: appSettings)
        _coordinator = StateObject(wrappedValue: AppCoordinator(settings: appSettings))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environmentObject(coordinator)
                .frame(minWidth: 760, minHeight: 520)
                .onAppear {
                    appDelegate.coordinator = coordinator
                    coordinator.initialize()
                }
        }
    }
}
