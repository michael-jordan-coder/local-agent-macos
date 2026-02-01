import Foundation

struct Conversation: Codable, Identifiable {
    let id: UUID
    var title: String
    var messages: [ChatMessage]
    let createdAt: Date
    var systemPrompt: String?

    init(id: UUID = UUID(), title: String = "New Conversation", messages: [ChatMessage] = [], createdAt: Date = .now, systemPrompt: String? = nil) {
        self.id = id
        self.title = title
        self.messages = messages
        self.createdAt = createdAt
        self.systemPrompt = systemPrompt
    }
}
