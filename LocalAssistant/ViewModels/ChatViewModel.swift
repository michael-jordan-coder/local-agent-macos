import Foundation
import Observation

@Observable
final class ChatViewModel {
    private(set) var conversations: [Conversation] = []
    var selectedConversationID: UUID?
    var input = ""
    private(set) var isLoading = false
    private(set) var error: String?

    // Session-only system prompt
    var sessionSystemPrompt: String = ""
    var isSystemPromptInspectorOpen: Bool = false

    var lastUserMessage: String? {
        guard let idx = currentIndex else { return nil }
        return conversations[idx].messages.last(where: { $0.role == "user" })?.content
    }

    var currentMessages: [ChatMessage] {
        guard let idx = currentIndex else { return [] }
        return conversations[idx].messages
    }

    private let ollamaClient: OllamaClient
    private let chatPersistence: ChatPersistence
    private let memoryPersistence: MemoryPersistence
    private let summarizationService: SummarizationService
    private let summaryViewModel: SummaryViewModel

    private let recentMessageCount = 16
    private let summarizationThreshold = 40

    init(
        ollamaClient: OllamaClient,
        chatPersistence: ChatPersistence,
        memoryPersistence: MemoryPersistence,
        summarizationService: SummarizationService,
        summaryViewModel: SummaryViewModel
    ) {
        self.ollamaClient = ollamaClient
        self.chatPersistence = chatPersistence
        self.memoryPersistence = memoryPersistence
        self.summarizationService = summarizationService
        self.summaryViewModel = summaryViewModel

        self.conversations = chatPersistence.loadAll()
        self.selectedConversationID = conversations.first?.id
    }

    // MARK: - Conversation management

    func newConversation() {
        let conv = Conversation()
        conversations.insert(conv, at: 0)
        selectedConversationID = conv.id
        chatPersistence.save(conv)
    }

    func deleteConversation(id: UUID) {
        conversations.removeAll(where: { $0.id == id })
        chatPersistence.delete(id: id)
        if selectedConversationID == id {
            selectedConversationID = conversations.first?.id
        }
    }

    // MARK: - Send

    func send() async {
        guard let idx = currentIndex else { return }
        let convID = conversations[idx].id
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        input = ""
        error = nil
        isLoading = true
        defer { isLoading = false }

        // Build prompt before appending
        let memory = memoryPersistence.load()
        let summary = summarizationService.loadSummary()
        let recent = Array(conversations[idx].messages.suffix(recentMessageCount))
        let prompt = PromptBuilder.build(
            sessionSystemPrompt: sessionSystemPrompt,
            memory: memory,
            summary: summary,
            recentMessages: recent,
            newMessage: text
        )

        // Append user message
        conversations[idx].messages.append(ChatMessage(role: "user", content: text))
        if conversations[idx].title == "New Conversation" {
            conversations[idx].title = String(text.prefix(50))
        }
        chatPersistence.save(conversations[idx])

        // Placeholder for streaming
        let placeholderIndex = conversations[idx].messages.count
        conversations[idx].messages.append(ChatMessage(role: "assistant", content: ""))

        do {
            var accumulated = ""
            try await ollamaClient.streamGenerate(prompt: prompt) { token in
                accumulated += token
                guard let i = self.index(for: convID) else { return }
                self.conversations[i].messages[placeholderIndex] = ChatMessage(
                    id: self.conversations[i].messages[placeholderIndex].id,
                    role: "assistant",
                    content: accumulated
                )
            }

            guard let i = index(for: convID) else { return }
            chatPersistence.save(conversations[i])
            await autoSummarizeIfNeeded(conversationID: convID)
        } catch {
            self.error = error.localizedDescription
            guard let i = index(for: convID) else { return }
            if conversations[i].messages[placeholderIndex].content.isEmpty {
                conversations[i].messages.remove(at: placeholderIndex)
            }
        }
    }

    // MARK: - Helpers

    private var currentIndex: Int? {
        index(for: selectedConversationID)
    }

    private func index(for id: UUID?) -> Int? {
        guard let id else { return nil }
        return conversations.firstIndex(where: { $0.id == id })
    }

    // MARK: - Session System Prompt

    func applySessionSystemPrompt(_ text: String) {
        sessionSystemPrompt = text
    }

    func resetSessionSystemPrompt() {
        sessionSystemPrompt = ""
    }

    // MARK: - Auto-summarization

    private func autoSummarizeIfNeeded(conversationID: UUID) async {
        guard let idx = index(for: conversationID),
              conversations[idx].messages.count > summarizationThreshold else { return }

        let toSummarize = Array(conversations[idx].messages.dropLast(recentMessageCount))
        guard !toSummarize.isEmpty else { return }

        do {
            let summaryText = try await summarizationService.generateSummary(from: toSummarize)
            summarizationService.saveSummary(summaryText)

            guard let idx = index(for: conversationID) else { return }
            let summaryMessage = ChatMessage(role: "system", content: "Conversation summary:\n\(summaryText)")
            let kept = Array(conversations[idx].messages.suffix(recentMessageCount))
            conversations[idx].messages = [summaryMessage] + kept
            chatPersistence.save(conversations[idx])
            summaryViewModel.reload()
        } catch {
            // Summarization failed silently
        }
    }
}
