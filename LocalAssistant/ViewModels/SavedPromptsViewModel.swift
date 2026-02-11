import AppKit
import Foundation
import Observation
import os

private let log = Logger(subsystem: "daniels.LocalAssistant", category: "SavedPromptsViewModel")

@MainActor
@Observable
final class SavedPromptsViewModel {
    private(set) var prompts: [SavedPrompt] = []
    var selectedPromptID: UUID?

    private let persistence: SavedPromptPersistence

    init(persistence: SavedPromptPersistence = SavedPromptPersistence()) {
        self.persistence = persistence
        self.prompts = persistence.loadAll()
        log.info("Init: loaded \(self.prompts.count) saved prompts")
    }

#if DEBUG
    init(previewPrompts: [SavedPrompt], selectedPromptID: UUID? = nil) {
        self.persistence = SavedPromptPersistence(
            directory: URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
                .appendingPathComponent("SavedPromptsPreview-\(UUID().uuidString)", isDirectory: true)
        )
        self.prompts = previewPrompts
        self.selectedPromptID = selectedPromptID ?? previewPrompts.first?.id
    }
#endif

    var sortedPrompts: [SavedPrompt] {
        prompts.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    var pinnedPrompts: [SavedPrompt] {
        sortedPrompts.filter(\.isPinned)
    }

    var unpinnedPrompts: [SavedPrompt] {
        sortedPrompts.filter { !$0.isPinned }
    }

    var selectedPrompt: SavedPrompt? {
        guard let id = selectedPromptID else { return nil }
        return prompts.first(where: { $0.id == id })
    }

    func addPrompt(title: String, content: String) {
        let prompt = SavedPrompt(title: title, content: content)
        prompts.insert(prompt, at: 0)
        persistence.save(prompt)
        selectedPromptID = prompt.id
        log.info("Added saved prompt: \(prompt.id)")
    }

    func updatePrompt(id: UUID, title: String, content: String) {
        guard let idx = prompts.firstIndex(where: { $0.id == id }) else { return }
        prompts[idx].title = title
        prompts[idx].content = content
        prompts[idx].updatedAt = .now
        persistence.save(prompts[idx])
        log.info("Updated saved prompt: \(id)")
    }

    func deletePrompt(id: UUID) {
        prompts.removeAll(where: { $0.id == id })
        persistence.delete(id: id)
        if selectedPromptID == id {
            selectedPromptID = nil
        }
        log.info("Deleted saved prompt: \(id)")
    }

    func togglePin(id: UUID) {
        guard let idx = prompts.firstIndex(where: { $0.id == id }) else { return }
        prompts[idx].isPinned.toggle()
        persistence.save(prompts[idx])
        log.info("Toggled pin for prompt \(id): \(self.prompts[idx].isPinned)")
    }

    func markUsed(id: UUID) {
        guard let idx = prompts.firstIndex(where: { $0.id == id }) else { return }
        prompts[idx].lastUsedAt = .now
        persistence.save(prompts[idx])
    }

    func copyToClipboard(id: UUID) {
        guard let prompt = prompts.first(where: { $0.id == id }) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(prompt.content, forType: .string)
        log.info("Copied prompt to clipboard: \(id)")
    }
}
