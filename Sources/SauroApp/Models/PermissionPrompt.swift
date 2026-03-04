import Foundation

struct PermissionPrompt: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let settingsURL: URL?
}
