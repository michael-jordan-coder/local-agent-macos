import SwiftUI

enum SidebarTab: String, CaseIterable {
    case chats
    case prompts
}

struct SidebarView: View {
    @Bindable var viewModel: SidebarViewModel

    @State private var isCTAHovered = false
    @State private var isSettingsHovered = false
    @Namespace private var tabHighlightNamespace

    var body: some View {
        VStack(spacing: 0) {
            sidebarCTA
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 12)

            Divider()
                .opacity(0.5)

            switch viewModel.sidebarTab {
            case .chats:
                chatsSidebar
            case .prompts:
                promptsSidebar
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationSplitViewColumnWidth(min: 240, ideal: 280)
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

    // MARK: - CTA Button

    private var sidebarCTA: some View {
        Button {
            viewModel.ctaAction()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: viewModel.sidebarTab == .chats ? "plus.message" : "plus")
                Text(viewModel.sidebarTab == .chats ? "New Chat" : "New Prompt")
                Spacer()
            }
            .font(.body.weight(.medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isCTAHovered ? Color.primary.opacity(0.08) : Color.primary.opacity(0.0))
            )
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isCTAHovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: isCTAHovered)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var sidebarToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            sidebarTabSwitcher
        }
    }

    private var sidebarTabSwitcher: some View {
        HStack(spacing: 4) {
            sidebarTabButton(title: "Chat", tab: .chats)
            sidebarTabButton(title: "Prompts", tab: .prompts)
        }
        .padding(4)
        .background(
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.72))
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        .help("Switch sidebar section")
        .accessibilityLabel("Section")
    }

    private func sidebarTabButton(title: String, tab: SidebarTab) -> some View {
        let isSelected = viewModel.sidebarTab == tab

        return Button {
            withAnimation(.easeInOut(duration: 0.16)) {
                viewModel.sidebarTab = tab
            }
        } label: {
            Text(title)
                .font(.headline.weight(isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.68))
                .lineLimit(1)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .frame(minWidth: 92)
                .background {
                    if isSelected {
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.12))
                            .overlay(
                                Capsule(style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                            )
                            .matchedGeometryEffect(id: "SidebarTabHighlight", in: tabHighlightNamespace)
                    }
                }
        }
        .buttonStyle(.plain)
        .contentShape(Capsule(style: .continuous))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
                    sectionHeader("Pinned", icon: "pin.fill")
                }
            }

            ForEach(viewModel.groupedSections, id: \.name) { section in
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
            text: $viewModel.searchText,
            placement: .sidebar,
            prompt: "Search conversations"
        )
        .overlay {
            if viewModel.filteredConversations.isEmpty && !viewModel.searchText.isEmpty {
                ContentUnavailableView.search(text: viewModel.searchText)
            } else if !viewModel.hasConversations {
                VStack(spacing: 8) {
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
        SavedPromptsListView(promptsVM: viewModel.savedPromptsVM)
            .safeAreaInset(edge: .bottom) {
                sidebarBottomBar
            }
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String, icon: String? = nil) -> some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Text(title.capitalized)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
        .padding( .bottom, 4)
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
                .padding(2)
        }
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

    // MARK: - Bottom Bar

    private var sidebarBottomBar: some View {
        VStack(spacing: 0) {
            Divider()
                .opacity(0.5)

            HStack(spacing: 0) {
                SettingsLink {
                    HStack(spacing: 8) {
                        Image(systemName: "gearshape")
                        Text("Settings")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(isSettingsHovered ? Color.primary.opacity(0.08) : Color.clear)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .onHover { isSettingsHovered = $0 }
                .animation(.easeInOut(duration: 0.15), value: isSettingsHovered)

                Spacer()

                modelBadge
                    .padding(.trailing, 12)
            }
            .frame(height: 40)
        }
        .background(.ultraThickMaterial)
    }

    private var modelBadge: some View {
        Text(viewModel.selectedModel)
            .font(.caption2.monospaced())
            .foregroundStyle(.blue)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.blue.opacity(0.12))
            )
            .overlay(
                Capsule()
                    .strokeBorder(Color.blue.opacity(0.2), lineWidth: 0.5)
            )
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
