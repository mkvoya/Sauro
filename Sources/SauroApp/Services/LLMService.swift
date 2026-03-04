import Foundation

struct LLMService {
    struct ExtractionDebug {
        let requestJSON: String
        let responseText: String
        let endpoint: String
    }

    struct ExtractionResult {
        let events: [DetectedEvent]
        let debug: ExtractionDebug
    }

    struct Configuration {
        let apiKey: String
        let baseURL: String
        let model: String

        var normalizedAPIKey: String { apiKey.trimmingCharacters(in: .whitespacesAndNewlines) }
        var normalizedBaseURL: String { baseURL.trimmingCharacters(in: .whitespacesAndNewlines) }
        var normalizedModel: String { model.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    private struct ChatRequest: Encodable {
        struct Message: Encodable {
            let role: String
            let content: String
        }

        let model: String
        let temperature: Double
        let messages: [Message]
    }

    private struct ChatResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable {
                let content: String
            }
            let message: Message
        }
        let choices: [Choice]
    }

    func extractEvents(from fullText: String, configuration: Configuration, now: Date = .now) async throws -> ExtractionResult {
        let apiKey = configuration.normalizedAPIKey
        let model = configuration.normalizedModel
        guard !apiKey.isEmpty else {
            return ExtractionResult(
                events: [],
                debug: .init(requestJSON: "", responseText: "", endpoint: "")
            )
        }
        guard let endpointURL = chatCompletionURL(from: configuration.normalizedBaseURL) else {
            throw NSError(domain: "LLM", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid BASE_URL"])
        }

        let nowString = ISO8601DateFormatter.basic.string(from: now)
        let systemPrompt = """
        You extract NEW schedule items from OCR text from a user's macOS screen.
        Return ONLY valid JSON array, no markdown.
        Each item must match this schema:
        {"title":"string","startISO8601":"YYYY-MM-DDTHH:mm:ssZ","endISO8601":"YYYY-MM-DDTHH:mm:ssZ","location":"string|null","notes":"string|null"}

        Rules:
        - Only include events that are likely real schedules/meetings/deadlines/reminders.
        - Ignore past events unless clearly upcoming.
        - If no event, return []
        - Infer timezone from text; default to local timezone.
        - Ensure end time is after start time.
        """

        let userPrompt = """
        Current time: \(nowString)

        OCR text:
        \(fullText)
        """

        let payload = ChatRequest(
            model: model,
            temperature: 0.1,
            messages: [
                .init(role: "system", content: systemPrompt),
                .init(role: "user", content: userPrompt)
            ]
        )

        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(payload)
        let requestJSON = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""

        let (data, response) = try await URLSession.shared.data(for: request)
        let responseText = String(data: data, encoding: .utf8) ?? ""
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw NSError(domain: "LLM", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: responseText])
        }

        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content else {
            throw EventExtractionError.invalidResponse
        }

        let events: [DetectedEvent]
        if let jsonData = content.data(using: .utf8) {
            events = (try? JSONDecoder().decode([DetectedEvent].self, from: jsonData)) ?? []
        } else {
            events = []
        }
        return ExtractionResult(
            events: events,
            debug: .init(
                requestJSON: requestJSON,
                responseText: responseText,
                endpoint: endpointURL.absoluteString
            )
        )
    }

    private func chatCompletionURL(from baseURL: String) -> URL? {
        guard let base = URL(string: baseURL) else { return nil }
        return base.appending(path: "chat/completions")
    }
}
