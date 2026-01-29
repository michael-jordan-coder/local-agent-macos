import Foundation

enum PromptBuilder {
    static func build(
        sessionSystemPrompt: String,
        memory: LongTermMemory,
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
        Be concise, direct, and practical. \
        Use the user's context and memory below to give relevant answers.
        """
        parts.append(systemSection)

        // 2) Long-term memory
        let p = memory.userProfile
        parts.append("""
        [MEMORY]
        User: \(p.name) | Language: \(p.language) | Tone: \(p.tone)
        Facts: \(memory.facts.isEmpty ? "none" : memory.facts.joined(separator: "; "))
        Preferences: \(memory.preferences.isEmpty ? "none" : memory.preferences.joined(separator: "; "))
        """)

        // 3) Summary (if exists)
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
