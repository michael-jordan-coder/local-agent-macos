import MarkdownUI
import SwiftUI

struct MessageRowView: View {
    let message: ChatMessage
    var isStreaming: Bool = false
    var isPickingMention: Bool = false
    var onPickMention: ((ChatMessage) -> Void)?

    @State private var assistantSegments: [ContentSegment]
    @State private var decodedUserImages: [NSImage]

    @State private var rowHover = false
    @State private var copied = false
    @State private var pickHover = false

    init(
        message: ChatMessage,
        isStreaming: Bool = false,
        isPickingMention: Bool = false,
        onPickMention: ((ChatMessage) -> Void)? = nil
    ) {
        self.message = message
        self.isStreaming = isStreaming
        self.isPickingMention = isPickingMention
        self.onPickMention = onPickMention
        _assistantSegments = State(initialValue: message.role == "assistant" ? Self.parseContent(message.content) : [])
        _decodedUserImages = State(initialValue: message.role == "user" ? Self.decodeImages(message.images) : [])
    }

    var body: some View {
        Group {
            switch message.role {
            case "user": userRow
            case "assistant": assistantRow
            default: systemRow
            }
        }
        .onChange(of: message.content) {
            guard message.role == "assistant" else { return }
            assistantSegments = Self.parseContent(message.content)
        }
        .onChange(of: userImageSignature) {
            guard message.role == "user" else { return }
            decodedUserImages = Self.decodeImages(message.images)
        }
    }

    // MARK: - User (right-aligned, system background)

    private var userRow: some View {
        HStack {
            Spacer(minLength: 80)
            VStack(alignment: .trailing, spacing: 6) {
                if let preview = message.mentionPreview {
                    HStack(spacing: 4) {
                        Image(systemName: "text.quote")
                            .font(.caption2)
                        Text(preview)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.4))
                    )
                }

                if !decodedUserImages.isEmpty {
                    ForEach(decodedUserImages.indices, id: \.self) { index in
                        Image(nsImage: decodedUserImages[index])
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 300, maxHeight: 300)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }

                if !message.content.isEmpty {
                    Text(message.content)
                        .font(.title3)
                        .textSelection(.enabled)
                        .padding(10)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    // MARK: - Assistant (left-aligned, hover actions)

    private var assistantRow: some View {
        VStack(alignment: .leading, spacing: 16) {
            let segments = assistantSegments

            ForEach(segments) { segment in
                switch segment.kind {
                case .text(let text):
                    let isLast = segment.id == segments.last?.id
                    if isStreaming && isLast {
                        HStack(alignment: .lastTextBaseline, spacing: 0) {
                            Markdown(text)
                                .font(.body)
                                .markdownTheme(.assistantMessage)
                                .environment(\.openURL, OpenURLAction { url in
                                    NSWorkspace.shared.open(url)
                                    return .handled
                                })
                            StreamingCursorView()
                        }
                    } else {
                        Markdown(text)
                            .font(.body)
                            .markdownTheme(.assistantMessage)
                            .environment(\.openURL, OpenURLAction { url in
                                NSWorkspace.shared.open(url)
                                return .handled
                            })
                    }
                case .codeBlock(let language, let code):
                    CodeBlockView(language: language, code: code)
                }
            }

            // Pulsing dot when content is empty and still streaming
            if isStreaming && message.content.isEmpty {
                PulsingDotView()
            }

            // Hover actions row
            if !isStreaming && !message.content.isEmpty {
                HStack(spacing: 4) {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(message.content, forType: .string)
                        withAnimation(.easeInOut(duration: 0.15)) { copied = true }
                        Task {
                            try? await Task.sleep(for: .seconds(1.5))
                            withAnimation(.easeInOut(duration: 0.15)) { copied = false }
                        }
                    } label: {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(.caption)
                            .foregroundStyle(copied ? Color.green : Color.secondary)
                            .frame(width: 24, height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(copied ? "Copied" : "Copy message")

                    Button {
                        // TODO: wire to chatVM.regenerate()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 24, height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Regenerate")
                }
                .opacity(rowHover || copied ? 1 : 0)
                .animation(.easeInOut(duration: 0.15), value: rowHover)
                .animation(.easeInOut(duration: 0.15), value: copied)
            }
        }
        .padding(isPickingMention ? 8 : 0)
        .background(
            Group {
                if isPickingMention {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(pickHover ? Color.accentColor.opacity(0.08) : Color.clear)
                        .strokeBorder(pickHover ? Color.accentColor.opacity(0.5) : Color(nsColor: .separatorColor).opacity(0.4), lineWidth: 1.5)
                }
            }
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            rowHover = hovering
            if isPickingMention { pickHover = hovering }
        }
        .onTapGesture {
            if isPickingMention, !message.content.isEmpty {
                onPickMention?(message)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: pickHover)
        .animation(.easeInOut(duration: 0.15), value: isPickingMention)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.trailing, 80)
    }

    // MARK: - System (dimmed)

    private var systemRow: some View {
        Text(message.content)
            .font(.body)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Content Parser

    struct ContentSegment: Identifiable {
        let id: Int
        let kind: Kind
        enum Kind {
            case text(String)
            case codeBlock(language: String, code: String)
        }
    }

    static func parseContent(_ content: String) -> [ContentSegment] {
        if !content.contains("```") {
            return [.init(id: 0, kind: .text(content))]
        }

        var segments: [ContentSegment] = []
        var remaining = content[content.startIndex...]
        var idx = 0

        while let openRange = remaining.range(of: "```") {
            let before = String(remaining[remaining.startIndex..<openRange.lowerBound])
                .trimmingCharacters(in: .newlines)
            if !before.isEmpty {
                segments.append(.init(id: idx, kind: .text(before))); idx += 1
            }

            var afterOpen = remaining[openRange.upperBound...]
            var language = ""
            if let nl = afterOpen.range(of: "\n") {
                language = String(afterOpen[afterOpen.startIndex..<nl.lowerBound])
                    .trimmingCharacters(in: .whitespaces)
                afterOpen = afterOpen[nl.upperBound...]
            }

            if let closeRange = afterOpen.range(of: "```") {
                let code = String(afterOpen[afterOpen.startIndex..<closeRange.lowerBound])
                    .trimmingCharacters(in: .newlines)
                segments.append(.init(id: idx, kind: .codeBlock(language: language, code: code))); idx += 1
                remaining = afterOpen[closeRange.upperBound...]
            } else {
                let code = String(afterOpen).trimmingCharacters(in: .newlines)
                segments.append(.init(id: idx, kind: .codeBlock(language: language, code: code))); idx += 1
                remaining = remaining[remaining.endIndex...]
            }
        }

        let rest = String(remaining).trimmingCharacters(in: .newlines)
        if !rest.isEmpty {
            segments.append(.init(id: idx, kind: .text(rest)))
        }

        if segments.isEmpty {
            segments.append(.init(id: 0, kind: .text(content)))
        }

        return segments
    }

    private static func decodeImages(_ images: [Data]?) -> [NSImage] {
        guard let images, !images.isEmpty else { return [] }
        return images.compactMap(NSImage.init(data:))
    }

    private var userImageSignature: Int {
        guard let images = message.images else { return 0 }
        return images.reduce(into: images.count) { partial, data in
            partial = partial &* 31 &+ data.count
        }
    }
}

// MARK: - Assistant Markdown Theme

extension MarkdownUI.Theme {
    static let assistantMessage = Theme()

        // MARK: Inline text styles

        .text { }
        .strong {
            FontWeight(.heavy)
        }
        .link {
            ForegroundColor(.accentColor)
            FontWeight(.medium)
        }
        .code {
            FontFamilyVariant(.monospaced)
            FontSize(.em(0.85))
            BackgroundColor(Color(white: 0.18))
        }

        // MARK: Headings

        .heading1 { configuration in
            VStack(alignment: .leading, spacing: 6) {
                configuration.label
                    .font(.largeTitle.weight(.bold))
                Divider()
            }
            .markdownMargin(top: 16, bottom: 8)
        }
        .heading2 { configuration in
            configuration.label
                .font(.title.weight(.bold))
                .markdownMargin(top: 14, bottom: 6)
        }
        .heading3 { configuration in
            configuration.label
                .font(.title2.weight(.semibold))
                .markdownMargin(top: 4, bottom: 4)
        }
        .heading4 { configuration in
            configuration.label
                .font(.title3.weight(.semibold))
                .markdownMargin(top: 8, bottom: 4)
        }
        .heading5 { configuration in
            configuration.label
                .font(.headline)
                .markdownMargin(top: 6, bottom: 2)
        }
        .heading6 { configuration in
            configuration.label
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .markdownMargin(top: 4, bottom: 2)
        }

        // MARK: Paragraphs

        .paragraph { configuration in
            configuration.label
                .fixedSize(horizontal: false, vertical: true)
                .relativeLineSpacing(.em(0.25))
                .markdownMargin(top: 0, bottom: 18
                )
        }

        // MARK: Lists

        .list { configuration in
            configuration.label
                .markdownMargin(top: 6, bottom: 8)
        }
        .listItem { configuration in
            configuration.label
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 2)
                .markdownMargin(top: .em(0.3))
        }
        .bulletedListMarker { _ in
            Circle()
                .fill(.secondary)
                .frame(width: 5, height: 5)
                .offset(y: 1)
        }
        .numberedListMarker { configuration in
            Text("\(configuration.itemNumber).")
                .font(.system(size: 14, weight: .medium).monospacedDigit())
                .foregroundStyle(.tertiary)
        }
        .taskListMarker { configuration in
            Image(systemName: configuration.isCompleted ? "checkmark.square.fill" : "square")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(configuration.isCompleted ? Color.accentColor : .secondary)
                .font(.system(size: 15))
        }

        // MARK: Blockquotes

        .blockquote { configuration in
            configuration.label
                .markdownTextStyle {
                    FontSize(.em(0.95))
                    FontStyle(.italic)
                    ForegroundColor(.secondary)
                }
                .padding(.leading, 14)
                .padding(.vertical, 8)
                .padding(.trailing, 8)
                .fixedSize(horizontal: false, vertical: true)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(white: 0.1).opacity(0.5))
                )
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color.accentColor.opacity(0.5))
                        .frame(width: 3)
                }
                .markdownMargin(top: 8, bottom: 8)
        }

        // MARK: Thematic break

        .thematicBreak {
            HStack {
                Spacer()
                Capsule()
                    .fill(.tertiary)
                    .frame(width: 60, height: 2)
                Spacer()
            }
            .padding(.vertical, 16)
            .zIndex(1)
        }

        // MARK: Fallback code block

        .codeBlock { configuration in
            ScrollView(.horizontal, showsIndicators: false) {
                configuration.label
                    .markdownTextStyle {
                        FontFamilyVariant(.monospaced)
                        FontSize(.em(0.85))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
            }
            .background(Color(white: 0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color(white: 0.15), lineWidth: 1)
            )
            .markdownMargin(top: 6, bottom: 6)
        }

        // MARK: Tables

        .table { configuration in
            configuration.label
                .fixedSize(horizontal: false, vertical: true)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color(white: 0.15), lineWidth: 1)
                )
                .markdownMargin(top: 8, bottom: 8)
        }
        .tableCell { configuration in
            configuration.label
                .markdownTextStyle {
                    if configuration.row == 0 {
                        FontWeight(.semibold)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .background(
                    configuration.row == 0
                        ? Color(white: 0.14)
                        : (configuration.row.isMultiple(of: 2) ? Color(white: 0.1).opacity(0.3) : Color.clear)
                )
        }
}

// MARK: - Code Block

struct CodeBlockView: View {
    let language: String
    let code: String

    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header bar
            HStack {
                Text(language.isEmpty ? "code" : language.capitalized)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.tertiary)

                Spacer()

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(code, forType: .string)
                    withAnimation(.easeInOut(duration: 0.15)) { copied = true }
                    Task {
                        try? await Task.sleep(for: .seconds(1.5))
                        withAnimation(.easeInOut(duration: 0.15)) { copied = false }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        Text(copied ? "Copied" : "Copy")
                    }
                    .font(.caption)
                    .foregroundStyle(copied ? Color.green : Color.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(white: 0.12))

            // Code content
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(size: 14, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(white: 0.08))
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color(white: 0.15), lineWidth: 1)
        )
    }
}

// MARK: - Streaming Indicators

struct PulsingDotView: View {
    @State private var pulsing = false

    var body: some View {
        Circle()
            .fill(Color.accentColor)
            .frame(width: 6, height: 6)
            .scaleEffect(pulsing ? 1.2 : 0.8)
            .opacity(pulsing ? 1 : 0.4)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulsing)
            .onAppear { pulsing = true }
    }
}

struct StreamingCursorView: View {
    @State private var visible = true

    var body: some View {
        Text("|")
            .font(.system(size: 15.5, weight: .medium))
            .foregroundStyle(Color.accentColor)
            .opacity(visible ? 1 : 0.3)
            .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: visible)
            .onAppear { visible = false }
    }
}

// Keep old name for any other references
struct SpinnerView: View {
    var body: some View {
        PulsingDotView()
    }
}

// MARK: - Preview

#Preview("Assistant Markdown") {
    let sampleMarkdown = """
    # Heading 1 — Main Title

    This is a paragraph with **bold text**, some `inline code`, and a [link](https://example.com). The assistant uses SF Pro Text for a polished reading experience.

    ## Heading 2 — Subsection

    Here's a blockquote with a callout:

    > This is an important note. Pay attention to how blockquotes render with the accent bar and italic styling.

    ### Heading 3 — Details

    **Bullet list:**

    - First item in the list
    - Second item with `code reference`
    - Third item with **bold emphasis**
    ---
    **Numbered steps:**

    1. Clone the repository
    2. Run `swift build` in the terminal
    3. Open the project in Xcode
    ---
    **Task list:**

    - [x] Design the markdown theme
    - [x] Implement code blocks
    - [ ] Add syntax highlighting

    ---

    #### Heading 4 — Comparison Table

    | Feature | Before | After |
    |---------|--------|-------|
    | Font | System default | SF Pro Text |
    | Spacing | Tight | Generous |
    | Code blocks | Basic | Editor-style |

    ##### Heading 5 — Small Heading

    ###### Heading 6 — Smallest Heading

    ```swift
    struct ContentView: View {
        var body: some View {
            Text("Hello, world!")
                .font(.title)
                .padding()
        }
    }
    ```

    And here's a final paragraph after the code block to show spacing between segments.
    """

    ScrollView {
        MessageRowView(
            message: ChatMessage(role: "assistant", content: sampleMarkdown)
        )
        .padding(32)
    }
    .frame(width: 700, height: 900)
    .preferredColorScheme(.dark)
}
