import Foundation

struct AppLog: Identifiable {
    let id = UUID()
    let time: Date
    let message: String
}
