import SwiftUI

struct PromptEditSheet: View {
    var prompt: SavedPrompt?
    var onSave: (_ title: String, _ content: String) -> Void
    var onCancel: () -> Void

    @State private var draftTitle: String = ""
    @State private var draftContent: String = ""
    @FocusState private var titleFocused: Bool

    private var isNew: Bool { prompt == nil }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(isNew ? "New Prompt" : "Edit Prompt")
                    .font(.headline)
                Spacer()
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 12)

            Divider()

            // Form
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Title")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    TextField("Prompt title (optional)", text: $draftTitle)
                        .textFieldStyle(.plain)
                        .font(.title3)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(white: 0.12))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Color(white: 0.2), lineWidth: 1)
                        )
                        .focused($titleFocused)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Content")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    ZStack(alignment: .topLeading) {
                        if draftContent.isEmpty {
                            Text("Write your prompt here…")
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .allowsHitTesting(false)
                        }

                        TextEditor(text: $draftContent)
                            .font(.body)
                            .scrollContentBackground(.hidden)
                            .padding(4)
                    }
                    .frame(minHeight: 200)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(white: 0.12))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color(white: 0.2), lineWidth: 1)
                    )
                }
            }
            .padding(24)

            Divider()

            // Footer
            HStack {
                Spacer()
                Button("Save") {
                    let title = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                    let content = draftContent.trimmingCharacters(in: .whitespacesAndNewlines)
                    let finalTitle = title.isEmpty ? "Untitled" : title
                    onSave(finalTitle, content)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .disabled(draftContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(minWidth: 520, minHeight: 420)
        .onAppear {
            if let prompt {
                draftTitle = prompt.title
                draftContent = prompt.content
            } else {
                draftTitle = ""
                draftContent = ""
            }
            titleFocused = true
        }
    }
}

#Preview("PromptEditSheet") {
    return PromptEditSheet(
        prompt: SavedPrompt(
            title: "Prompt Title",
            content: "Provide concise, production-focused guidance with explicit assumptions."
        ),
        onSave: { _, _ in },
        onCancel: {}
    )
    .frame(width: 560, height: 440)
}
