import Foundation

struct LLMService {
    struct ExtractionDebug {
        let requestJSON: String
        let responseText: String
        let endpoint: String
        let modelInputText: String
    }

    struct ExtractionResult {
        let events: [DetectedEvent]
        let debug: ExtractionDebug
    }

    struct Configuration {
        enum Provider {
            case openAICompatible
            case ollama
        }

        let provider: Provider
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

    private struct OllamaChatRequest: Encodable {
        struct Message: Encodable {
            let role: String
            let content: String
        }

        let model: String
        let messages: [Message]
        let stream: Bool
        let format: String
    }

    private struct OllamaChatResponse: Decodable {
        struct Message: Decodable {
            let role: String
            let content: String
        }

        let message: Message
    }

    func buildModelInputText(from fullText: String, now: Date) -> String {
        let nowString = ISO8601DateFormatter.basic.string(from: now)
        return """
        Current time: \(nowString)

        OCR text:
        \(fullText)
        """
    }

    func extractEvents(from fullText: String, configuration: Configuration, now: Date = .now) async throws -> ExtractionResult {
        let model = configuration.normalizedModel

        let userPrompt = buildModelInputText(from: fullText, now: now)
        let systemPrompt = """
        You extract NEW schedule/todo items from OCR text from a user's macOS screen.
        First, identify items the user is LIKELY INTERESTED IN adding to calendar/todo.
        Prioritize meetings, appointments, deadlines, reminders, and actionable tasks.
        Ignore irrelevant UI text, ads, boilerplate, random numbers, or low-confidence snippets.
        Return ONLY valid JSON array, no markdown.
        Each item must match this schema:
        {"title":"string","startISO8601":"YYYY-MM-DDTHH:mm:ssZ","endISO8601":"YYYY-MM-DDTHH:mm:ssZ","location":"string|null","notes":"string|null"}

        Rules:
        - Only include events that are likely real schedules/meetings/deadlines/reminders.
        - Ignore past events unless clearly upcoming.
        - If no event, return []
        - Infer timezone from text; default to local timezone.
        - Ensure end time is after start time.
        - If there is only a todo/deadline without explicit end time, set end to start + 30 minutes.
        """

        switch configuration.provider {
        case .openAICompatible:
            return try await extractViaOpenAICompatible(
                model: model,
                systemPrompt: systemPrompt,
                userPrompt: userPrompt,
                configuration: configuration
            )
        case .ollama:
            return try await extractViaOllama(
                model: model,
                systemPrompt: systemPrompt,
                userPrompt: userPrompt,
                configuration: configuration
            )
        }
    }

    private func chatCompletionURL(from baseURL: String) -> URL? {
        guard let base = URL(string: baseURL) else { return nil }
        return base.appending(path: "chat/completions")
    }

    private func ollamaChatURL(from baseURL: String) -> URL? {
        guard let base = URL(string: baseURL) else { return nil }
        return base.appending(path: "api/chat")
    }

    private func decodeEvents(from modelContent: String) -> [DetectedEvent] {
        guard let jsonData = modelContent.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([DetectedEvent].self, from: jsonData)) ?? []
    }

    private func extractViaOpenAICompatible(
        model: String,
        systemPrompt: String,
        userPrompt: String,
        configuration: Configuration
    ) async throws -> ExtractionResult {
        let apiKey = configuration.normalizedAPIKey
        guard !apiKey.isEmpty else {
            return ExtractionResult(events: [], debug: .init(requestJSON: "", responseText: "", endpoint: "", modelInputText: ""))
        }
        guard let endpointURL = chatCompletionURL(from: configuration.normalizedBaseURL) else {
            throw NSError(domain: "LLM", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid BASE_URL"])
        }

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

        return ExtractionResult(
            events: decodeEvents(from: content),
            debug: .init(requestJSON: requestJSON, responseText: responseText, endpoint: endpointURL.absoluteString, modelInputText: userPrompt)
        )
    }

    private func extractViaOllama(
        model: String,
        systemPrompt: String,
        userPrompt: String,
        configuration: Configuration
    ) async throws -> ExtractionResult {
        guard let endpointURL = ollamaChatURL(from: configuration.normalizedBaseURL) else {
            throw NSError(domain: "LLM", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid Ollama BASE_URL"])
        }

        let payload = OllamaChatRequest(
            model: model,
            messages: [
                .init(role: "system", content: systemPrompt),
                .init(role: "user", content: userPrompt)
            ],
            stream: false,
            format: "json"
        )
        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)
        let requestJSON = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""

        let (data, response) = try await URLSession.shared.data(for: request)
        let responseText = String(data: data, encoding: .utf8) ?? ""
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw NSError(domain: "LLM", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: responseText])
        }

        let decoded = try JSONDecoder().decode(OllamaChatResponse.self, from: data)
        return ExtractionResult(
            events: decodeEvents(from: decoded.message.content),
            debug: .init(requestJSON: requestJSON, responseText: responseText, endpoint: endpointURL.absoluteString, modelInputText: userPrompt)
        )
    }
}
