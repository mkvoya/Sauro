import Foundation
import SwiftUI

enum LLMProviderChoice: String, CaseIterable, Sendable {
    case ollama
    case openAI
}

@Observable
final class AppSettings: @unchecked Sendable {
    private static let ollamaModelKey = "ollamaModel"
    private static let captureIntervalKey = "captureInterval"
    private static let targetCalendarKey = "targetCalendar"
    private static let isEnabledKey = "isEnabled"
    private static let confidenceThresholdKey = "confidenceThreshold"
    private static let llmProviderKey = "llmProvider"
    private static let openAIBaseURLKey = "openAIBaseURL"
    private static let openAIAPIKeyKey = "openAIAPIKey"
    private static let openAIModelKey = "openAIModel"
    private static let verboseLoggingKey = "verboseLogging"
    private static let selectedDisplayIDKey = "selectedDisplayID"
    private static let dailyAPICallLimitKey = "dailyAPICallLimit"
    private static let pauseWhenIdleKey = "pauseWhenIdle"

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

    var llmProvider: LLMProviderChoice {
        didSet { UserDefaults.standard.set(llmProvider.rawValue, forKey: Self.llmProviderKey) }
    }

    var openAIBaseURL: String {
        didSet { UserDefaults.standard.set(openAIBaseURL, forKey: Self.openAIBaseURLKey) }
    }

    var openAIAPIKey: String {
        didSet { UserDefaults.standard.set(openAIAPIKey, forKey: Self.openAIAPIKeyKey) }
    }

    var openAIModel: String {
        didSet { UserDefaults.standard.set(openAIModel, forKey: Self.openAIModelKey) }
    }

    var verboseLogging: Bool {
        didSet { UserDefaults.standard.set(verboseLogging, forKey: Self.verboseLoggingKey) }
    }

    var selectedDisplayID: UInt32 {
        didSet { UserDefaults.standard.set(Int(selectedDisplayID), forKey: Self.selectedDisplayIDKey) }
    }

    var dailyAPICallLimit: Int {
        didSet { UserDefaults.standard.set(dailyAPICallLimit, forKey: Self.dailyAPICallLimitKey) }
    }

    var pauseWhenIdle: Bool {
        didSet { UserDefaults.standard.set(pauseWhenIdle, forKey: Self.pauseWhenIdleKey) }
    }

    init() {
        let defaults = UserDefaults.standard
        self.ollamaModel = defaults.string(forKey: Self.ollamaModelKey) ?? "llama3.2"
        self.captureInterval = defaults.double(forKey: Self.captureIntervalKey).nonZero ?? 5.0
        self.targetCalendar = defaults.string(forKey: Self.targetCalendarKey)
        self.isEnabled = defaults.bool(forKey: Self.isEnabledKey)
        self.confidenceThreshold = defaults.double(forKey: Self.confidenceThresholdKey).nonZero ?? 0.7
        self.llmProvider = LLMProviderChoice(rawValue: defaults.string(forKey: Self.llmProviderKey) ?? "") ?? .ollama
        self.openAIBaseURL = defaults.string(forKey: Self.openAIBaseURLKey) ?? "https://api.openai.com"
        self.openAIAPIKey = defaults.string(forKey: Self.openAIAPIKeyKey) ?? ""
        self.openAIModel = defaults.string(forKey: Self.openAIModelKey) ?? "gpt-4o-mini"
        self.verboseLogging = defaults.bool(forKey: Self.verboseLoggingKey)
        let storedDisplay = defaults.integer(forKey: Self.selectedDisplayIDKey)
        self.selectedDisplayID = storedDisplay > 0 ? UInt32(storedDisplay) : 0
        self.dailyAPICallLimit = defaults.integer(forKey: Self.dailyAPICallLimitKey).nonZeroInt ?? 200
        self.pauseWhenIdle = defaults.object(forKey: Self.pauseWhenIdleKey) as? Bool ?? true
    }
}

private extension Double {
    var nonZero: Double? {
        self == 0 ? nil : self
    }
}

private extension Int {
    var nonZeroInt: Int? {
        self == 0 ? nil : self
    }
}
