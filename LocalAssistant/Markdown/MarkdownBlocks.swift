import SwiftUI

struct MarkdownBlocksView: View {
    let blocks: [MarkdownBlock]
    let theme: MarkdownTheme
    var textColor: Color?

    var body: some View {
        VStack(alignment: .leading, spacing: theme.blockSpacing) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                MarkdownBlockView(
                    block: block,
                    theme: theme,
                    textColor: textColor
                )
            }
        }
    }
}

private struct MarkdownBlockView: View {
    let block: MarkdownBlock
    let theme: MarkdownTheme
    var textColor: Color?

    var body: some View {
        switch block {
        case .heading(let level, let inlines):
            MarkdownInlineText(
                inlines: inlines,
                theme: theme,
                base: headingToken(level: level),
                textColor: textColor ?? theme.palette.textPrimary
            )
            .padding(.top, headingToken(level: level).spacingBefore)
            .padding(.bottom, headingToken(level: level).spacingAfter)

        case .paragraph(let inlines):
            MarkdownInlineText(
                inlines: inlines,
                theme: theme,
                base: theme.body,
                textColor: textColor ?? theme.palette.textPrimary
            )
            .padding(.top, theme.body.spacingBefore)
            .padding(.bottom, theme.body.spacingAfter)

        case .list(let kind, let items, let depth):
            MarkdownListView(
                kind: kind,
                items: items,
                depth: depth,
                theme: theme,
                textColor: textColor
            )
            .padding(.top, theme.list.spacingBefore)
            .padding(.bottom, theme.list.spacingAfter)

        case .codeBlock(let language, let code):
            MarkdownCodeBlockView(language: language, code: code, theme: theme)
                .padding(.top, theme.codeBlock.spacingBefore)
                .padding(.bottom, theme.codeBlock.spacingAfter)

        case .blockquote(let blocks):
            HStack(alignment: .top, spacing: 12) {
                Rectangle()
                    .fill(theme.palette.quoteBorder)
                    .frame(width: 3)

                MarkdownBlocksView(
                    blocks: blocks,
                    theme: theme,
                    textColor: theme.palette.textSecondary
                )
            }
            .padding(.vertical, 8)
            .padding(.leading, 12)
            .padding(.trailing, 4)
            .background(theme.palette.surfaceSubtle)
            .clipShape(RoundedRectangle(cornerRadius: theme.codeCornerRadius))
            .padding(.top, theme.blockquote.spacingBefore)
            .padding(.bottom, theme.blockquote.spacingAfter)

        case .thematicBreak:
            Rectangle()
                .fill(theme.palette.borderSubtle)
                .frame(height: theme.horizontalRule.lineWidth)
                .padding(.top, theme.horizontalRule.spacingBefore)
                .padding(.bottom, theme.horizontalRule.spacingAfter)

        case .table(let table):
            MarkdownTableView(table: table, theme: theme)

        case .fallback(let text):
            Text(verbatim: text)
                .font(theme.body.font)
                .kerning(theme.body.kerning)
                .lineSpacing(theme.body.lineSpacing)
                .foregroundStyle(textColor ?? theme.palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, theme.body.spacingBefore)
                .padding(.bottom, theme.body.spacingAfter)
        }
    }

    private func headingToken(level: Int) -> MarkdownTheme.TypographyToken {
        switch level {
        case 1: return theme.h1
        case 2: return theme.h2
        default: return theme.h3
        }
    }
}

private struct MarkdownCodeBlockView: View {
    let language: String?
    let code: String
    let theme: MarkdownTheme

    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if let language, !language.isEmpty {
                    Text(language)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(theme.palette.textSecondary)
                        .textCase(.lowercase)
                }

                Spacer(minLength: 0)

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(code, forType: .string)

                    withAnimation(.easeInOut(duration: 0.15)) {
                        copied = true
                    }

                    Task {
                        try? await Task.sleep(for: .seconds(1.5))
                        withAnimation(.easeInOut(duration: 0.15)) {
                            copied = false
                        }
                    }
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(copied ? Color.green : theme.palette.textSecondary)
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(copied ? "Copied" : "Copy code")
            }

            ScrollView(.horizontal, showsIndicators: true) {
                // Syntax-highlighted code
                Text(AttributedString(SyntaxHighlighter.highlight(code, language: language)))
                    .lineSpacing(theme.codeBlock.lineSpacing)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(theme.codeBlockPadding)
        .background(Color(nsColor: SyntaxHighlighter.codeBlockBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: theme.codeBlockCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: theme.codeBlockCornerRadius)
                .stroke(Color(nsColor: SyntaxHighlighter.codeBlockBorderColor), lineWidth: 1)
        )
    }
}

private struct MarkdownListView: View {
    let kind: MarkdownListKind
    let items: [MarkdownListItem]
    let depth: Int
    let theme: MarkdownTheme
    var textColor: Color?

    var body: some View {
        VStack(alignment: .leading, spacing: theme.listItemSpacing) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: 8) {
                    Text(marker(for: index))
                        .font(theme.list.font)
                        .foregroundStyle(textColor ?? theme.palette.textSecondary)
                        .frame(width: markerWidth, alignment: .trailing)

                    MarkdownBlocksView(
                        blocks: item.blocks,
                        theme: theme,
                        textColor: textColor
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.leading, CGFloat(depth) * theme.listIndent)
    }

    private var markerWidth: CGFloat {
        24
    }

    private func marker(for index: Int) -> String {
        switch kind {
        case .unordered:
            return "•"
        case .ordered(let start):
            return "\(start + index)."
        }
    }
}

private struct MarkdownTableView: View {
    let table: MarkdownTable
    let theme: MarkdownTheme

    private var columnCount: Int {
        max(
            table.headers.count,
            table.rows.map(\.count).max() ?? 0
        )
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {
                if !table.headers.isEmpty {
                    tableRow(
                        cells: table.headers,
                        token: theme.tableHeader,
                        textColor: theme.palette.textPrimary,
                        background: theme.palette.surfaceSubtle.opacity(0.8)
                    )
                }

                ForEach(Array(table.rows.enumerated()), id: \.offset) { index, row in
                    tableRow(
                        cells: row,
                        token: theme.tableCell,
                        textColor: theme.palette.textPrimary,
                        background: index.isMultiple(of: 2) ? theme.palette.surface : theme.palette.surfaceSubtle.opacity(0.4)
                    )
                }
            }
            .background(theme.palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: theme.codeCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: theme.codeCornerRadius)
                    .stroke(theme.palette.borderSubtle, lineWidth: theme.tableCell.borderWidth)
            )
        }
        .padding(.top, theme.tableCell.spacingBefore)
        .padding(.bottom, theme.tableCell.spacingAfter)
    }

    @ViewBuilder
    private func tableRow(
        cells: [String],
        token: MarkdownTheme.TableToken,
        textColor: Color,
        background: Color
    ) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(0..<columnCount, id: \.self) { column in
                Text(verbatim: column < cells.count ? cells[column] : "")
                    .font(token.font)
                    .kerning(token.kerning)
                    .lineSpacing(token.lineSpacing)
                    .foregroundStyle(textColor)
                    .frame(minWidth: 120, maxWidth: .infinity, alignment: .leading)
                    .padding(token.cellPadding)
                    .background(background)
                    .overlay(
                        Rectangle()
                            .stroke(theme.palette.borderSubtle, lineWidth: token.borderWidth)
                    )
            }
        }
    }
}

private struct MarkdownInlineText: View {
    let inlines: [MarkdownInline]
    let theme: MarkdownTheme
    let base: MarkdownTheme.TypographyToken
    let textColor: Color

    var body: some View {
        Text(attributedText)
            .lineSpacing(base.lineSpacing)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var attributedText: AttributedString {
        MarkdownInlineAttributedBuilder.build(
            inlines: inlines,
            theme: theme,
            base: base,
            textColor: textColor
        )
    }
}

private enum MarkdownInlineAttributedBuilder {
    static func build(
        inlines: [MarkdownInline],
        theme: MarkdownTheme,
        base: MarkdownTheme.TypographyToken,
        textColor: Color
    ) -> AttributedString {
        var result = AttributedString()

        for inline in inlines {
            result += build(
                inline: inline,
                theme: theme,
                base: base,
                textColor: textColor
            )
        }

        return result
    }

    private static func build(
        inline: MarkdownInline,
        theme: MarkdownTheme,
        base: MarkdownTheme.TypographyToken,
        textColor: Color
    ) -> AttributedString {
        switch inline {
        case .text(let text):
            return styledText(text, font: base.font, kerning: base.kerning, textColor: textColor)

        case .strong(let value):
            var segment = build(inlines: value, theme: theme, base: base, textColor: textColor)
            segment.font = theme.strong.font
            segment.kern = theme.strong.kerning
            return segment

        case .emphasis(let value):
            var segment = build(inlines: value, theme: theme, base: base, textColor: textColor)
            segment.font = base.font.italic()
            return segment

        case .inlineCode(let code):
            // SwiftUI attributed text does not support per-run rounded corners,
            // so inline code uses NBSP-based padding and background color.
            let leadingInset = theme.inlineCode.padding.leading > 0 ? "\u{00A0}" : ""
            let trailingInset = theme.inlineCode.padding.trailing > 0 ? "\u{00A0}" : ""
            let padded = "\(leadingInset)\(code)\(trailingInset)"
            var segment = styledText(
                padded,
                font: theme.inlineCode.font,
                kerning: theme.inlineCode.kerning,
                textColor: theme.palette.codeText
            )
            segment.backgroundColor = theme.palette.surfaceSubtle
            segment.baselineOffset = 0.5
            return segment

        case .link(let label, let destination):
            var segment = build(inlines: label, theme: theme, base: base, textColor: textColor)
            if let url = URL(string: destination) {
                segment.link = url
            }
            segment.foregroundColor = .accentColor
            return segment

        case .softBreak:
            return styledText(" ", font: base.font, kerning: base.kerning, textColor: textColor)

        case .lineBreak:
            return styledText("\n", font: base.font, kerning: base.kerning, textColor: textColor)
        }
    }

    private static func styledText(
        _ text: String,
        font: Font,
        kerning: CGFloat,
        textColor: Color
    ) -> AttributedString {
        var value = AttributedString(text)
        value.font = font
        value.kern = kerning
        value.foregroundColor = textColor
        return value
    }
}
