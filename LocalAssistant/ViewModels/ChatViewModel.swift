import Foundation
import Observation
import os

private let log = Logger(subsystem: "daniels.LocalAssistant", category: "ChatViewModel")

@MainActor
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
    private let summarizationService: SummarizationService
    private let summaryViewModel: SummaryViewModel

    private let recentMessageCount = 16
    private let summarizationThreshold = 40

    init(
        ollamaClient: OllamaClient,
        chatPersistence: ChatPersistence,
        summarizationService: SummarizationService,
        summaryViewModel: SummaryViewModel
    ) {
        self.ollamaClient = ollamaClient
        self.chatPersistence = chatPersistence
        self.summarizationService = summarizationService
        self.summaryViewModel = summaryViewModel

        self.conversations = chatPersistence.loadAll()
        self.selectedConversationID = conversations.first?.id
        log.info("Init: loaded \(self.conversations.count) conversations")
    }

    // MARK: - Conversation management

    func newConversation() {
        let conv = Conversation()
        conversations.insert(conv, at: 0)
        selectedConversationID = conv.id
        chatPersistence.save(conv)
        log.info("New conversation created: \(conv.id)")
    }

    func deleteConversation(id: UUID) {
        log.info("Deleting conversation: \(id)")
        conversations.removeAll(where: { $0.id == id })
        chatPersistence.delete(id: id)
        if selectedConversationID == id {
            selectedConversationID = conversations.first?.id
        }
    }

    // MARK: - Send

    func send() async {
        guard let idx = currentIndex else {
            log.warning("Send aborted: no conversation selected")
            return
        }
        let convID = conversations[idx].id
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            log.warning("Send aborted: empty input")
            return
        }

        log.info("Send started — conv: \(convID), input: \(text.prefix(60))")
        input = ""
        error = nil
        isLoading = true
        defer {
            isLoading = false
            log.info("Send finished — isLoading set to false")
        }

        // Build prompt before appending
        let summary = summarizationService.loadSummary()
        let recent = Array(conversations[idx].messages.suffix(recentMessageCount))
        let prompt = PromptBuilder.build(
            sessionSystemPrompt: sessionSystemPrompt,
            summary: summary,
            recentMessages: recent,
            newMessage: text
        )
        log.debug("Prompt built (\(prompt.count) chars)")

        // Append user message
        conversations[idx].messages.append(ChatMessage(role: "user", content: text))
        if conversations[idx].title == "New Conversation" {
            conversations[idx].title = String(text.prefix(50))
        }
        chatPersistence.save(conversations[idx])
        log.info("User message appended, conversation saved")

        // Placeholder for streaming
        let placeholderIndex = conversations[idx].messages.count
        conversations[idx].messages.append(ChatMessage(role: "assistant", content: ""))
        log.info("Assistant placeholder added at index \(placeholderIndex)")

        do {
            var accumulated = ""
            var tokenCount = 0
            log.info("Streaming started")
            try await ollamaClient.streamGenerate(prompt: prompt) { [weak self] token in
                guard let self else { return }
                accumulated += token
                tokenCount += 1
                guard let i = self.index(for: convID),
                      placeholderIndex < self.conversations[i].messages.count else {
                    log.warning("Token dropped: conversation index invalid")
                    return
                }
                self.conversations[i].messages[placeholderIndex] = ChatMessage(
                    id: self.conversations[i].messages[placeholderIndex].id,
                    role: "assistant",
                    content: accumulated
                )
            }
            log.info("Streaming complete — \(tokenCount) tokens, \(accumulated.count) chars")

            guard let i = index(for: convID) else {
                log.warning("Post-stream save skipped: conversation gone")
                return
            }
            chatPersistence.save(conversations[i])
            log.info("Conversation saved after streaming")
            await autoSummarizeIfNeeded(conversationID: convID)
        } catch {
            log.error("Streaming error: \(error.localizedDescription)")
            self.error = error.localizedDescription
            guard let i = index(for: convID) else { return }
            if placeholderIndex < conversations[i].messages.count,
               conversations[i].messages[placeholderIndex].content.isEmpty {
                conversations[i].messages.remove(at: placeholderIndex)
                log.info("Empty placeholder removed after error")
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
        log.info("System prompt applied (\(text.count) chars)")
    }

    func resetSessionSystemPrompt() {
        sessionSystemPrompt = ""
        log.info("System prompt reset")
    }

    // MARK: - Auto-summarization

    private func autoSummarizeIfNeeded(conversationID: UUID) async {
        guard let idx = index(for: conversationID),
              conversations[idx].messages.count > summarizationThreshold else {
            log.debug("Auto-summarize skipped: below threshold")
            return
        }

        let toSummarize = Array(conversations[idx].messages.dropLast(recentMessageCount))
        guard !toSummarize.isEmpty else { return }

        log.info("Auto-summarize started — \(toSummarize.count) messages to summarize")
        do {
            let summaryText = try await summarizationService.generateSummary(from: toSummarize)
            summarizationService.saveSummary(summaryText)

            guard let idx = index(for: conversationID) else { return }
            let summaryMessage = ChatMessage(role: "system", content: "Conversation summary:\n\(summaryText)")
            let kept = Array(conversations[idx].messages.suffix(recentMessageCount))
            conversations[idx].messages = [summaryMessage] + kept
            chatPersistence.save(conversations[idx])
            summaryViewModel.reload()
            log.info("Auto-summarize complete — kept \(kept.count) recent messages")
        } catch {
            log.error("Auto-summarize failed: \(error.localizedDescription)")
        }
    }
}
