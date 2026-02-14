import SwiftUI

struct MessageRowView: View {
    let message: ChatMessage
    var isStreaming: Bool = false
    var isPickingMention: Bool = false
    var onPickMention: ((ChatMessage) -> Void)?

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
            if !message.content.isEmpty {
                MarkdownView(markdown: message.content, theme: .default)

                // Behavior note: the prior MarkdownUI renderer placed a cursor inline at the
                // final text baseline. With the AST block renderer, cursor feedback is shown
                // just below content to keep block layout deterministic during streaming.
                if isStreaming {
                    StreamingCursorView()
                }
            }

            if isStreaming && message.content.isEmpty {
                PulsingDotView()
            }

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
        Group {
            if message.content.hasPrefix("🔍SEARCH_SOURCES:") {
                searchSourcesView
            } else if message.content == "🔍SEARCH_SOURCES_EMPTY" {
                emptySearchView
            } else {
                MarkdownView(markdown: message.content, theme: .default)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var searchSourcesView: some View {
        let sourcesData = message.content.dropFirst("🔍SEARCH_SOURCES:".count)
        let sources = parseSearchSources(String(sourcesData))

        return SearchSourcesView(sources: sources)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptySearchView: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("No results found")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func parseSearchSources(_ data: String) -> [(domain: String, url: String)] {
        data.split(separator: ",").compactMap { pair in
            let parts = pair.split(separator: "|")
            guard parts.count == 2 else { return nil }
            return (domain: String(parts[0]), url: String(parts[1]))
        }
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

    This is a paragraph with **bold text**, some `inline code`, and a [link](https://example.com).

    ## Heading 2 — Subsection

    > This is an important note with **emphasis**.

    ### Heading 3 — Details

    - First bullet
    - Second bullet with `code`
      - Nested bullet

    1. Step one
    2. Step two

    ---

    | Feature | Before | After |
    |---------|--------|-------|
    | Font | Default | Tokenized |
    | Spacing | Mixed | Deterministic |

    ```swift
    struct ContentView: View {
        var body: some View {
            Text("Hello, world!")
        }
    }
    ```
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
