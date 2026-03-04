import AppKit
import CoreGraphics

enum ScreenCaptureService {
    static func hasScreenRecordingPermission() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    static func requestScreenRecordingPermissionIfNeeded() -> Bool {
        if hasScreenRecordingPermission() { return true }
        return CGRequestScreenCaptureAccess()
    }

    static func captureFullScreen() -> CGImage? {
        CGWindowListCreateImage(
            .infinite,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution]
        )
    }
}
