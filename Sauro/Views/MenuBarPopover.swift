import SwiftUI

struct MenuBarPopover: View {
    @Environment(PipelineCoordinator.self) private var coordinator
    @Environment(AppSettings.self) private var settings
    @State private var activePanel: PopoverPanel = .detections

    private enum PopoverPanel {
        case detections
        case settings
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            StatusToggleView()

            Divider()

            switch activePanel {
            case .detections:
                RecentDetectionsView()
            case .settings:
                SettingsView()
            }

            Divider()

            HStack {
                if activePanel == .detections {
                    Button("Settings") {
                        activePanel = .settings
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)

                    Button("Log") {
                        LogWindowController.shared.showWindow()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                } else {
                    Button("Back") {
                        activePanel = .detections
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(width: 320)
        .fixedSize(horizontal: false, vertical: true)
    }
}
