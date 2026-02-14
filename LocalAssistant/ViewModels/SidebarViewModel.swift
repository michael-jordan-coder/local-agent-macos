import SwiftUI

@Observable
final class SidebarViewModel {

    // MARK: - Dependencies (internal)

    private let chatVM: ChatViewModel
    let savedPromptsVM: SavedPromptsViewModel

    // MARK: - Sidebar State

    var sidebarTab: SidebarTab = .chats
    var searchText = ""
    var renamingConversationID: UUID?
    var renameText = ""

    @ObservationIgnored
    @AppStorage("selectedModel") var selectedModel: String = "gpt-oss:20b-cloud"

    /// Fired when a conversation's "View System Prompt" context action is triggered.
    var onRequestInspector: (() -> Void)?

    // MARK: - Init

    init(chatVM: ChatViewModel, savedPromptsVM: SavedPromptsViewModel) {
        self.chatVM = chatVM
        self.savedPromptsVM = savedPromptsVM
    }

    // MARK: - Conversations (read-only projections)

    var conversations: [Conversation] {
        chatVM.conversations
    }

    var selectedConversationID: UUID? {
        get { chatVM.selectedConversationID }
        set { chatVM.selectedConversationID = newValue }
    }

    var hasConversations: Bool {
        !chatVM.conversations.isEmpty
    }

    var filteredConversations: [Conversation] {
        let base = searchText.isEmpty
            ? conversations
            : conversations.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        return base.sorted { $0.lastActiveDate > $1.lastActiveDate }
    }

    var pinnedConversations: [Conversation] {
        filteredConversations.filter(\.isPinned)
    }

    var unpinnedConversations: [Conversation] {
        filteredConversations.filter { !$0.isPinned }
    }

    var groupedSections: [DateSection] {
        let calendar = Calendar.current
        let now = Date.now
        let startOfToday = calendar.startOfDay(for: now)
        let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday)!
        let startOfWeek = calendar.date(byAdding: .day, value: -7, to: startOfToday)!
        let startOfMonth = calendar.date(byAdding: .day, value: -30, to: startOfToday)!

        var today: [Conversation] = []
        var yesterday: [Conversation] = []
        var week: [Conversation] = []
        var month: [Conversation] = []
        var older: [Conversation] = []

        for conv in unpinnedConversations {
            let date = conv.lastActiveDate
            if date >= startOfToday {
                today.append(conv)
            } else if date >= startOfYesterday {
                yesterday.append(conv)
            } else if date >= startOfWeek {
                week.append(conv)
            } else if date >= startOfMonth {
                month.append(conv)
            } else {
                older.append(conv)
            }
        }

        var sections: [DateSection] = []
        if !today.isEmpty { sections.append(DateSection(name: "Today", conversations: today)) }
        if !yesterday.isEmpty { sections.append(DateSection(name: "Yesterday", conversations: yesterday)) }
        if !week.isEmpty { sections.append(DateSection(name: "Previous 7 Days", conversations: week)) }
        if !month.isEmpty { sections.append(DateSection(name: "Previous 30 Days", conversations: month)) }
        if !older.isEmpty { sections.append(DateSection(name: "Older", conversations: older)) }
        return sections
    }

    // MARK: - Rename

    var isRenaming: Bool {
        renamingConversationID != nil
    }

    func beginRename(for conversation: Conversation) {
        renameText = conversation.title
        renamingConversationID = conversation.id
    }

    func commitRename() {
        guard let id = renamingConversationID else { return }
        chatVM.renameConversation(id: id, to: renameText)
        renamingConversationID = nil
    }

    func cancelRename() {
        renamingConversationID = nil
    }

    // MARK: - Actions

    func ctaAction() {
        if sidebarTab == .chats {
            chatVM.newConversation()
        } else {
            savedPromptsVM.addPrompt(title: "Untitled Prompt", content: "")
        }
    }

    func deleteConversation(id: UUID) {
        chatVM.deleteConversation(id: id)
    }

    func togglePin(id: UUID) {
        chatVM.togglePin(id: id)
    }

    func showInspector(for conversation: Conversation) {
        chatVM.selectedConversationID = conversation.id
        onRequestInspector?()
    }

    // MARK: - Types

    struct DateSection {
        let name: String
        let conversations: [Conversation]
    }
}
