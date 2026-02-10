import Foundation

struct Conversation: Codable, Identifiable {
    let id: UUID
    var title: String
    var messages: [ChatMessage]
    let createdAt: Date
    var systemPrompt: String?
    var isPinned: Bool

    var lastActiveDate: Date {
        messages.last?.timestamp ?? createdAt
    }

    var messageCount: Int {
        messages.filter { $0.role == "user" || $0.role == "assistant" }.count
    }

    init(id: UUID = UUID(), title: String = "New Conversation", messages: [ChatMessage] = [], createdAt: Date = .now, systemPrompt: String? = nil, isPinned: Bool = false) {
        self.id = id
        self.title = title
        self.messages = messages
        self.createdAt = createdAt
        self.systemPrompt = systemPrompt
        self.isPinned = isPinned
    }

    // Backward-compatible decoding for existing conversations without isPinned
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        messages = try container.decode([ChatMessage].self, forKey: .messages)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        systemPrompt = try container.decodeIfPresent(String.self, forKey: .systemPrompt)
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
    }
}
