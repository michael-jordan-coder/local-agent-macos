import MarkdownUI
import SwiftUI

struct MessageRowView: View {
    let message: ChatMessage
    var isStreaming: Bool = false
    var isPickingMention: Bool = false
    var onPickMention: ((ChatMessage) -> Void)?

    var body: some View {
        switch message.role {
        case "user": userRow
        case "assistant": assistantRow
        default: systemRow
        }
    }

    // MARK: - User (right-aligned, system background)

    private var userRow: some View {
        HStack {
            Spacer(minLength: 80)
            VStack(alignment: .trailing, spacing: 8) {
                if let images = message.images, !images.isEmpty {
                    ForEach(Array(images.enumerated()), id: \.offset) { _, data in
                        if let nsImage = NSImage(data: data) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: 300, maxHeight: 300)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
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

    // MARK: - Assistant (left-aligned, SF icon, code blocks)

    @State private var copyHover = false
    @State private var copied = false
    @State private var pickHover = false

    private var assistantRow: some View {
        HStack(alignment: .top, spacing: 8) {
            Group {
                if isStreaming {
                    SpinnerView()
                } else {
                    Color.clear
                }
            }
            .frame(width: 20)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Self.parseContent(message.content)) { segment in
                    switch segment.kind {
                    case .text(let text):
                        Markdown(text)
                            .markdownTheme(.assistantMessage)
                            .environment(\.openURL, OpenURLAction { url in
                                NSWorkspace.shared.open(url)
                                return .handled
                            })
                    case .codeBlock(let language, let code):
                        CodeBlockView(language: language, code: code)
                    }
                }

                if !isStreaming && !message.content.isEmpty {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(message.content, forType: .string)
                        withAnimation(.easeInOut(duration: 0.15)) { copied = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation(.easeInOut(duration: 0.15)) { copied = false }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            Text(copied ? "Copied" : "Copy")
                        }
                        .font(.caption)
                        .foregroundStyle(copied ? Color.green : (copyHover ? Color.primary : Color.secondary.opacity(0.5)))
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in copyHover = hovering }
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
            .contentShape(isPickingMention ? Rectangle() : Rectangle())
            .onHover { hovering in
                if isPickingMention { pickHover = hovering }
            }
            .onTapGesture {
                if isPickingMention, !message.content.isEmpty {
                    onPickMention?(message)
                }
            }
            .animation(.easeInOut(duration: 0.15), value: pickHover)
            .animation(.easeInOut(duration: 0.15), value: isPickingMention)

            Spacer(minLength: 80)
        }
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
}

// MARK: - Assistant Markdown Theme

/// Custom MarkdownUI theme for assistant messages.
/// Tuned for macOS readability: clear heading hierarchy, comfortable list spacing,
/// subtle blockquotes, and lightweight inline/block code styling.
extension MarkdownUI.Theme {
    static let assistantMessage = Theme()

        // MARK: Inline text styles

        .text {
            FontSize(16)
        }
        .strong {
            FontWeight(.semibold)
        }
        .link {
            ForegroundColor(.accentColor)
            UnderlineStyle(.single)
        }
        .code {
            FontFamilyVariant(.monospaced)
            FontSize(.em(0.88))
            BackgroundColor(Color(nsColor: .quaternaryLabelColor).opacity(0.4))
        }

        // MARK: Headings

        .heading1 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontSize(30)
                    FontWeight(.semibold)
                }
                .markdownMargin(top: 12, bottom: 6)
        }
        .heading2 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontSize(26)
                    FontWeight(.semibold)
                }
                .markdownMargin(top: 10, bottom: 4)
        }
        .heading3 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontSize(22)
                    FontWeight(.semibold)
                }
                .markdownMargin(top: 8, bottom: 4)
        }
        .heading4 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontSize(19)
                    FontWeight(.semibold)
                }
                .markdownMargin(top: 6, bottom: 2)
        }
        .heading5 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontSize(17)
                    FontWeight(.semibold)
                }
                .markdownMargin(top: 4, bottom: 2)
        }
        .heading6 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontSize(15)
                    FontWeight(.semibold)
                    ForegroundColor(.secondary)
                }
                .markdownMargin(top: 4, bottom: 2)
        }

        // MARK: Paragraphs

        .paragraph { configuration in
            configuration.label
                .fixedSize(horizontal: false, vertical: true)
                .relativeLineSpacing(.em(0.15))
                .markdownMargin(top: 0, bottom: 8)
        }

        // MARK: Lists

        .list { configuration in
            configuration.label
                .markdownMargin(top: 4, bottom: 4)
        }
        .listItem { configuration in
            configuration.label
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 2)
                .markdownMargin(top: .em(0.2))
        }
        .bulletedListMarker { configuration in
            Text("•")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(configuration.listLevel == 1 ? .primary : .secondary)
        }
        .numberedListMarker { configuration in
            Text("\(configuration.itemNumber).")
                .font(.system(size: 15, weight: .medium).monospacedDigit())
                .foregroundStyle(.primary)
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
                    ForegroundColor(.secondary)
                }
                .relativePadding(.leading, length: .em(0.6))
                .padding(.vertical, 6)
                .padding(.trailing, 8)
                .fixedSize(horizontal: false, vertical: true)
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color(nsColor: .tertiaryLabelColor))
                        .frame(width: 3)
                }
                .padding(.leading, 2)
                .markdownMargin(top: 6, bottom: 6)
        }

        // MARK: Thematic break

        .thematicBreak {
            Divider()
                .padding(.vertical, 10)
        }

        // MARK: Fallback code block

        .codeBlock { configuration in
            ScrollView(.horizontal, showsIndicators: true) {
                configuration.label
                    .markdownTextStyle {
                        FontFamilyVariant(.monospaced)
                        FontSize(.em(0.85))
                    }
                    .padding(14)
            }
            .background(
                Color(nsColor: .quaternaryLabelColor).opacity(0.5),
                in: RoundedRectangle(cornerRadius: 8)
            )
            .markdownMargin(top: 6, bottom: 6)
        }

        // MARK: Tables

        .table { configuration in
            configuration.label
                .fixedSize(horizontal: false, vertical: true)
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
        }
}

// MARK: - Code Block

struct CodeBlockView: View {
    let language: String
    let code: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                if !language.isEmpty {
                    Text(language)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(code, forType: .string)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)

            Divider()

            ScrollView(.horizontal, showsIndicators: true) {
                Text(code)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(Color.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Spinner

struct SpinnerView: View {
    @State private var isAnimating = false

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(
                AngularGradient(
                    gradient: Gradient(colors: [.white.opacity(0), .white]),
                    center: .center,
                    startAngle: .degrees(0),
                    endAngle: .degrees(252)
                ),
                style: StrokeStyle(lineWidth: 2, lineCap: .round)
            )
            .frame(width: 14, height: 14)
            .rotationEffect(.degrees(isAnimating ? 360 : 0))
            .animation(.linear(duration: 0.9).repeatForever(autoreverses: false), value: isAnimating)
            .onAppear { isAnimating = true }
    }
}
