import Foundation

struct ChatPersistence {
    private let directory: URL

    private var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    private var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = .prettyPrinted
        return e
    }

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LocalAssistant")
        directory = base.appendingPathComponent("conversations")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        migrateOldFormatIfNeeded(base: base)
    }

    func loadAll() -> [Conversation] {
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return []
        }
        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> Conversation? in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? decoder.decode(Conversation.self, from: data)
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func save(_ conversation: Conversation) {
        let url = directory.appendingPathComponent("\(conversation.id.uuidString).json")
        guard let data = try? encoder.encode(conversation) else { return }
        try? data.write(to: url, options: .atomic)
    }

    func delete(id: UUID) {
        let url = directory.appendingPathComponent("\(id.uuidString).json")
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Migration

    private func migrateOldFormatIfNeeded(base: URL) {
        let oldFile = base.appendingPathComponent("conversation.json")
        guard FileManager.default.fileExists(atPath: oldFile.path()) else { return }

        if let data = try? Data(contentsOf: oldFile),
           let messages = try? decoder.decode([ChatMessage].self, from: data),
           !messages.isEmpty {
            let title = messages.first(where: { $0.role == "user" })
                .map { String($0.content.prefix(50)) } ?? "Imported"
            let conv = Conversation(title: title, messages: messages)
            save(conv)
        }

        try? FileManager.default.removeItem(at: oldFile)
    }
}
