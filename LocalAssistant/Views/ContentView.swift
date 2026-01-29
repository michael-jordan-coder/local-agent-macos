import SwiftUI

struct ContentView: View {
    var statusVM: AppStatusViewModel
    @Bindable var chatVM: ChatViewModel
    var memoryVM: MemoryViewModel
    var summaryVM: SummaryViewModel
    @State private var showInspector = false

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

    private var sidebar: some View {
        List(selection: $chatVM.selectedConversationID) {
            ForEach(chatVM.conversations) { conv in
                Text(conv.title)
                    .lineLimit(1)
                    .tag(conv.id)
                    .contextMenu {
                        Button("Delete", role: .destructive) {
                            chatVM.deleteConversation(id: conv.id)
                        }
                    }
            }
        }
        .navigationSplitViewColumnWidth(min: 180, ideal: 220)
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
