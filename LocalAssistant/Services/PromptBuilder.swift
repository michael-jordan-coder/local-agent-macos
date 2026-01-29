import Foundation

enum PromptBuilder {
    static func build(
        sessionSystemPrompt: String,
        summary: String,
        recentMessages: [ChatMessage],
        newMessage: String
    ) -> String {
        var parts: [String] = []

        // 1) System instruction
        var systemSection = "[SYSTEM]"
        if !sessionSystemPrompt.isEmpty {
            systemSection += "\n\(sessionSystemPrompt)\n"
        }
        systemSection += """

        You are a helpful personal assistant. Reply in English. \
        Be concise, direct, and practical.
        """
        parts.append(systemSection)

        // 2) Summary (if exists)
        if !summary.isEmpty {
            parts.append("[SUMMARY]\n\(summary)")
        }

        // 4) Recent conversation history
        if !recentMessages.isEmpty {
            let history = recentMessages.map { "\($0.role.uppercased()): \($0.content)" }
                .joined(separator: "\n")
            parts.append("[CONVERSATION]\n\(history)")
        }

        // 5) New user message
        parts.append("USER: \(newMessage)")

        return parts.joined(separator: "\n\n")
    }
}
