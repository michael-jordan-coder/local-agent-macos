import SwiftUI

struct ContentView: View {
    var statusVM: AppStatusViewModel
    @Bindable var chatVM: ChatViewModel
    var summaryVM: SummaryViewModel
    @Bindable var savedPromptsVM: SavedPromptsViewModel
    @State private var showInspector = false
    @State private var sidebarVM: SidebarViewModel?

    var body: some View {
        NavigationSplitView {
            if let sidebarVM {
                SidebarView(viewModel: sidebarVM)
            }
        }         detail: {
            detailContent
        }
        .inspector(isPresented: $showInspector) {
            SystemPromptPanelView(chatVM: chatVM, savedPromptsVM: savedPromptsVM, isPresented: $showInspector)
                .inspectorColumnWidth(min: 350, ideal: 380, max: 400)
        }
        .frame(minWidth: 700, minHeight: 500)
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showInspector.toggle()
                } label: {
                    Image(systemName: chatVM.currentSystemPrompt.isEmpty ? "doc.text" : "doc.text.fill")
                }
                .help(showInspector ? "Close System Prompt" : "System Prompt")
            }
        }
        .onAppear {
            if sidebarVM == nil {
                let vm = SidebarViewModel(chatVM: chatVM, savedPromptsVM: savedPromptsVM)
                vm.onRequestInspector = { showInspector = true }
                sidebarVM = vm
            }
        }
    }

    // MARK: - Detail

    private var currentTab: SidebarTab {
        sidebarVM?.sidebarTab ?? .chats
    }

    @ViewBuilder
    private var detailContent: some View {
        if currentTab == .prompts {
            PromptLibraryView(promptsVM: savedPromptsVM) { promptContent in
                chatVM.applySystemPrompt(promptContent)
                sidebarVM?.sidebarTab = .chats
            }
        } else {
            VStack(spacing: 0) {
                if !statusVM.isReady {
                    StatusBarView(status: statusVM.status)
                }

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

#Preview("ContentView") {
    let previewRoot = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent("LocalAssistantContentPreview", isDirectory: true)

    let client = OllamaClient()
    let chatPersistence = ChatPersistence(directory: previewRoot.appendingPathComponent("conversations", isDirectory: true))
    let summarizationService = SummarizationService(
        ollamaClient: client,
        fileURL: previewRoot.appendingPathComponent("summary.txt")
    )
    let summaryVM = SummaryViewModel(service: summarizationService)
    let chatVM = ChatViewModel(
        ollamaClient: client,
        chatPersistence: chatPersistence,
        summarizationService: summarizationService,
        summaryViewModel: summaryVM
    )
    chatVM.newConversation()
    chatVM.applySystemPrompt("You are a precise and pragmatic assistant.")

    let savedPromptsVM = SavedPromptsViewModel(
        persistence: SavedPromptPersistence(directory: previewRoot.appendingPathComponent("saved-prompts", isDirectory: true))
    )
    let statusVM = AppStatusViewModel(previewStatus: .ready)

    return ContentView(
        statusVM: statusVM,
        chatVM: chatVM,
        summaryVM: summaryVM,
        savedPromptsVM: savedPromptsVM
    )
    .frame(width: 1200, height: 760)
}
