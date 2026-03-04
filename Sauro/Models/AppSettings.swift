import Foundation
import SwiftUI

@Observable
final class AppSettings: @unchecked Sendable {
    private static let ollamaModelKey = "ollamaModel"
    private static let captureIntervalKey = "captureInterval"
    private static let targetCalendarKey = "targetCalendar"
    private static let isEnabledKey = "isEnabled"
    private static let confidenceThresholdKey = "confidenceThreshold"

    var ollamaModel: String {
        didSet { UserDefaults.standard.set(ollamaModel, forKey: Self.ollamaModelKey) }
    }

    var captureInterval: TimeInterval {
        didSet { UserDefaults.standard.set(captureInterval, forKey: Self.captureIntervalKey) }
    }

    var targetCalendar: String? {
        didSet { UserDefaults.standard.set(targetCalendar, forKey: Self.targetCalendarKey) }
    }

    var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: Self.isEnabledKey) }
    }

    var confidenceThreshold: Double {
        didSet { UserDefaults.standard.set(confidenceThreshold, forKey: Self.confidenceThresholdKey) }
    }

    init() {
        let defaults = UserDefaults.standard
        self.ollamaModel = defaults.string(forKey: Self.ollamaModelKey) ?? "llama3.2"
        self.captureInterval = defaults.double(forKey: Self.captureIntervalKey).nonZero ?? 5.0
        self.targetCalendar = defaults.string(forKey: Self.targetCalendarKey)
        self.isEnabled = defaults.bool(forKey: Self.isEnabledKey)
        self.confidenceThreshold = defaults.double(forKey: Self.confidenceThresholdKey).nonZero ?? 0.7
    }
}

private extension Double {
    var nonZero: Double? {
        self == 0 ? nil : self
    }
}
