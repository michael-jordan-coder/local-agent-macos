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
            // — New Chat / New Prompt CTA —
            sidebarCTA
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 8)

            // — Tab Switcher —
            sidebarTabPicker
                .padding(.horizontal, 12)
                .padding(.bottom, 6)

            // — Tab Body —
            switch sidebarTab {
            case .chats:
                chatsSidebar
            case .prompts:
                promptsSidebar
            }
        }
        .navigationSplitViewColumnWidth(min: 240, ideal: 280)
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

    // MARK: - Sidebar CTA Button

    @State private var isNewChatHovered = false

    private var sidebarCTA: some View {
        Button {
            if sidebarTab == .chats {
                chatVM.newConversation()
            } else {
                savedPromptsVM.addPrompt(title: "Untitled Prompt", content: "")
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: sidebarTab == .chats ? "plus.message" : "plus")
                    .font(.subheadline)
                Text(sidebarTab == .chats ? "New Chat" : "New Prompt")
                    .font(.subheadline.weight(.medium))
                Spacer()
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isNewChatHovered ? Color.primary.opacity(0.08) : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isNewChatHovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: isNewChatHovered)
    }

    // MARK: - Tab Picker

    private var sidebarTabPicker: some View {
        HStack {
            Picker("", selection: $sidebarTab) {
                Text("Chats").tag(SidebarTab.chats)
                Text("Prompts").tag(SidebarTab.prompts)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()

            Spacer()
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
                Section {
                    ForEach(pinnedConversations) { conv in
                        conversationRow(conv)
                    }
                } header: {
                    sectionHeader("Pinned", icon: "pin.fill")
                }
            }

            ForEach(groupedSections, id: \.name) { section in
                Section {
                    ForEach(section.conversations) { conv in
                        conversationRow(conv)
                    }
                } header: {
                    sectionHeader(section.name)
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .searchable(
            text: $searchText,
            placement: .sidebar,
            prompt: "Search conversations"
        )
        .overlay {
            if filteredConversations.isEmpty && !searchText.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else if chatVM.conversations.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "bubble.left.and.text.bubble.right")
                        .font(.largeTitle.weight(.ultraLight))
                        .foregroundStyle(.quaternary)
                    Text("No conversations yet")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                    Text("Tap \"New Chat\" to get started")
                        .font(.caption)
                        .foregroundStyle(.quaternary)
                }
                .padding()
            }
        }
        .safeAreaInset(edge: .bottom) {
            sidebarBottomBar
        }
    }

    // MARK: - Prompts Sidebar

    private var promptsSidebar: some View {
        SavedPromptsListView(promptsVM: savedPromptsVM)
            .safeAreaInset(edge: .bottom) {
                sidebarBottomBar
            }
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String, icon: String? = nil) -> some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
                .tracking(0.8)
        }
        .padding(.top, 6)
    }

    // MARK: - Conversation Row

    private func conversationRow(_ conv: Conversation) -> some View {
        HStack {
            Text(conv.title)
                .font(.body)
                .lineLimit(1)

            Spacer(minLength: 0)

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

            if let content = conv.systemPrompt, !content.isEmpty {
                Button {
                    // Select and open inspector to show system prompt
                    chatVM.selectedConversationID = conv.id
                    showInspector = true
                } label: {
                    Label("View System Prompt", systemImage: "doc.text")
                }
            }

            Divider()

            Button(role: .destructive) {
                chatVM.deleteConversation(id: conv.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Bottom Bar

    private var sidebarBottomBar: some View {
        VStack(spacing: 0) {
            Divider()
                .opacity(0.5)

            HStack(spacing: 0) {
                SettingsLink {
                    HStack(spacing: 6) {
                        Image(systemName: "gearshape")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Settings")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer()

                // Model badge
                modelBadge
                    .padding(.trailing, 10)
            }
            .frame(height: 36)
        }
        .background(.ultraThinMaterial)
    }

    @AppStorage("selectedModel") private var selectedModel: String = "llama3"

    private var modelBadge: some View {
        Text(selectedModel)
            .font(.caption2.weight(.semibold).monospaced())
            .foregroundStyle(Color(red: 0.55, green: 0.75, blue: 0.95))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(Color(red: 0.25, green: 0.45, blue: 0.80).opacity(0.15))
            )
            .overlay(
                Capsule()
                    .strokeBorder(Color(red: 0.35, green: 0.50, blue: 0.85).opacity(0.25), lineWidth: 0.5)
            )
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
            PromptLibraryView(promptsVM: savedPromptsVM) { promptContent in
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
