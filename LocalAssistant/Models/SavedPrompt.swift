import Foundation

struct SavedPrompt: Codable, Identifiable, Hashable {
    let id: UUID
    var title: String
    var content: String
    let createdAt: Date
    var updatedAt: Date
    var lastUsedAt: Date?
    var isPinned: Bool

    init(
        id: UUID = UUID(),
        title: String,
        content: String,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        lastUsedAt: Date? = nil,
        isPinned: Bool = false
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastUsedAt = lastUsedAt
        self.isPinned = isPinned
    }

    // Backward-compatible decoding for existing prompts without updatedAt
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        content = try container.decode(String.self, forKey: .content)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        lastUsedAt = try container.decodeIfPresent(Date.self, forKey: .lastUsedAt)
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
    }
}
