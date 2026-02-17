import SwiftUI

struct SavedPromptsListView: View {
    @Bindable var promptsVM: SavedPromptsViewModel
    @State private var searchText = ""

    private var filtered: [SavedPrompt] {
        if searchText.isEmpty { return promptsVM.sortedPrompts }
        return promptsVM.sortedPrompts.filter {
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
        List(selection: $promptsVM.selectedPromptID) {
            if !pinnedFiltered.isEmpty {
                Section {
                    ForEach(pinnedFiltered) { prompt in
                        promptRow(prompt)
                    }
                } header: {
                    Text("Pinned")
                }
            }

            if !unpinnedFiltered.isEmpty {
                Section {
                    ForEach(unpinnedFiltered) { prompt in
                        promptRow(prompt)
                    }
                } header: {
                    Text("Prompts")
                }
            }
        }
        .listStyle(.sidebar)
        .searchable(
            text: $searchText,
            placement: .sidebar,
            prompt: "Search"
        )
        .overlay {
            if filtered.isEmpty && !searchText.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else if promptsVM.prompts.isEmpty {
                ContentUnavailableView {
                    Label("No Saved Prompts", systemImage: "doc.text")
                } description: {
                    Text("Create reusable system prompts you can apply to any conversation.")
                }
            }
        }
    }

    private func promptRow(_ prompt: SavedPrompt) -> some View {
        Label(prompt.title, systemImage: prompt.isPinned ? "pin.fill" : "doc.text")
            .lineLimit(1)
            .tag(prompt.id)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                promptsVM.deletePrompt(id: prompt.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .contextMenu {
            Button {
                promptsVM.togglePin(id: prompt.id)
            } label: {
                Label(prompt.isPinned ? "Unpin" : "Pin", systemImage: prompt.isPinned ? "pin.slash" : "pin")
            }

            Divider()

            Button(role: .destructive) {
                promptsVM.deletePrompt(id: prompt.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

#Preview("SavedPromptsListView") {
    let promptsVM = makeSavedPromptsListPreviewVM()
    return SavedPromptsListView(promptsVM: promptsVM)
        .frame(width: 320, height: 520)
}

private func makeSavedPromptsListPreviewVM() -> SavedPromptsViewModel {
    let root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent("SavedPromptsListPreview", isDirectory: true)
    let promptsVM = SavedPromptsViewModel(
        persistence: SavedPromptPersistence(directory: root)
    )
    promptsVM.addPrompt(
        title: "Senior Swift Reviewer",
        content: "Review changes for regressions, edge cases, and missing tests."
    )
    promptsVM.addPrompt(
        title: "API Planner",
        content: "Design API contracts with explicit request/response examples and error cases."
    )
    if let firstID = promptsVM.prompts.first?.id {
        promptsVM.togglePin(id: firstID)
    }
    promptsVM.selectedPromptID = nil
    return promptsVM
}
