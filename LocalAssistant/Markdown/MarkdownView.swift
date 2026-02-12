import AppKit
import SwiftUI

// Markdown system migration notes (Step 0):
// - Markdown source strings are produced/stored in `ChatMessage.content` and streamed into `MessageRowView`.
// - Previous rendering lived in `Views/MessageRowView.swift` via `MarkdownUI.Markdown(...)` + `.assistantMessage` theme.
// - Previous fenced-code segmentation was handled by `Services/Markdown/AssistantMarkdownTokenizer.swift`.
// - This view replaces that renderer path with an AST-driven renderer using Apple Swift Markdown.
struct MarkdownView: View {
    let markdown: String
    let theme: MarkdownTheme

    @State private var document: MarkdownDocumentModel

    init(markdown: String, theme: MarkdownTheme = .default) {
        self.markdown = markdown
        self.theme = theme
        _document = State(initialValue: MarkdownRenderer.render(markdown: markdown))
    }

    var body: some View {
        MarkdownBlocksView(blocks: document.blocks, theme: theme)
            .frame(maxWidth: theme.contentMaxWidth, alignment: .leading)
            .padding(.horizontal, theme.horizontalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
            .environment(\.openURL, OpenURLAction { url in
                NSWorkspace.shared.open(url)
                return .handled
            })
            .onChange(of: markdown) {
                document = MarkdownRenderer.render(markdown: markdown)
            }
    }
}
