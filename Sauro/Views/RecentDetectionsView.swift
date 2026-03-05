import SwiftUI

struct RecentDetectionsView: View {
    @Environment(PipelineCoordinator.self) private var coordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Recent Detections")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if coordinator.recentDetections.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Text("No events detected yet")
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(coordinator.recentDetections) { record in
                            DetectionRowView(
                                record: record,
                                onUndo: {
                                    Task {
                                        await coordinator.undoRecord(withID: record.id)
                                    }
                                },
                                onDismiss: {
                                    Task {
                                        await coordinator.dismissRecord(withID: record.id)
                                    }
                                }
                            )
                        }
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
    }
}
