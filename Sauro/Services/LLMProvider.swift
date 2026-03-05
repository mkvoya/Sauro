import Foundation

struct LLMProviderResult: Sendable {
    let events: [DetectedEvent]
    let promptSent: String
    let rawResponse: String
}

protocol LLMProvider: Sendable {
    func extractEvents(from ocrText: String, referenceDate: Date) async throws -> LLMProviderResult
}
