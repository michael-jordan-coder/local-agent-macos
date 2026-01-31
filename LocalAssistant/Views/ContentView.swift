import SwiftUI

struct ContentView: View {
    var statusVM: AppStatusViewModel
    @Bindable var chatVM: ChatViewModel
    var summaryVM: SummaryViewModel
    @State private var showInspector = false
    @State private var searchText = ""

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailContent
                .inspector(isPresented: $showInspector) {
                    SystemPromptPanelView(chatVM: chatVM)
                        .inspectorColumnWidth(min: 250, ideal: 300, max: 400)
                }
        }
        .frame(minWidth: 700, minHeight: 500)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showInspector.toggle()
                } label: {
                    Image(systemName: chatVM.sessionSystemPrompt.isEmpty ? "doc.text" : "doc.text.fill")
                }
                .help("System Prompt")
            }
        }
    }

    // MARK: - Sidebar

    private var filteredConversations: [Conversation] {
        guard !searchText.isEmpty else { return chatVM.conversations }
        return chatVM.conversations.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var sidebar: some View {
        List(selection: $chatVM.selectedConversationID) {
            ForEach(filteredConversations) { conv in
                Text(conv.title)
                    .font(.title3.weight(.regular))
                    .lineLimit(1)
                    .padding(.vertical, 4)
                    .tag(conv.id)
                    .contextMenu {
                        Button("Delete", role: .destructive) {
                            chatVM.deleteConversation(id: conv.id)
                        }
                    }
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()
                SettingsLink {
                    Label("Settings", systemImage: "gear")
                        .font(.body)
                        .foregroundStyle(.primary)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .background(.regularMaterial)
        }
        .searchable(
            text: $searchText,
            placement: .sidebar,
            prompt: "Search conversations"
        )
        .navigationSplitViewColumnWidth(min: 220, ideal: 260)
        .toolbar {
            ToolbarItem {
                Button { chatVM.newConversation() } label: {
                    Image(systemName: "square.and.pencil")
                }
            }
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailContent: some View {
        VStack(spacing: 0) {
            StatusBarView(status: statusVM.status)

            if !statusVM.isReady {
                loadingView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if chatVM.selectedConversationID != nil {
                ChatView(messages: chatVM.currentMessages, isLoading: chatVM.isLoading)
                ComposerView(chatVM: chatVM)
            } else {
                Text("Create a new conversation to get started")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                Text(statusVM.status == .checking ? "Checking Ollama…" : "Starting Ollama…")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
