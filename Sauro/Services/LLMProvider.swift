import Foundation

protocol LLMProvider: Sendable {
    func extractEvents(from ocrText: String, referenceDate: Date) async throws -> [DetectedEvent]
}
