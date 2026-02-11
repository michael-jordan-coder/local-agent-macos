import SwiftUI

struct PromptLibraryView: View {
    @Bindable var promptsVM: SavedPromptsViewModel
    var onApply: (String) -> Void

    @State private var searchText = ""
    @State private var showNewSheet = false
    @State private var deletingPromptID: UUID?

    private let columns = [GridItem(.adaptive(minimum: 260, maximum: 400), spacing: 14)]

    private var filtered: [SavedPrompt] {
        let base = promptsVM.sortedPrompts
        guard !searchText.isEmpty else { return base }
        return base.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.content.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var pinnedFiltered: [SavedPrompt] {
        filtered.filter(\.isPinned)
    }

    private var unpinnedFiltered: [SavedPrompt] {
        filtered.filter { !$0.isPinned }
    }

    var body: some View {
        Group {
            if promptsVM.selectedPromptID != nil {
                // Full-page detail view
                PromptDetailView(
                    promptsVM: promptsVM,
                    promptID: promptsVM.selectedPromptID!,
                    onApply: { content in
                        onApply(content)
                    },
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            promptsVM.selectedPromptID = nil
                        }
                    }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                // Card grid library
                libraryGrid
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: promptsVM.selectedPromptID)
    }

    // MARK: - Library Grid

    private var libraryGrid: some View {
        Group {
            if promptsVM.prompts.isEmpty {
                emptyLibrary
            } else if filtered.isEmpty {
                emptySearch
            } else {
                cardGrid
            }
        }
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search prompts")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showNewSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .help("New Prompt")
            }
        }
        .sheet(isPresented: $showNewSheet) {
            PromptEditSheet(
                onSave: { title, content in
                    promptsVM.addPrompt(title: title, content: content)
                    showNewSheet = false
                    // Navigate to the newly created prompt
                    // selectedPromptID is set by addPrompt
                },
                onCancel: { showNewSheet = false }
            )
        }
        .confirmationDialog(
            "Delete this prompt?",
            isPresented: showDeleteBinding,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let id = deletingPromptID {
                    promptsVM.deletePrompt(id: id)
                }
                deletingPromptID = nil
            }
            Button("Cancel", role: .cancel) {
                deletingPromptID = nil
            }
        } message: {
            Text("This action cannot be undone.")
        }
    }

    // MARK: - Card Grid

    private var cardGrid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if !pinnedFiltered.isEmpty {
                    section(title: "Pinned", prompts: pinnedFiltered)
                }

                if !unpinnedFiltered.isEmpty {
                    section(
                        title: pinnedFiltered.isEmpty ? nil : "All Prompts",
                        prompts: unpinnedFiltered
                    )
                }
            }
            .padding(24)
        }
    }

    private func section(title: String?, prompts: [SavedPrompt]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(prompts) { prompt in
                    PromptCardView(
                        prompt: prompt,
                        onCopy: { promptsVM.copyToClipboard(id: prompt.id) },
                        onEdit: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                promptsVM.selectedPromptID = prompt.id
                            }
                        },
                        onDelete: { deletingPromptID = prompt.id },
                        onApply: {
                            promptsVM.markUsed(id: prompt.id)
                            onApply(prompt.content)
                        }
                    )
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            promptsVM.selectedPromptID = prompt.id
                        }
                    }
                }
            }
        }
    }

    // MARK: - Empty States

    private var emptyLibrary: some View {
        ContentUnavailableView {
            Label("Prompt Library", systemImage: "doc.text")
        } description: {
            Text("Save reusable system prompts you can apply to any conversation.")
        } actions: {
            Button("New Prompt") {
                showNewSheet = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var emptySearch: some View {
        ContentUnavailableView.search(text: searchText)
    }

    // MARK: - Bindings

    private var showDeleteBinding: Binding<Bool> {
        Binding(
            get: { deletingPromptID != nil },
            set: { if !$0 { deletingPromptID = nil } }
        )
    }
}

#Preview("PromptLibraryView") {
    let promptsVM = makePromptLibraryPreviewVM()
    return NavigationStack {
        PromptLibraryView(promptsVM: promptsVM) { _ in }
    }
    .frame(width: 1000, height: 700)
}

private func makePromptLibraryPreviewVM() -> SavedPromptsViewModel {
    let root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent("PromptLibraryPreview", isDirectory: true)
    let promptsVM = SavedPromptsViewModel(
        persistence: SavedPromptPersistence(directory: root)
    )
    promptsVM.addPrompt(
        title: "Sprint Planner",
        content: "Turn requirements into a milestone plan with concrete deliverables and risks."
    )
    let firstID = promptsVM.selectedPromptID
    promptsVM.addPrompt(
        title: "Refactor Guide",
        content: "Propose safe incremental refactors with test checkpoints."
    )
    promptsVM.addPrompt(
        title: "Incident Summary",
        content: "Summarize incident timeline, impact, root cause, and follow-up actions."
    )
    if let firstID {
        promptsVM.togglePin(id: firstID)
    }
    promptsVM.selectedPromptID = nil
    return promptsVM
}
