import Foundation

@MainActor
final class AppSettings: ObservableObject {
    enum Provider: String, CaseIterable, Identifiable {
        case openAICompatible = "openai_compatible"
        case ollama = "ollama"

        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .openAICompatible: return "OpenAI/兼容接口"
            case .ollama: return "Ollama 本地模型"
            }
        }
    }

    @Published var providerRawValue: String
    @Published var apiKey: String
    @Published var baseURL: String
    @Published var model: String
    @Published var directAddToCalendar: Bool

    private enum Keys {
        static let provider = "settings.provider"
        static let apiKey = "settings.apiKey"
        static let baseURL = "settings.baseURL"
        static let model = "settings.model"
        static let directAddToCalendar = "settings.directAddToCalendar"
    }

    init() {
        let defaults = UserDefaults.standard
        self.providerRawValue = defaults.string(forKey: Keys.provider) ?? Provider.openAICompatible.rawValue
        self.apiKey = defaults.string(forKey: Keys.apiKey) ?? ""
        self.baseURL = defaults.string(forKey: Keys.baseURL) ?? "https://api.openai.com/v1"
        self.model = defaults.string(forKey: Keys.model) ?? "gpt-4.1-mini"
        if defaults.object(forKey: Keys.directAddToCalendar) == nil {
            self.directAddToCalendar = true
        } else {
            self.directAddToCalendar = defaults.bool(forKey: Keys.directAddToCalendar)
        }
    }

    var provider: Provider {
        get { Provider(rawValue: providerRawValue) ?? .openAICompatible }
        set { providerRawValue = newValue.rawValue }
    }

    var hasRequiredFields: Bool {
        let hasBaseAndModel =
            !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        switch provider {
        case .openAICompatible:
            return hasBaseAndModel && !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .ollama:
            return hasBaseAndModel
        }
    }

    func save() {
        let defaults = UserDefaults.standard
        defaults.set(providerRawValue, forKey: Keys.provider)
        defaults.set(apiKey, forKey: Keys.apiKey)
        defaults.set(baseURL, forKey: Keys.baseURL)
        defaults.set(model, forKey: Keys.model)
        defaults.set(directAddToCalendar, forKey: Keys.directAddToCalendar)
    }
}
