import Foundation

struct MemoryPersistence {
    private let fileURL: URL

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LocalAssistant")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("memory.json")
    }

    func load() -> LongTermMemory {
        guard let data = try? Data(contentsOf: fileURL) else { return .default }
        return (try? JSONDecoder().decode(LongTermMemory.self, from: data)) ?? .default
    }

    func save(_ memory: LongTermMemory) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(memory) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
