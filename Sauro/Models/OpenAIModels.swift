import Foundation

struct OpenAIChatRequest: Codable, Sendable {
    let model: String
    let messages: [OpenAIChatMessage]
    let responseFormat: OpenAIResponseFormat?

    enum CodingKeys: String, CodingKey {
        case model, messages
        case responseFormat = "response_format"
    }
}

struct OpenAIChatMessage: Codable, Sendable {
    let role: String
    let content: String
}

struct OpenAIChatResponse: Codable, Sendable {
    let choices: [OpenAIChoice]
}

struct OpenAIChoice: Codable, Sendable {
    let message: OpenAIChatMessage
}

struct OpenAIResponseFormat: Codable, Sendable {
    let type: String
    let jsonSchema: OpenAIJSONSchema?

    enum CodingKeys: String, CodingKey {
        case type
        case jsonSchema = "json_schema"
    }

    static var eventExtraction: OpenAIResponseFormat {
        OpenAIResponseFormat(
            type: "json_schema",
            jsonSchema: OpenAIJSONSchema(
                name: "event_extraction",
                strict: true,
                schema: OpenAISchemaDefinition(
                    type: "object",
                    properties: [
                        "events": OpenAISchemaProperty(
                            type: "array",
                            description: "Array of detected calendar events",
                            items: OpenAISchemaItems(
                                type: "object",
                                properties: [
                                    "title": OpenAISchemaProperty(type: "string", description: "Event title"),
                                    "start_date": OpenAISchemaProperty(type: "string", description: "Start date/time in ISO 8601 format"),
                                    "end_date": OpenAISchemaProperty(type: ["string", "null"], description: "End date/time in ISO 8601 format, or null"),
                                    "location": OpenAISchemaProperty(type: ["string", "null"], description: "Event location, or null"),
                                    "notes": OpenAISchemaProperty(type: ["string", "null"], description: "Additional notes, or null"),
                                    "is_all_day": OpenAISchemaProperty(type: "boolean", description: "Whether this is an all-day event"),
                                    "confidence": OpenAISchemaProperty(type: "number", description: "Confidence score from 0.0 to 1.0"),
                                ],
                                required: ["title", "start_date", "confidence", "end_date", "location", "notes", "is_all_day"],
                                additionalProperties: false
                            )
                        )
                    ],
                    required: ["events"],
                    additionalProperties: false
                )
            )
        )
    }
}

struct OpenAIJSONSchema: Codable, Sendable {
    let name: String
    let strict: Bool
    let schema: OpenAISchemaDefinition
}

struct OpenAISchemaDefinition: Codable, Sendable {
    let type: String
    let properties: [String: OpenAISchemaProperty]
    let required: [String]
    let additionalProperties: Bool
}

struct OpenAISchemaProperty: Codable, Sendable {
    let type: JSONSchemaType
    let description: String?
    let items: OpenAISchemaItems?

    init(type: JSONSchemaType, description: String? = nil, items: OpenAISchemaItems? = nil) {
        self.type = type
        self.description = description
        self.items = items
    }
}

enum JSONSchemaType: Codable, Sendable {
    case single(String)
    case multiple([String])

    init(_ value: String) { self = .single(value) }
    init(_ values: [String]) { self = .multiple(values) }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .single(let s): try container.encode(s)
        case .multiple(let a): try container.encode(a)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let s = try? container.decode(String.self) {
            self = .single(s)
        } else {
            self = .multiple(try container.decode([String].self))
        }
    }
}

extension JSONSchemaType: ExpressibleByStringLiteral {
    init(stringLiteral value: String) { self = .single(value) }
}

extension JSONSchemaType: ExpressibleByArrayLiteral {
    init(arrayLiteral elements: String...) { self = .multiple(elements) }
}

struct OpenAISchemaItems: Codable, Sendable {
    let type: String
    let properties: [String: OpenAISchemaProperty]?
    let required: [String]?
    let additionalProperties: Bool?
}
