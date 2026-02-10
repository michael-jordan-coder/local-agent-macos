import SwiftUI

enum SidebarTab: String, CaseIterable {
    case chats
    case prompts
}

struct ContentView: View {
    var statusVM: AppStatusViewModel
    @Bindable var chatVM: ChatViewModel
    var summaryVM: SummaryViewModel
    @Bindable var savedPromptsVM: SavedPromptsViewModel
    @State private var showInspector = false
    @State private var searchText = ""
    @State private var renamingConversationID: UUID?
    @State private var renameText = ""
    @State private var sidebarTab: SidebarTab = .chats

    var body: some View {
        NavigationSplitView {
            sidebarContent
        } detail: {
            detailContent
                .inspector(isPresented: $showInspector) {
                    SystemPromptPanelView(chatVM: chatVM, savedPromptsVM: savedPromptsVM)
                        .inspectorColumnWidth(min: 250, ideal: 300, max: 400)
                }
        }
        .frame(minWidth: 700, minHeight: 500)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showInspector.toggle()
                } label: {
                    Image(systemName: chatVM.currentSystemPrompt.isEmpty ? "doc.text" : "doc.text.fill")
                }
                .help("System Prompt")
            }
        }
    }

    // MARK: - Sidebar Content

    @ViewBuilder
    private var sidebarContent: some View {
        VStack(spacing: 0) {
            // Tab toggle
            Picker("", selection: $sidebarTab) {
                Label("Chats", systemImage: "bubble.left.and.bubble.right")
                    .tag(SidebarTab.chats)
                Label("Prompts", systemImage: "doc.text")
                    .tag(SidebarTab.prompts)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            
            .padding(.vertical, 8)

            // Tab content
            switch sidebarTab {
            case .chats:
                chatsSidebar
            case .prompts:
                promptsSidebar
            }
        }
        .navigationSplitViewColumnWidth(min: 220, ideal: 260)
        .toolbar {
            ToolbarItem {
                if sidebarTab == .chats {
                    Button { chatVM.newConversation() } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .help("New Conversation")
                } else {
                    Button {
                        savedPromptsVM.addPrompt(title: "Untitled Prompt", content: "")
                    } label: {
                        Image(systemName: "plus")
                    }
                    .help("New Prompt")
                }
            }
        }
    }

    // MARK: - Chats Sidebar

    private var filteredConversations: [Conversation] {
        let base = searchText.isEmpty
            ? chatVM.conversations
            : chatVM.conversations.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        return base.sorted { $0.lastActiveDate > $1.lastActiveDate }
    }

    private var pinnedConversations: [Conversation] {
        filteredConversations.filter(\.isPinned)
    }

    private var unpinnedConversations: [Conversation] {
        filteredConversations.filter { !$0.isPinned }
    }

    private var chatsSidebar: some View {
        List(selection: $chatVM.selectedConversationID) {
            if !pinnedConversations.isEmpty {
                Section("Pinned") {
                    ForEach(pinnedConversations) { conv in
                        sidebarRow(conv)
                    }
                }
            }

            ForEach(groupedSections, id: \.name) { section in
                Section(section.name) {
                    ForEach(section.conversations) { conv in
                        sidebarRow(conv)
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()
                SettingsLink {
                    Label("Settings", systemImage: "gear")
                }
                .buttonStyle(.plain)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(.regularMaterial)
        }
        .searchable(
            text: $searchText,
            placement: .sidebar,
            prompt: "Search conversations"
        )
        .alert("Rename Conversation", isPresented: showRenameBinding) {
            TextField("Name", text: $renameText)
            Button("Rename") {
                if let id = renamingConversationID {
                    chatVM.renameConversation(id: id, to: renameText)
                }
            }
            .keyboardShortcut(.defaultAction)
            Button("Cancel", role: .cancel) { }
        }
    }

    // MARK: - Prompts Sidebar

    private var promptsSidebar: some View {
        SavedPromptsListView(promptsVM: savedPromptsVM)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    Divider()
                    SettingsLink {
                        Label("Settings", systemImage: "gear")
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(.regularMaterial)
            }
    }

    // MARK: - Sidebar Row

    private func sidebarRow(_ conv: Conversation) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(conv.title)
                .lineLimit(1)

            Text(conv.lastActiveDate, format: .relative(presentation: .named))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .tag(conv.id)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                chatVM.deleteConversation(id: conv.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .contextMenu {
            Button {
                chatVM.togglePin(id: conv.id)
            } label: {
                Label(conv.isPinned ? "Unpin" : "Pin", systemImage: conv.isPinned ? "pin.slash" : "pin")
            }

            Button {
                renameText = conv.title
                renamingConversationID = conv.id
            } label: {
                Label("Rename", systemImage: "pencil")
            }

            Divider()

            Button(role: .destructive) {
                chatVM.deleteConversation(id: conv.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Date Sections

    private struct DateSection {
        let name: String
        let conversations: [Conversation]
    }

    private var groupedSections: [DateSection] {
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

    // MARK: - Rename Binding

    private var showRenameBinding: Binding<Bool> {
        Binding(
            get: { renamingConversationID != nil },
            set: { if !$0 { renamingConversationID = nil } }
        )
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailContent: some View {
        if sidebarTab == .prompts {
            SavedPromptEditorView(promptsVM: savedPromptsVM) { promptContent in
                chatVM.applySystemPrompt(promptContent)
                sidebarTab = .chats
            }
        } else {
            VStack(spacing: 0) {
                StatusBarView(status: statusVM.status)

                if !statusVM.isReady {
                    loadingView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if chatVM.selectedConversationID != nil {
                    ChatView(
                        messages: chatVM.currentMessages,
                        isLoading: chatVM.isLoading,
                        isPickingMention: chatVM.isPickingMention,
                        onPickMention: { chatVM.selectMention($0) }
                    )
                    ComposerView(chatVM: chatVM)
                } else {
                    ContentUnavailableView {
                        Label("No Conversation Selected", systemImage: "message")
                    } description: {
                        Text("Create or select a conversation to get started.")
                    } actions: {
                        Button("New Conversation") {
                            chatVM.newConversation()
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var loadingView: some View {
        if case .failed(let msg) = statusVM.status {
            Text(msg).foregroundStyle(.red)
        } else {
            VStack(spacing: 8) {
                ProgressView()
                Text(statusVM.status == .checking ? "Checking Ollama\u{2026}" : "Starting Ollama\u{2026}")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
