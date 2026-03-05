import SwiftUI
import AppKit

@MainActor
final class LogWindowController {
    static let shared = LogWindowController()

    private var window: NSWindow?

    private init() {}

    func showWindow() {
        if let window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let hostingView = NSHostingView(rootView: LogWindowContent())
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 400),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Sauro Log"
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("SauroLogWindow")
        window.makeKeyAndOrderFront(nil)
        // Bring app to front so the window is visible
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }
}

private struct LogWindowContent: View {
    private let logger = AppLogger.shared

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(logger.entries.count) entries")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
                Button("Clear") {
                    logger.clear()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(8)

            Divider()

            if logger.entries.isEmpty {
                Spacer()
                Text("No log entries yet")
                    .foregroundStyle(.tertiary)
                    .font(.caption)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(logger.entries) { entry in
                            LogEntryRow(entry: entry)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

private struct LogEntryRow: View {
    let entry: LogEntry

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text(entry.timestamp, format: .dateTime.hour().minute().second())
                .foregroundStyle(.tertiary)

            Text(entry.level.rawValue.uppercased())
                .foregroundStyle(levelColor)
                .frame(width: 40, alignment: .leading)

            Text(entry.message)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
        }
        .font(.system(size: 11, design: .monospaced))
    }

    private var levelColor: Color {
        switch entry.level {
        case .debug: .secondary
        case .info: .blue
        case .error: .red
        }
    }
}
