import Foundation
import CryptoKit

actor OCRDeduplicator {
    private var lastNormalizedText: String?
    private var lastStableText: String?
    private var consecutiveStableCount = 0

    private let similarityThreshold = 0.90
    private let requiredStableFrames = 2

    func isDuplicate(_ text: String) -> Bool {
        let normalized = normalize(text)
        guard let last = lastNormalizedText else { return false }
        return similarity(last, normalized) >= similarityThreshold
    }

    func markSeen(_ text: String) {
        lastNormalizedText = normalize(text)
    }

    /// Returns true when the screen content has been stable for enough consecutive frames.
    /// This prevents flooding the LLM when the user is scrolling.
    func isStable(_ text: String) -> Bool {
        let normalized = normalize(text)
        if let lastStable = lastStableText, similarity(lastStable, normalized) >= similarityThreshold {
            consecutiveStableCount += 1
        } else {
            consecutiveStableCount = 1
            lastStableText = normalized
        }
        return consecutiveStableCount >= requiredStableFrames
    }

    private func normalize(_ text: String) -> String {
        text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .lowercased()
    }

    private func similarity(_ a: String, _ b: String) -> Double {
        guard !a.isEmpty || !b.isEmpty else { return 1.0 }
        let maxLen = max(a.count, b.count)
        guard maxLen > 0 else { return 1.0 }

        let setA = bigrams(a)
        let setB = bigrams(b)

        guard !setA.isEmpty || !setB.isEmpty else {
            return a == b ? 1.0 : 0.0
        }

        let intersection = setA.intersection(setB).count
        let union = setA.union(setB).count
        return Double(intersection) / Double(union)
    }

    private func bigrams(_ text: String) -> Set<String> {
        guard text.count >= 2 else { return Set([text]) }
        var result = Set<String>()
        var idx = text.startIndex
        while idx < text.index(before: text.endIndex) {
            let next = text.index(after: idx)
            result.insert(String(text[idx...next]))
            idx = next
        }
        return result
    }
}
