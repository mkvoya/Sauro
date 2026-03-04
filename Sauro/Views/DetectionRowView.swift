import SwiftUI

struct DetectionRowView: View {
    let record: DetectionRecord

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(record.event.title)
                    .font(.body)
                    .lineLimit(1)

                Text(formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            statusBadge
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: record.event.startDate)
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch record.status {
        case .detected:
            Text("Detected")
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.blue.opacity(0.15))
                .clipShape(Capsule())
        case .addedToCalendar:
            Text("Added")
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.green.opacity(0.15))
                .clipShape(Capsule())
        case .undone:
            Text("Undone")
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.orange.opacity(0.15))
                .clipShape(Capsule())
        case .dismissed:
            Text("Dismissed")
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.gray.opacity(0.15))
                .clipShape(Capsule())
        }
    }
}
