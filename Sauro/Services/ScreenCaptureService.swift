@preconcurrency import ScreenCaptureKit
import CoreGraphics
import AppKit

actor ScreenCaptureService {
    enum CaptureError: Error, LocalizedError {
        case noDisplayFound
        case captureFailure(String)

        var errorDescription: String? {
            switch self {
            case .noDisplayFound:
                return "No display found for screen capture"
            case .captureFailure(let message):
                return "Screen capture failed: \(message)"
            }
        }
    }

    func captureScreen() async throws -> CGImage {
        let content = try await SCShareableContent.current
        guard let display = content.displays.first else {
            throw CaptureError.noDisplayFound
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])
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
