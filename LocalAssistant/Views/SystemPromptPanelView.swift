import SwiftUI

struct SystemPromptPanelView: View {
    @Bindable var chatVM: ChatViewModel
    @Bindable var savedPromptsVM: SavedPromptsViewModel
    @Binding var isPresented: Bool
    @State private var draftPrompt: String = ""
    @State private var applyState: ApplyState = .clean
    @State private var showSaveToLibrary = false
    @State private var saveTitle = ""
    @State private var isCloseHovered = false
    @State private var isSaveHovered = false
    @State private var isResetHovered = false
    @State private var isRevertHovered = false
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

            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.primary.opacity(0.015))
        .ignoresSafeArea(.container, edges: .top)
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
                    .font(.headline.weight(.semibold))

                statusChip

                Spacer()

                if applyState == .dirty {
                    Button("Revert") {
                        draftPrompt = chatVM.currentSystemPrompt
                        applyState = .clean
                    }
                    .buttonStyle(.plain)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(isRevertHovered ? Color.primary.opacity(0.08) : Color.clear)
                    )
                    .onHover { isRevertHovered = $0 }
                }

                Button("Apply") {
                    applyPrompt()
                }
                .buttonStyle(.borderedProminent)
                .disabled(applyState != .dirty)
                .keyboardShortcut(.return, modifiers: [.command])

                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(isCloseHovered ? Color.primary.opacity(0.08) : Color.clear)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .onHover { isCloseHovered = $0 }
                .animation(.easeInOut(duration: 0.15), value: isCloseHovered)
                .help("Close System Prompt")
            }

            Text("Applies to this conversation only")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(Color.primary.opacity(0.02))
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
            .font(.caption2.monospaced())
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(tint.opacity(0.12))
            )
            .overlay(
                Capsule()
                    .strokeBorder(tint.opacity(0.22), lineWidth: 0.5)
            )
    }

    private var promptStatus: PromptStatus {
        if applyState == .dirty { return .unsaved }
        if applyState == .confirmed { return .applied }
        return chatVM.currentSystemPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .inactive : .active
    }

    // MARK: - Editor

    private var editorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SYSTEM INSTRUCTIONS")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
                .tracking(0.8)

            ZStack(alignment: .topLeading) {
                if draftPrompt.isEmpty {
                    Text(placeholderText)
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 10)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $draftPrompt)
                    .focused($editorFocused)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 12)
            }
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(editorFocused ? 0.07 : 0.045))
            )
            .animation(.easeInOut(duration: 0.15), value: editorFocused)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 8) {
            Button("Reset") {
                draftPrompt = ""
                chatVM.resetSystemPrompt()
                applyState = .clean
            }
            .buttonStyle(.plain)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isResetHovered ? Color.primary.opacity(0.08) : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .onHover { isResetHovered = $0 }
            .animation(.easeInOut(duration: 0.15), value: isResetHovered)
            .disabled(chatVM.currentSystemPrompt.isEmpty && draftPrompt.isEmpty)

            Spacer()

            Button {
                saveTitle = ""
                showSaveToLibrary = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.down")
                    Text("Save to Library")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isSaveHovered ? Color.primary.opacity(0.08) : Color.clear)
                )
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .onHover { isSaveHovered = $0 }
            .animation(.easeInOut(duration: 0.15), value: isSaveHovered)
            .disabled(draftPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.primary.opacity(0.02))
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
