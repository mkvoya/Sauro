import Foundation

struct OllamaChatRequest: Codable, Sendable {
    let model: String
    let messages: [OllamaChatMessage]
    let stream: Bool
    let format: OllamaFormat?

    init(model: String, messages: [OllamaChatMessage], stream: Bool = false, format: OllamaFormat? = nil) {
        self.model = model
        self.messages = messages
        self.stream = stream
        self.format = format
    }
}

struct OllamaChatMessage: Codable, Sendable {
    let role: String
    let content: String
}

struct OllamaFormat: Codable, Sendable {
    let type: String
    let properties: [String: OllamaFormatProperty]
    let required: [String]

    static var eventExtractionSchema: OllamaFormat {
        OllamaFormat(
            type: "object",
            properties: [
                "events": OllamaFormatProperty(
                    type: "array",
                    description: "Array of detected calendar events",
                    items: OllamaFormatItems(
                        type: "object",
                        properties: [
                            "title": OllamaFormatProperty(type: "string", description: "Event title"),
                            "start_date": OllamaFormatProperty(type: "string", description: "Start date/time in ISO 8601 format"),
                            "end_date": OllamaFormatProperty(type: "string", description: "End date/time in ISO 8601 format, or null"),
                            "location": OllamaFormatProperty(type: "string", description: "Event location, or null"),
                            "notes": OllamaFormatProperty(type: "string", description: "Additional notes, or null"),
                            "is_all_day": OllamaFormatProperty(type: "boolean", description: "Whether this is an all-day event"),
                            "confidence": OllamaFormatProperty(type: "number", description: "Confidence score from 0.0 to 1.0"),
                        ],
                        required: ["title", "start_date", "confidence"]
                    )
                )
            ],
            required: ["events"]
        )
    }
}

struct OllamaFormatProperty: Codable, Sendable {
    let type: String
    var description: String?
    var items: OllamaFormatItems?
}

struct OllamaFormatItems: Codable, Sendable {
    let type: String
    var properties: [String: OllamaFormatProperty]?
    var required: [String]?
}

struct OllamaChatResponse: Codable, Sendable {
    let model: String
    let message: OllamaChatMessage
    let done: Bool
}

struct LLMEventExtractionResult: Codable, Sendable {
    let events: [LLMExtractedEvent]
}

struct LLMExtractedEvent: Codable, Sendable {
    let title: String
    let startDate: String
    let endDate: String?
    let location: String?
    let notes: String?
    let isAllDay: Bool?
    let confidence: Double

    enum CodingKeys: String, CodingKey {
        case title
        case startDate = "start_date"
        case endDate = "end_date"
        case location
        case notes
        case isAllDay = "is_all_day"
        case confidence
    }
}
