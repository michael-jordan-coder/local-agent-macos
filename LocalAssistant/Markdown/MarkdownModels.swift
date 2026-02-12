import Foundation

struct MarkdownDocumentModel {
    var blocks: [MarkdownBlock]
}

indirect enum MarkdownBlock {
    case heading(level: Int, inlines: [MarkdownInline])
    case paragraph(inlines: [MarkdownInline])
    case list(kind: MarkdownListKind, items: [MarkdownListItem], depth: Int)
    case codeBlock(language: String?, code: String)
    case blockquote(blocks: [MarkdownBlock])
    case thematicBreak
    case table(MarkdownTable)
    case fallback(text: String)
}

enum MarkdownListKind {
    case unordered
    case ordered(start: Int)
}

struct MarkdownListItem {
    var blocks: [MarkdownBlock]
}

indirect enum MarkdownInline {
    case text(String)
    case strong([MarkdownInline])
    case emphasis([MarkdownInline])
    case inlineCode(String)
    case link(label: [MarkdownInline], destination: String)
    case softBreak
    case lineBreak
}

struct MarkdownTable {
    var headers: [String]
    var rows: [[String]]
}
