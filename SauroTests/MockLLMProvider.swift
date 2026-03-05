import Foundation
@testable import Sauro

actor MockLLMProvider: LLMProvider {
    var eventsToReturn: [DetectedEvent] = []
    var errorToThrow: Error?
    var callCount = 0
    var lastOCRText: String?

    func setEvents(_ events: [DetectedEvent]) {
        eventsToReturn = events
    }

    func setError(_ error: Error?) {
        errorToThrow = error
    }

    func extractEvents(from ocrText: String, referenceDate: Date) async throws -> LLMProviderResult {
        callCount += 1
        lastOCRText = ocrText
        if let error = errorToThrow {
            throw error
        }
        return LLMProviderResult(events: eventsToReturn, promptSent: "", rawResponse: "")
    }
}
