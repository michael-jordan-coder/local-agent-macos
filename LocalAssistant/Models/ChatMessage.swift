import Foundation

struct ChatMessage: Codable, Identifiable {
    let id: UUID
    let role: String
    let content: String
    let images: [Data]?
    let timestamp: Date
    let mentionPreview: String?

    init(id: UUID = UUID(), role: String, content: String, images: [Data]? = nil, timestamp: Date = .now, mentionPreview: String? = nil) {
        self.id = id
        self.role = role
        self.content = content
        self.images = images
        self.timestamp = timestamp
        self.mentionPreview = mentionPreview
    }
}
