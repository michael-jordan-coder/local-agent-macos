import SwiftUI

struct PromptDetailView: View {
    @Bindable var promptsVM: SavedPromptsViewModel
    let promptID: UUID
    var onApply: (String) -> Void
    var onBack: () -> Void

    @State private var draftTitle: String = ""
    @State private var draftContent: String = ""
    @State private var saveState: SaveState = .clean
    @State private var showDeleteConfirmation = false
    @State private var copied = false
    @FocusState private var titleFocused: Bool

    private enum SaveState: Equatable {
        case clean, dirty, saved
    }

    private var prompt: SavedPrompt? {
        promptsVM.prompts.first(where: { $0.id == promptID })
    }

    var body: some View {
        if let prompt {
            editorContent(for: prompt)
                .id(prompt.id)
                .onAppear {
                    draftTitle = prompt.title
                    draftContent = prompt.content
                    saveState = .clean
                }
        } else {
            ContentUnavailableView {
                Label("Prompt Not Found", systemImage: "doc.text")
            } description: {
                Text("This prompt may have been deleted.")
            } actions: {
                Button("Back to Library") { onBack() }
                    .buttonStyle(.glassProminent)
            }
        }
    }

    // MARK: - Editor Content

    private func editorContent(for prompt: SavedPrompt) -> some View {
        VStack(spacing: 0) {
            // Top bar
            topBar(for: prompt)

            Divider()

            // Editor
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Title field
                    TextField("Untitled", text: $draftTitle)
                        .textFieldStyle(.plain)
                        .font(.title.weight(.semibold))
                        .focused($titleFocused)

                    // Content editor
                    ZStack(alignment: .topLeading) {
                        if draftContent.isEmpty {
                            Text("Write your system prompt here…")
                                .foregroundStyle(.tertiary)
                                .padding(.top, 1)
                                .allowsHitTesting(false)
                        }

                        TextEditor(text: $draftContent)
                            .font(.body.monospaced())
                            .scrollContentBackground(.hidden)
                    }
                    .frame(minHeight: 320)

                    // Metadata
                    HStack(spacing: 16) {
                        Text("Created \(prompt.createdAt, format: .dateTime.month().day().year())")

                        Text("Updated \(prompt.updatedAt, format: .relative(presentation: .named))")

                        if let lastUsed = prompt.lastUsedAt {
                            Text("Last used \(lastUsed, format: .relative(presentation: .named))")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.quaternary)
                }
                .padding(32)
            }

            Divider()

            // Bottom action bar
            bottomBar(for: prompt)
        }
        .confirmationDialog("Delete this prompt?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                promptsVM.deletePrompt(id: prompt.id)
                onBack()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This action cannot be undone.")
        }
        .onChange(of: draftTitle) { checkDirty(prompt: prompt) }
        .onChange(of: draftContent) { checkDirty(prompt: prompt) }
    }

    // MARK: - Top Bar

    private func topBar(for prompt: SavedPrompt) -> some View {
        HStack(spacing: 12) {
            // Back button
            Button {
                onBack()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.medium))
                    Text("Library")
                        .font(.body)
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Spacer()

            // Dirty indicator
            if saveState == .dirty {
                Text("Unsaved changes")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .transition(.opacity)
            }

            if saveState == .saved {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Saved")
                        .foregroundStyle(.green)
                }
                .font(.caption)
                .transition(.scale.combined(with: .opacity))
            }

            // Pin toggle
            Button {
                promptsVM.togglePin(id: prompt.id)
            } label: {
                Image(systemName: prompt.isPinned ? "pin.fill" : "pin")
                    .font(.body)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(prompt.isPinned ? Color.accentColor : .secondary)
            .help(prompt.isPinned ? "Unpin" : "Pin")

            // Copy
            Button {
                promptsVM.copyToClipboard(id: prompt.id)
                withAnimation(.easeInOut(duration: 0.15)) { copied = true }
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    withAnimation(.easeInOut(duration: 0.15)) { copied = false }
                }
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.body)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(copied ? .green : .secondary)
            .help(copied ? "Copied!" : "Copy to Clipboard")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .animation(.easeInOut(duration: 0.2), value: saveState)
    }

    // MARK: - Bottom Bar

    private func bottomBar(for prompt: SavedPrompt) -> some View {
        HStack(spacing: 10) {
            // Delete
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .buttonStyle(.glass)
            .controlSize(.large)

            Spacer()

            // Apply
            Button {
                saveIfNeeded(prompt: prompt)
                promptsVM.markUsed(id: prompt.id)
                onApply(draftContent)
            } label: {
                Label("Apply to Conversation", systemImage: "play.fill")
            }
            .buttonStyle(.glass)
            .controlSize(.large)
            .disabled(draftContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            // Save
            Button {
                performSave(prompt: prompt)
            } label: {
                HStack(spacing: 4) {
                    if saveState == .saved {
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.semibold))
                            .transition(.scale.combined(with: .opacity))
                    }
                    Text(saveState == .saved ? "Saved" : "Save")
                        .contentTransition(.interpolate)
                }
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .disabled(saveState != .dirty)
            .keyboardShortcut("s", modifiers: .command)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }

    // MARK: - Helpers

    private func checkDirty(prompt: SavedPrompt) {
        guard saveState != .saved else { return }
        let isDirty = draftTitle != prompt.title || draftContent != prompt.content
        withAnimation(.easeInOut(duration: 0.15)) {
            saveState = isDirty ? .dirty : .clean
        }
    }

    private func saveIfNeeded(prompt: SavedPrompt) {
        guard saveState == .dirty else { return }
        performSave(prompt: prompt)
    }

    private func performSave(prompt: SavedPrompt) {
        let title = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let content = draftContent.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalTitle = title.isEmpty ? "Untitled" : title
        guard !content.isEmpty else { return }
        promptsVM.updatePrompt(id: prompt.id, title: finalTitle, content: content)
        withAnimation(.spring(duration: 0.2)) {
            saveState = .saved
        }
        scheduleSavedReset()
    }

    private func scheduleSavedReset() {
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            guard saveState == .saved else { return }
            withAnimation(.spring(duration: 0.2)) {
                saveState = .clean
            }
        }
    }
}

#Preview("PromptDetailView") {
    let data = makePromptDetailPreviewData()
    return PromptDetailView(
        promptsVM: data.promptsVM,
        promptID: data.promptID,
        onApply: { _ in },
        onBack: {}
    )
    .frame(width: 900, height: 640)
}

private func makePromptDetailPreviewData() -> (promptsVM: SavedPromptsViewModel, promptID: UUID) {
    let root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent("PromptDetailPreview", isDirectory: true)
    let promptsVM = SavedPromptsViewModel(
        persistence: SavedPromptPersistence(directory: root)
    )
    promptsVM.addPrompt(
        title: "Architecture Reviewer",
        content: "Prefer clear tradeoffs and concrete migration plans over generic recommendations."
    )
    let promptID = promptsVM.selectedPromptID ?? UUID()
    promptsVM.addPrompt(
        title: "Testing Assistant",
        content: "Generate practical tests focused on behavior and edge cases."
    )
    return (promptsVM, promptID)
}
