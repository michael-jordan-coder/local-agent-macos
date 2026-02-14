import Foundation
import Markdown

enum MarkdownRenderer {
    static func render(markdown: String) -> MarkdownDocumentModel {
        let document = Document(parsing: markdown)
        return MarkdownDocumentModel(blocks: parseBlocks(from: document, depth: 0))
    }

    private static func parseBlocks(from container: some Markup, depth: Int) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        for child in container.children {
            blocks.append(contentsOf: parseBlock(child, depth: depth))
        }
        return blocks
    }

    private static func parseBlock(_ node: some Markup, depth: Int) -> [MarkdownBlock] {
        if let heading = node as? Heading {
            let level = max(1, min(3, headingLevel(heading)))
            return [.heading(level: level, inlines: parseInlineList(from: heading))]
        }

        if let paragraph = node as? Paragraph {
            return [.paragraph(inlines: parseInlineList(from: paragraph))]
        }

        if let unorderedList = node as? UnorderedList {
            let items = parseListItems(from: unorderedList, depth: depth)
            return [.list(kind: .unordered, items: items, depth: depth)]
        }

        if let orderedList = node as? OrderedList {
            let items = parseListItems(from: orderedList, depth: depth)
            return [.list(kind: .ordered(start: orderedListStart(orderedList)), items: items, depth: depth)]
        }

        if let codeBlock = node as? CodeBlock {
            return [.codeBlock(language: codeBlockLanguage(codeBlock), code: codeBlockText(codeBlock))]
        }

        if let blockQuote = node as? BlockQuote {
            let nested = parseBlocks(from: blockQuote, depth: depth + 1)
            return [.blockquote(blocks: nested)]
        }

        if node is ThematicBreak {
            return [.thematicBreak]
        }

        if typeName(node).hasSuffix("Table") || typeName(node) == "Table" {
            if let table = parseTable(from: node) {
                return [.table(table)]
            }
            return [.fallback(text: literalText(from: node))]
        }

        let nestedBlocks = parseBlocks(from: node, depth: depth + 1)
        if !nestedBlocks.isEmpty {
            return nestedBlocks
        }

        let fallback = literalText(from: node).trimmingCharacters(in: .whitespacesAndNewlines)
        if fallback.isEmpty {
            return []
        }
        return [.paragraph(inlines: [.text(fallback)])]
    }

    private static func parseListItems(from list: some Markup, depth: Int) -> [MarkdownListItem] {
        var items: [MarkdownListItem] = []

        for child in list.children {
            guard let item = child as? ListItem else { continue }
            var blocks = parseBlocks(from: item, depth: depth + 1)
            if blocks.isEmpty {
                let text = literalText(from: item).trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    blocks = [.paragraph(inlines: [.text(text)])]
                }
            }
            items.append(MarkdownListItem(blocks: blocks))
        }

        return items
    }

    private static func parseInlineList(from container: some Markup) -> [MarkdownInline] {
        var inlines: [MarkdownInline] = []
        for child in container.children {
            inlines.append(contentsOf: parseInline(child))
        }
        return inlines
    }

    private static func parseInline(_ node: some Markup) -> [MarkdownInline] {
        if let text = node as? Text {
            return [.text(text.string)]
        }

        if let strong = node as? Strong {
            return [.strong(parseInlineList(from: strong))]
        }

        if let emphasis = node as? Emphasis {
            return [.emphasis(parseInlineList(from: emphasis))]
        }

        if let inlineCode = node as? InlineCode {
            return [.inlineCode(inlineCode.code)]
        }

        if let link = node as? Link {
            let label = parseInlineList(from: link)
            let destination = linkDestination(link)
            if destination.isEmpty {
                return label
            }
            return [.link(label: label, destination: destination)]
        }

        if node is SoftBreak {
            return [.softBreak]
        }

        if node is LineBreak {
            return [.lineBreak]
        }

        let nested = parseInlineList(from: node)
        if !nested.isEmpty {
            return nested
        }

        let fallback = literalText(from: node)
        if fallback.isEmpty {
            return []
        }

        return [.text(fallback)]
    }

    private static func headingLevel(_ heading: Heading) -> Int {
        max(1, heading.level)
    }

    private static func orderedListStart(_ orderedList: OrderedList) -> Int {
        Int(clamping: orderedList.startIndex)
    }

    private static func codeBlockLanguage(_ codeBlock: CodeBlock) -> String? {
        guard let language = codeBlock.language else { return nil }
        return language.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : language
    }

    private static func codeBlockText(_ codeBlock: CodeBlock) -> String {
        codeBlock.code
    }

    private static func linkDestination(_ link: Link) -> String {
        link.destination ?? ""
    }

    private static func parseTable(from table: some Markup) -> MarkdownTable? {
        var headerRows: [[String]] = []
        var bodyRows: [[String]] = []

        for section in table.children {
            let sectionType = typeName(section)

            if sectionType.contains("Head") {
                headerRows.append(contentsOf: parseRows(from: section))
            } else if sectionType.contains("Body") {
                bodyRows.append(contentsOf: parseRows(from: section))
            } else if sectionType.contains("Row") {
                bodyRows.append(parseCells(from: section))
            }
        }

        if headerRows.isEmpty && bodyRows.isEmpty {
            bodyRows = parseRows(from: table)
        }

        let headers = headerRows.first ?? []
        let rows = bodyRows

        if headers.isEmpty && rows.isEmpty {
            return nil
        }

        return MarkdownTable(headers: headers, rows: rows)
    }

    private static func parseRows(from container: some Markup) -> [[String]] {
        var rows: [[String]] = []

        for child in container.children {
            let childType = typeName(child)
            if childType.contains("Row") {
                rows.append(parseCells(from: child))
            }
        }

        return rows
    }

    private static func parseCells(from row: some Markup) -> [String] {
        var cells: [String] = []

        for child in row.children {
            let childType = typeName(child)
            guard childType.contains("Cell") else { continue }

            let text = literalText(from: child).trimmingCharacters(in: .whitespacesAndNewlines)
            cells.append(text)
        }

        return cells
    }

    private static func literalText(from node: some Markup) -> String {
        if let text = node as? Text {
            return text.string
        }

        if let inlineCode = node as? InlineCode {
            return inlineCode.code
        }

        if node is SoftBreak {
            return " "
        }

        if node is LineBreak {
            return "\n"
        }

        if let codeBlock = node as? CodeBlock {
            return codeBlock.code
        }

        var value = ""
        for child in node.children {
            value += literalText(from: child)
        }
        return value
    }

    private static func typeName(_ node: some Markup) -> String {
        String(describing: type(of: node))
    }
}
