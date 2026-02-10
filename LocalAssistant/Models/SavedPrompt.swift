import Foundation

struct SavedPrompt: Codable, Identifiable {
    let id: UUID
    var title: String
    var content: String
    let createdAt: Date
    var lastUsedAt: Date?
    var isPinned: Bool

    init(
        id: UUID = UUID(),
        title: String,
        content: String,
        createdAt: Date = .now,
        lastUsedAt: Date? = nil,
        isPinned: Bool = false
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        self.isPinned = isPinned
    }
}
