import SwiftUI

struct SystemPromptPanelView: View {
    @Bindable var chatVM: ChatViewModel
    @Bindable var savedPromptsVM: SavedPromptsViewModel
    @State private var draftPrompt: String = ""
    @State private var applyState: ApplyState = .clean
    @State private var showSaveToLibrary = false
    @State private var saveTitle = ""
    @FocusState private var editorFocused: Bool

    private let placeholderText = "Custom instructions that shape how the assistant responds in this conversation\u{2026}"

    enum ApplyState: Equatable {
        case clean, dirty, confirmed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            editor
            actions
        }
        .padding()
        .onAppear {
            draftPrompt = chatVM.currentSystemPrompt
        }
        .onChange(of: chatVM.selectedConversationID) {
            draftPrompt = chatVM.currentSystemPrompt
            applyState = .clean
        }
        .onChange(of: draftPrompt) {
            guard applyState != .confirmed else { return }
            let isDirty = !draftPrompt.isEmpty && draftPrompt != chatVM.currentSystemPrompt
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
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Label("System Prompt", systemImage: "terminal")
                .font(.headline)

            Spacer()

            if !chatVM.currentSystemPrompt.isEmpty {
                Label("Active", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
    }

    // MARK: - Editor

    private var editor: some View {
        GroupBox {
            ZStack(alignment: .topLeading) {
                if draftPrompt.isEmpty {
                    Text(placeholderText)
                        .foregroundStyle(.tertiary)
                        .padding(8)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $draftPrompt)
                    .focused($editorFocused)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 200)
            }
        }
    }

    // MARK: - Actions

    private var actions: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Spacer()

                Button("Reset") {
                    draftPrompt = ""
                    chatVM.resetSystemPrompt()
                    applyState = .clean
                }
                .controlSize(.large)
                .buttonStyle(.bordered)
                .disabled(chatVM.currentSystemPrompt.isEmpty && draftPrompt.isEmpty)

                Button {
                    chatVM.applySystemPrompt(draftPrompt)
                    withAnimation(.spring(duration: 0.2)) {
                        applyState = .confirmed
                    }
                    scheduleConfirmReset()
                } label: {
                    HStack(spacing: 4) {
                        if applyState == .confirmed {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.semibold))
                                .transition(.scale.combined(with: .opacity))
                        }
                        Text(applyState == .confirmed ? "Applied" : "Apply")
                            .contentTransition(.interpolate)
                    }
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .disabled(applyState != .dirty)
            }

            // Save to Library
            HStack {
                Spacer()
                Button {
                    saveTitle = ""
                    showSaveToLibrary = true
                } label: {
                    Label("Save to Library", systemImage: "square.and.arrow.down")
                }
                .controlSize(.small)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .disabled(draftPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func scheduleConfirmReset() {
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            guard applyState == .confirmed else { return }
            withAnimation(.spring(duration: 0.2)) {
                applyState = .clean
            }
        }
    }
}

#Preview("SystemPromptPanelView") {
    let client = OllamaClient()
    let chatPersistence = ChatPersistence()
    let summarizationService = SummarizationService(ollamaClient: client)
    let summaryVM = SummaryViewModel(service: summarizationService)

    let chatVM = ChatViewModel(
        ollamaClient: client,
        chatPersistence: chatPersistence,
        summarizationService: summarizationService,
        summaryViewModel: summaryVM
    )
    let savedPromptsVM = SavedPromptsViewModel()
    SystemPromptPanelView(chatVM: chatVM, savedPromptsVM: savedPromptsVM)
        .frame(width: 380)
        .padding()
}
