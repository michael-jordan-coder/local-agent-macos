import Foundation

struct SavedPromptPersistence {
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
        directory = base.appendingPathComponent("saved-prompts")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func loadAll() -> [SavedPrompt] {
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return []
        }
        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> SavedPrompt? in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? decoder.decode(SavedPrompt.self, from: data)
            }
            .sorted { ($0.lastUsedAt ?? $0.createdAt) > ($1.lastUsedAt ?? $1.createdAt) }
    }

    func save(_ prompt: SavedPrompt) {
        let url = directory.appendingPathComponent("\(prompt.id.uuidString).json")
        guard let data = try? encoder.encode(prompt) else { return }
        try? data.write(to: url, options: .atomic)
    }

    func delete(id: UUID) {
        let url = directory.appendingPathComponent("\(id.uuidString).json")
        try? FileManager.default.removeItem(at: url)
    }
}
