@preconcurrency import ScreenCaptureKit
import CoreGraphics
import AppKit

struct DisplayInfo: Identifiable, Sendable {
    let id: CGDirectDisplayID
    let width: Int
    let height: Int

    var displayID: CGDirectDisplayID { id }
}

actor ScreenCaptureService {
    enum CaptureError: Error, LocalizedError {
        case noDisplayFound
        case captureFailure(String)
        case permissionDenied

        var errorDescription: String? {
            switch self {
            case .noDisplayFound:
                return "No display found for screen capture"
            case .captureFailure(let message):
                return "Screen capture failed: \(message)"
            case .permissionDenied:
                return "Screen recording permission not granted. Please enable it in System Settings > Privacy & Security > Screen Recording."
            }
        }
    }

    private var selectedDisplayID: CGDirectDisplayID?

    func setDisplayID(_ id: CGDirectDisplayID) {
        selectedDisplayID = id > 0 ? id : nil
    }

    func availableDisplays() async throws -> [DisplayInfo] {
        let content = try await SCShareableContent.current
        return content.displays.map { DisplayInfo(id: $0.displayID, width: $0.width, height: $0.height) }
    }

    func captureScreen() async throws -> CGImage {
        guard CGPreflightScreenCaptureAccess() else {
            CGRequestScreenCaptureAccess()
            throw CaptureError.permissionDenied
        }

        let content = try await SCShareableContent.current

        let display: SCDisplay
        if let selectedID = selectedDisplayID,
           let match = content.displays.first(where: { $0.displayID == selectedID }) {
            display = match
        } else {
            guard let first = content.displays.first else {
                throw CaptureError.noDisplayFound
            }
            display = first
        }

        let bundleID = Bundle.main.bundleIdentifier ?? "cc.sauro"
        let ownApps = content.applications.filter { $0.bundleIdentifier == bundleID }

        let filter = SCContentFilter(
            display: display,
            excludingApplications: ownApps,
            exceptingWindows: []
        )
        let configuration = SCStreamConfiguration()
        configuration.width = display.width
        configuration.height = display.height
        configuration.showsCursor = false

        let image = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: configuration
        )

        return image
    }
}
