import SwiftUI

struct MarkdownTheme {
    struct TypographyToken {
        var font: Font
        var lineSpacing: CGFloat
        var kerning: CGFloat
        var spacingBefore: CGFloat
        var spacingAfter: CGFloat
    }

    struct ListToken {
        var font: Font
        var lineSpacing: CGFloat
        var kerning: CGFloat
        var spacingBefore: CGFloat
        var spacingAfter: CGFloat
        var indent: CGFloat
        var itemSpacing: CGFloat
    }

    struct InlineCodeToken {
        var font: Font
        var lineSpacing: CGFloat
        var kerning: CGFloat
        var spacingBefore: CGFloat
        var spacingAfter: CGFloat
        var padding: EdgeInsets
    }

    struct HorizontalRuleToken {
        var spacingBefore: CGFloat
        var spacingAfter: CGFloat
        var lineWidth: CGFloat
    }

    struct TableToken {
        var font: Font
        var lineSpacing: CGFloat
        var kerning: CGFloat
        var spacingBefore: CGFloat
        var spacingAfter: CGFloat
        var cellPadding: EdgeInsets
        var borderWidth: CGFloat
    }

    struct Palette {
        var textPrimary: Color
        var textSecondary: Color
        var surface: Color
        var surfaceSubtle: Color
        var borderSubtle: Color
        var quoteBorder: Color
        var codeText: Color
    }

    var h1: TypographyToken
    var h2: TypographyToken
    var h3: TypographyToken
    var body: TypographyToken
    var strong: TypographyToken
    var inlineCode: InlineCodeToken
    var codeBlock: TypographyToken
    var blockquote: TypographyToken
    var horizontalRule: HorizontalRuleToken
    var tableHeader: TableToken
    var tableCell: TableToken
    var list: ListToken

    var contentMaxWidth: CGFloat
    var horizontalPadding: CGFloat
    var blockSpacing: CGFloat
    var listIndent: CGFloat
    var listItemSpacing: CGFloat
    var codeBlockPadding: EdgeInsets
    var codeBlockCornerRadius: CGFloat
    var codeCornerRadius: CGFloat

    var palette: Palette
}

extension MarkdownTheme {
    static let `default` = MarkdownTheme(
        h1: .init(
            font: .title.bold(),
            lineSpacing: 8,
            kerning: 0.2,
            spacingBefore: 24,
            spacingAfter: 12
        ),
        h2: .init(
            font: .title2.weight(.semibold),
            lineSpacing: 7,
            kerning: 0.15,
            spacingBefore: 20,
            spacingAfter: 10
        ),
        h3: .init(
            font: .title3.weight(.semibold),
            lineSpacing: 6,
            kerning: 0.1,
            spacingBefore: 16,
            spacingAfter: 8
        ),
        body: .init(
            font: .system(size: 15, weight: .regular),
            lineSpacing: 6,
            kerning: 0,
            spacingBefore: 0,
            spacingAfter: 12
        ),
        strong: .init(
            font: .system(size: 15, weight: .semibold),
            lineSpacing: 6,
            kerning: 0,
            spacingBefore: 0,
            spacingAfter: 0
        ),
        inlineCode: .init(
            font: .body.monospaced(),
            lineSpacing: 4,
            kerning: 0,
            spacingBefore: 0,
            spacingAfter: 0,
            padding: EdgeInsets(top: 1, leading: 4, bottom: 1, trailing: 4)
        ),
        codeBlock: .init(
            font: .body.monospaced(),
            lineSpacing: 5,
            kerning: 0,
            spacingBefore: 12,
            spacingAfter: 12
        ),
        blockquote: .init(
            font: .body,
            lineSpacing: 6,
            kerning: 0,
            spacingBefore: 12,
            spacingAfter: 12
        ),
        horizontalRule: .init(
            spacingBefore: 20,
            spacingAfter: 20,
            lineWidth: 1
        ),
        tableHeader: .init(
            font: .subheadline.weight(.semibold),
            lineSpacing: 4,
            kerning: 0,
            spacingBefore: 12,
            spacingAfter: 0,
            cellPadding: EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10),
            borderWidth: 1
        ),
        tableCell: .init(
            font: .body,
            lineSpacing: 4,
            kerning: 0,
            spacingBefore: 0,
            spacingAfter: 12,
            cellPadding: EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10),
            borderWidth: 1
        ),
        list: .init(
            font: .body,
            lineSpacing: 6,
            kerning: 0,
            spacingBefore: 8,
            spacingAfter: 8,
            indent: 20,
            itemSpacing: 8
        ),
        contentMaxWidth: .infinity,
        horizontalPadding: 0,
        blockSpacing: 0,
        listIndent: 20,
        listItemSpacing: 8,
        codeBlockPadding: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16),
        codeBlockCornerRadius: 12,
        codeCornerRadius: 8,
        palette: .init(
            textPrimary: Color(nsColor: .labelColor),
            textSecondary: Color(nsColor: .secondaryLabelColor),
            surface: Color(nsColor: .windowBackgroundColor),
            surfaceSubtle: Color(nsColor: .controlBackgroundColor),
            borderSubtle: Color(nsColor: .separatorColor),
            quoteBorder: Color(nsColor: .tertiaryLabelColor),
            codeText: Color(nsColor: .labelColor)
        )
    )
}
