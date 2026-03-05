import SwiftUI

@main
struct SauroApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var settings = AppSettings()
    @State private var coordinator: PipelineCoordinator

    init() {
        let s = AppSettings()
        _settings = State(initialValue: s)
        _coordinator = State(initialValue: PipelineCoordinator(settings: s))
    }

    var body: some Scene {
        MenuBarExtra("Sauro", systemImage: "calendar.badge.clock") {
            MenuBarPopover()
                .environment(coordinator)
                .environment(settings)
                .task {
                    appDelegate.setCoordinator(coordinator)
                }
        }
        .menuBarExtraStyle(.window)
    }
}
