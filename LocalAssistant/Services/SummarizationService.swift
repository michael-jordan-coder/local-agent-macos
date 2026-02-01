import Foundation

struct SummarizationService {
    private let fileURL: URL
    private let ollamaClient: OllamaClient
    private let maxSummarizationChars = 16_000

    init(ollamaClient: OllamaClient) {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LocalAssistant")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("summary.txt")
        self.ollamaClient = ollamaClient
    }

    func loadSummary() -> String {
        (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
    }

    func saveSummary(_ summary: String) {
        try? summary.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    func clearSummary() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    func generateSummary(from messages: [ChatMessage]) async throws -> String {
        let text = messages.map { "\($0.role.uppercased()): \($0.content.trimmingCharacters(in: .whitespacesAndNewlines))" }
            .joined(separator: "\n")

        let truncated = text.count > maxSummarizationChars
            ? String(text.prefix(maxSummarizationChars))
            : text

        let prompt = """
        Summarize the following conversation in 12 bullet points or fewer. \
        Focus on user goals, decisions, preferences, and open tasks.

        \(truncated)
        """
        return try await ollamaClient.generate(prompt: prompt)
    }
}
