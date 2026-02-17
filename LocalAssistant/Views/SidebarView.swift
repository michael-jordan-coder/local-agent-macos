import SwiftUI

enum SidebarTab: String, CaseIterable {
    case chats
    case prompts
}

struct SidebarView: View {
    @Bindable var viewModel: SidebarViewModel
    @Namespace private var tabNamespace

    var body: some View {
        VStack(spacing: 0) {
            sidebarTabSwitcher
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 6)

            switch viewModel.sidebarTab {
            case .chats:
                chatsSidebar
            case .prompts:
                promptsSidebar
            }
        }
        .navigationSplitViewColumnWidth(min: 220, ideal: 260)
        .toolbar { sidebarToolbar }
        .alert("Rename Conversation", isPresented: showRenameBinding) {
            TextField("Name", text: $viewModel.renameText)
            Button("Rename") {
                viewModel.commitRename()
            }
            .keyboardShortcut(.defaultAction)
            Button("Cancel", role: .cancel) {
                viewModel.cancelRename()
            }
        }
    }

    // MARK: - Tab Switcher

    private var sidebarTabSwitcher: some View {
        HStack(spacing: 2) {
            tabButton("Chats", tab: .chats)
            tabButton("Prompts", tab: .prompts)
        }
        .padding(3)
        .background(
            Capsule(style: .continuous)
                .fill(.quaternary.opacity(0.5))
        )
    }

    private func tabButton(_ title: String, tab: SidebarTab) -> some View {
        let isSelected = viewModel.sidebarTab == tab

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.sidebarTab = tab
            }
        } label: {
            Text(title)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .white : .secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity)
                .background {
                    if isSelected {
                        Capsule(style: .continuous)
                            .fill(Color.accentColor)
                            .matchedGeometryEffect(id: "activeTab", in: tabNamespace)
                    }
                }
        }
        .buttonStyle(.plain)
        .contentShape(Capsule(style: .continuous))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var sidebarToolbar: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            Button {
                viewModel.ctaAction()
            } label: {
                Label(
                    viewModel.sidebarTab == .chats ? "New Chat" : "New Prompt",
                    systemImage: viewModel.sidebarTab == .chats ? "square.and.pencil" : "plus"
                )
            }
            .help(viewModel.sidebarTab == .chats ? "New Chat" : "New Prompt")
        }
    }

    // MARK: - Chats Sidebar

    private var chatsSidebar: some View {
        List(selection: Binding(
            get: { viewModel.selectedConversationID },
            set: { viewModel.selectedConversationID = $0 }
        )) {
            if !viewModel.pinnedConversations.isEmpty {
                Section {
                    ForEach(viewModel.pinnedConversations) { conv in
                        conversationRow(conv)
                    }
                } header: {
                    Text("Pinned")
                }
            }

            ForEach(viewModel.groupedSections, id: \.name) { section in
                Section {
                    ForEach(section.conversations) { conv in
                        conversationRow(conv)
                    }
                } header: {
                    Text(section.name)
                }
            }
        }
        .listStyle(.sidebar)
        .searchable(
            text: $viewModel.searchText,
            placement: .sidebar,
            prompt: "Search"
        )
        .overlay {
            if viewModel.filteredConversations.isEmpty && !viewModel.searchText.isEmpty {
                ContentUnavailableView.search(text: viewModel.searchText)
            } else if !viewModel.hasConversations {
                ContentUnavailableView(
                    "No Conversations",
                    systemImage: "bubble.left.and.text.bubble.right",
                    description: Text("Create a new chat to get started.")
                )
            }
        }
    }

    // MARK: - Prompts Sidebar

    private var promptsSidebar: some View {
        SavedPromptsListView(promptsVM: viewModel.savedPromptsVM)
    }

    // MARK: - Conversation Row

    private func conversationRow(_ conv: Conversation) -> some View {
        Label(conv.title, systemImage: conv.isPinned ? "pin.fill" : "bubble.left")
            .lineLimit(1)
            .tag(conv.id)
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                    viewModel.deleteConversation(id: conv.id)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            .contextMenu {
                Button {
                    viewModel.togglePin(id: conv.id)
                } label: {
                    Label(conv.isPinned ? "Unpin" : "Pin", systemImage: conv.isPinned ? "pin.slash" : "pin")
                }

                Button {
                    viewModel.beginRename(for: conv)
                } label: {
                    Label("Rename", systemImage: "pencil")
                }

                if let content = conv.systemPrompt, !content.isEmpty {
                    Button {
                        viewModel.showInspector(for: conv)
                    } label: {
                        Label("View System Prompt", systemImage: "doc.text")
                    }
                }

                Divider()

                Button(role: .destructive) {
                    viewModel.deleteConversation(id: conv.id)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
    }

    // MARK: - Rename Binding

    private var showRenameBinding: Binding<Bool> {
        Binding(
            get: { viewModel.isRenaming },
            set: { if !$0 { viewModel.cancelRename() } }
        )
    }
}

#Preview("SidebarView") {
    let now = Date.now
    let firstConversation = Conversation(
        title: "Swift Concurrency Questions",
        messages: [ChatMessage(role: "user", content: "How should I structure async flows?", timestamp: now.addingTimeInterval(-3600))],
        createdAt: now.addingTimeInterval(-7200),
        systemPrompt: "You are a helpful API designer.",
        isPinned: true
    )
    let secondConversation = Conversation(
        title: "Performance Optimization",
        messages: [ChatMessage(role: "user", content: "Profile this render path", timestamp: now.addingTimeInterval(-1800))],
        createdAt: now.addingTimeInterval(-5400),
        systemPrompt: nil,
        isPinned: false
    )
    let chatVM = ChatViewModel(
        previewConversations: [firstConversation, secondConversation],
        selectedConversationID: firstConversation.id
    )
    let savedPromptsVM = SavedPromptsViewModel(
        previewPrompts: [
            SavedPrompt(title: "Code Review", content: "Focus on correctness, risk, and missing tests.", isPinned: true),
            SavedPrompt(title: "Refactor Guide", content: "Prefer incremental, test-first changes.")
        ]
    )
    let sidebarVM = SidebarViewModel(chatVM: chatVM, savedPromptsVM: savedPromptsVM)
    sidebarVM.sidebarTab = .chats

    return NavigationSplitView {
        SidebarView(viewModel: sidebarVM)
    } detail: {
        Text("Detail")
    }
    .frame(width: 700, height: 520)
}
