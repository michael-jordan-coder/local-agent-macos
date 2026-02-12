import SwiftUI

struct SystemPromptPanelView: View {
    @Bindable var chatVM: ChatViewModel
    @Bindable var savedPromptsVM: SavedPromptsViewModel
    @Binding var isPresented: Bool
    @State private var draftPrompt: String = ""
    @State private var applyState: ApplyState = .clean
    @State private var showSaveToLibrary = false
    @State private var saveTitle = ""
    @FocusState private var editorFocused: Bool

    private let placeholderText = "Custom instructions that shape how the assistant responds in this conversation..."

    enum ApplyState: Equatable {
        case clean, dirty, confirmed
    }

    private enum PromptStatus {
        case active, unsaved, applied, inactive
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()
                .opacity(0.5)

            editorSection
                .frame(maxHeight: .infinity)

            Divider()
                .opacity(0.5)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            draftPrompt = chatVM.currentSystemPrompt
            applyState = .clean
        }
        .onChange(of: chatVM.selectedConversationID) {
            draftPrompt = chatVM.currentSystemPrompt
            applyState = .clean
        }
        .onChange(of: chatVM.currentSystemPrompt) {
            guard applyState != .dirty else { return }
            draftPrompt = chatVM.currentSystemPrompt
        }
        .onChange(of: draftPrompt) {
            let isDirty = draftPrompt != chatVM.currentSystemPrompt
            applyState = isDirty ? .dirty : .clean
        }
        .alert("Save to Library", isPresented: $showSaveToLibrary) {
            TextField("Prompt title", text: $saveTitle)
            Button("Save") {
                let title = saveTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !title.isEmpty else { return }
                savedPromptsVM.addPrompt(title: title, content: draftPrompt)
                saveTitle = ""
            }
            .keyboardShortcut(.defaultAction)
            Button("Cancel", role: .cancel) {
                saveTitle = ""
            }
        }
        .onExitCommand {
            isPresented = false
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("System Prompt")
                    .font(.title3)

                statusChip

                Spacer()
            }

            Text("Applies to this conversation only")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private var statusChip: some View {
        switch promptStatus {
        case .active:
            chip("Active", tint: .green)
        case .unsaved:
            chip("Unsaved", tint: .orange)
        case .applied:
            chip("Applied", tint: .green)
        case .inactive:
            EmptyView()
        }
    }

    private func chip(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(tint)
    }

    private var promptStatus: PromptStatus {
        if applyState == .dirty { return .unsaved }
        if applyState == .confirmed { return .applied }
        return chatVM.currentSystemPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .inactive : .active
    }

    // MARK: - Editor

    private var editorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("System Instructions")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Save to Library") {
                    saveTitle = ""
                    showSaveToLibrary = true
                }
                .buttonStyle(.glass)
                .controlSize(.large)
                .contentShape(Rectangle())
                .disabled(draftPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("Apply") {
                    applyPrompt()
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .contentShape(Rectangle())
                .disabled(applyState != .dirty)
                .keyboardShortcut(.return, modifiers: [.command])
            }

            Divider()
                .opacity(0.8)

            ZStack(alignment: .topLeading) {
                if draftPrompt.isEmpty {
                    Text(placeholderText)
                        .font(.body.monospaced().weight(.light))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 10)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $draftPrompt)
                    .focused($editorFocused)
                    .font(.body.monospaced().weight(.light))
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 12)
            }
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(red: 24/255, green: 24/255, blue: 24/255))
            )
            .animation(.easeInOut(duration: 0.15), value: editorFocused)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }

    private func applyPrompt() {
        chatVM.applySystemPrompt(draftPrompt)
        withAnimation(.easeInOut(duration: 0.15)) {
            applyState = .confirmed
        }
        scheduleConfirmReset()
    }

    private func scheduleConfirmReset() {
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            guard applyState == .confirmed else { return }
            withAnimation(.easeInOut(duration: 0.15)) {
                applyState = .clean
            }
        }
    }
}

#Preview("System Prompt Panel") {
    @Previewable @State var shown = true

    let previewRoot = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent("LocalAssistantPreview", isDirectory: true)
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

    return SystemPromptPanelView(chatVM: chatVM, savedPromptsVM: savedPromptsVM, isPresented: $shown)
        .frame(width: 340, height: 620)
}
