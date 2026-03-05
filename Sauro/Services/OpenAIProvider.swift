import Foundation

actor OpenAIProvider: LLMProvider {
    private let baseURL: URL
    private let apiKey: String
    private let model: String
    private let session: URLSession

    init(baseURL: URL, apiKey: String, model: String) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.model = model
        self.session = URLSession.shared
    }

    func extractEvents(from ocrText: String, referenceDate: Date) async throws -> LLMProviderResult {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss ZZZZZ"
        let currentDateString = dateFormatter.string(from: referenceDate)

        let systemPrompt = """
        You are a calendar event extraction assistant. Your job is to identify calendar events from OCR text captured from a screen.

        Current date and time: \(currentDateString)

        Rules:
        - Extract only clear calendar events (meetings, appointments, deadlines, etc.)
        - Each event must have at minimum a title and a start date/time
        - Resolve relative dates (e.g., "tomorrow", "next Monday") using the current date provided
        - Use ISO 8601 format for all dates (e.g., "2026-03-04T14:00:00")
        - Set confidence from 0.0 to 1.0 based on how certain you are this is a real event
        - If no events are found, return an empty events array
        - Do NOT fabricate events; only extract what is clearly present in the text
        """

        let userMessage = "Extract calendar events from the following OCR text:\n\n\(ocrText)"

        let messages = [
            OpenAIChatMessage(role: "system", content: systemPrompt),
            OpenAIChatMessage(role: "user", content: userMessage)
        ]

        let request = OpenAIChatRequest(
            model: model,
            messages: messages,
            responseFormat: OpenAIResponseFormat.eventExtraction
        )

        let url = baseURL.appendingPathComponent("v1/chat/completions")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.timeoutInterval = 120

        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw OpenAIError.requestFailed(statusCode: statusCode)
        }

        let chatResponse = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)

        guard let content = chatResponse.choices.first?.message.content,
              let contentData = content.data(using: .utf8) else {
            throw OpenAIError.invalidResponse
        }

        let result: LLMEventExtractionResult
        do {
            result = try JSONDecoder().decode(LLMEventExtractionResult.self, from: contentData)
        } catch {
            if let extracted = Self.extractJSONFromMarkdown(content),
               let fallbackData = extracted.data(using: .utf8) {
                result = try JSONDecoder().decode(LLMEventExtractionResult.self, from: fallbackData)
            } else {
                throw error
            }
        }
        let events = result.events.compactMap { parseExtractedEvent($0) }

        let promptSent = "[system] \(systemPrompt)\n\n[user] \(userMessage)"
        return LLMProviderResult(events: events, promptSent: promptSent, rawResponse: content)
    }

    private func parseExtractedEvent(_ extracted: LLMExtractedEvent) -> DetectedEvent? {
        guard let startDate = parseISO8601Date(extracted.startDate) else {
            return nil
        }

        let endDate = extracted.endDate.flatMap { parseISO8601Date($0) }

        return DetectedEvent(
            title: extracted.title,
            startDate: startDate,
            endDate: endDate,
            location: extracted.location,
            notes: extracted.notes,
            isAllDay: extracted.isAllDay ?? false,
            confidence: extracted.confidence
        )
    }

    private static func extractJSONFromMarkdown(_ text: String) -> String? {
        let pattern = "```(?:json)?\\s*\\n([\\s\\S]*?)\\n\\s*```"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[range])
    }

    private func parseISO8601Date(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: string) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) {
            return date
        }
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        return dateFormatter.date(from: string)
    }
}

enum OpenAIError: Error, LocalizedError {
    case requestFailed(statusCode: Int)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .requestFailed(let statusCode):
            return "OpenAI request failed with status code \(statusCode)"
        case .invalidResponse:
            return "Invalid response from OpenAI"
        }
    }
}
