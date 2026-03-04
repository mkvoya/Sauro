import Foundation

@MainActor
final class AppSettings: ObservableObject {
    @Published var apiKey: String
    @Published var baseURL: String
    @Published var model: String

    private enum Keys {
        static let apiKey = "settings.apiKey"
        static let baseURL = "settings.baseURL"
        static let model = "settings.model"
    }

    init() {
        let defaults = UserDefaults.standard
        self.apiKey = defaults.string(forKey: Keys.apiKey) ?? ""
        self.baseURL = defaults.string(forKey: Keys.baseURL) ?? "https://api.openai.com/v1"
        self.model = defaults.string(forKey: Keys.model) ?? "gpt-4.1-mini"
    }

    var hasRequiredFields: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func save() {
        let defaults = UserDefaults.standard
        defaults.set(apiKey, forKey: Keys.apiKey)
        defaults.set(baseURL, forKey: Keys.baseURL)
        defaults.set(model, forKey: Keys.model)
    }
}
