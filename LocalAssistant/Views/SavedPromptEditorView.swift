import SwiftUI

struct SavedPromptEditorView: View {
    @Bindable var promptsVM: SavedPromptsViewModel
    var onApply: (String) -> Void

    @State private var draftTitle = ""
    @State private var draftContent = ""
    @State private var applyState: ApplyState = .clean
    @State private var showDeleteConfirmation = false
    @FocusState private var titleFocused: Bool

    private enum ApplyState: Equatable {
        case clean, dirty, saved
    }

    var body: some View {
        if let prompt = promptsVM.selectedPrompt {
            editor(for: prompt)
                .id(prompt.id)
                .onAppear {
                    draftTitle = prompt.title
                    draftContent = prompt.content
                    applyState = .clean
                }
                .onChange(of: promptsVM.selectedPromptID) {
                    guard let p = promptsVM.selectedPrompt else { return }
                    draftTitle = p.title
                    draftContent = p.content
                    applyState = .clean
                }
        } else {
            ContentUnavailableView {
                Label("Saved Prompts", systemImage: "doc.text")
            } description: {
                Text("Create reusable system prompts you can apply to any conversation.")
            } actions: {
                Button("New Prompt") {
                    promptsVM.addPrompt(title: "Untitled Prompt", content: "")
                }
            }
        }
    }

    private func editor(for prompt: SavedPrompt) -> some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                // Title field
                TextField("Prompt title", text: $draftTitle)
                    .textFieldStyle(.plain)
                    .font(.title2.weight(.medium))
                    .focused($titleFocused)

                // Content editor
                GroupBox {
                    ZStack(alignment: .topLeading) {
                        if draftContent.isEmpty {
                            Text("Write your system prompt here...")
                                .foregroundStyle(.tertiary)
                                .padding(8)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: $draftContent)
                            .font(.body)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 300)
                    }
                }

                // Actions
                HStack(spacing: 8) {
                    Button("Apply to Conversation") {
                        guard let id = promptsVM.selectedPromptID else { return }
                        promptsVM.markUsed(id: id)
                        onApply(draftContent)
                    }
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)
                    .disabled(draftContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Spacer()

                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .controlSize(.large)
                    .buttonStyle(.bordered)

                    Button {
                        let title = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                        let content = draftContent.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !title.isEmpty, !content.isEmpty else { return }
                        promptsVM.updatePrompt(id: prompt.id, title: title, content: content)
                        withAnimation(.spring(duration: 0.2)) {
                            applyState = .saved
                        }
                        scheduleSavedReset()
                    } label: {
                        HStack(spacing: 4) {
                            if applyState == .saved {
                                Image(systemName: "checkmark")
                                    .font(.caption.weight(.semibold))
                                    .transition(.scale.combined(with: .opacity))
                            }
                            Text(applyState == .saved ? "Saved" : "Save")
                                .contentTransition(.interpolate)
                        }
                    }
                    .controlSize(.large)
                    .buttonStyle(.bordered)
                    .disabled(applyState != .dirty)
                }
            }
            .padding(24)

            Spacer()
        }
        .confirmationDialog("Delete this prompt?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                promptsVM.deletePrompt(id: prompt.id)
            }
        }
        .onChange(of: draftTitle) { checkDirty(prompt: prompt) }
        .onChange(of: draftContent) { checkDirty(prompt: prompt) }
    }

    private func checkDirty(prompt: SavedPrompt) {
        guard applyState != .saved else { return }
        let isDirty = draftTitle != prompt.title || draftContent != prompt.content
        applyState = isDirty ? .dirty : .clean
    }

    private func scheduleSavedReset() {
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            guard applyState == .saved else { return }
            withAnimation(.spring(duration: 0.2)) {
                applyState = .clean
            }
        }
    }
}
