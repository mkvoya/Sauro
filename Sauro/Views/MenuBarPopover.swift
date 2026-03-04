import SwiftUI

struct MenuBarPopover: View {
    @Environment(PipelineCoordinator.self) private var coordinator
    @Environment(AppSettings.self) private var settings
    @State private var showingSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            StatusToggleView()

            Divider()

            if showingSettings {
                SettingsView()
            } else {
                RecentDetectionsView()
            }

            Divider()

            HStack {
                Button(showingSettings ? "Back" : "Settings") {
                    showingSettings.toggle()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(width: 320, height: 400)
    }
}
