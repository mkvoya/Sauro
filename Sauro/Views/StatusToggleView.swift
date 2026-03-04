import SwiftUI

struct StatusToggleView: View {
    @Environment(PipelineCoordinator.self) private var coordinator
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings

        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Sauro")
                    .font(.headline)

                if let error = coordinator.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(1)
                } else if coordinator.isRunning && settings.isEnabled {
                    Text("Monitoring screen...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Paused")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Toggle("", isOn: $settings.isEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
                .onChange(of: settings.isEnabled) { _, newValue in
                    if newValue && !coordinator.isRunning {
                        coordinator.start()
                    }
                }
        }
    }
}
