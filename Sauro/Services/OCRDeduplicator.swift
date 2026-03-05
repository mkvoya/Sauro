import Foundation
import CryptoKit

actor OCRDeduplicator {
    private var lastHash: String?

    func isDuplicate(_ text: String) -> Bool {
        let hash = sha256(text)
        return hash == lastHash
    }

    func markSeen(_ text: String) {
        lastHash = sha256(text)
    }

    private func sha256(_ text: String) -> String {
        let data = Data(text.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
