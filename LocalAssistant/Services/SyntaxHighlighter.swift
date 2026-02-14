import Foundation
import AppKit

/// Syntax highlighter tuned for markdown fenced code blocks using Cursor Dark colors.
struct SyntaxHighlighter {

    // MARK: - Cursor Dark Theme Colors

    private static let colors = ColorScheme(
        // Core editor colors (from Cursor Dark `editor.*` and token scopes)
        keyword: NSColor(hex: "#83d6c5"),
        string: NSColor(hex: "#e394dc"),
        comment: NSColor(hex: "#6d6d6d"),
        number: NSColor(hex: "#ebc88d"),
        function: NSColor(hex: "#efb080"),
        type: NSColor(hex: "#87c3ff"),
        constant: NSColor(hex: "#82d2ce"),
        property: NSColor(hex: "#AA9BF5"),
        plain: NSColor(hex: "#d6d6dd"),
        background: NSColor(hex: "#1a1a1a"),
        border: NSColor(hex: "#2A2A2A"),
        // CSS-specific scopes from the same Cursor Dark token palette
        cssAtRule: NSColor(hex: "#a8cc7c"),
        cssSelector: NSColor(hex: "#83d6c5"),
        cssProperty: NSColor(hex: "#87c3ff"),
        cssValue: NSColor(hex: "#e394dc"),
        cssKeyword: NSColor(hex: "#83d6c5")
    )

    private static let font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

    // MARK: - Public API

    static var codeBlockBackgroundColor: NSColor {
        colors.background
    }

    static var codeBlockBorderColor: NSColor {
        colors.border
    }

    /// Highlight code with syntax colors
    static func highlight(_ code: String, language: String?) -> NSAttributedString {
        let attributed = NSMutableAttributedString(string: code)

        // Base styling
        attributed.addAttributes([
            .foregroundColor: colors.plain,
            .font: font
        ], range: NSRange(location: 0, length: attributed.length))

        // Apply syntax highlighting based on language
        if language?.lowercased() == "css" || language?.lowercased() == "scss" || language?.lowercased() == "less" {
            highlightCSS(in: attributed)
        } else {
            // Standard highlighting for other languages
            highlightComments(in: attributed)
            highlightStrings(in: attributed)
            highlightNumbers(in: attributed)
            highlightKeywords(in: attributed, language: language)
            highlightConstants(in: attributed)
            highlightTypes(in: attributed)
            highlightProperties(in: attributed)
            highlightFunctions(in: attributed)
        }

        return attributed
    }

    // MARK: - Token Patterns

    private static func highlightComments(in text: NSMutableAttributedString) {
        // Single-line comments: // ...
        let singleLinePattern = #"//.*?$"#
        applyColor(colors.comment, to: text, pattern: singleLinePattern, options: .anchorsMatchLines)

        // Multi-line comments: /* ... */
        let multiLinePattern = #"/\*[\s\S]*?\*/"#
        applyColor(colors.comment, to: text, pattern: multiLinePattern)
    }

    private static func highlightStrings(in text: NSMutableAttributedString) {
        // Double-quoted strings: "..."
        let doubleQuotePattern = #""(?:[^"\\]|\\.)*""#
        applyColor(colors.string, to: text, pattern: doubleQuotePattern)

        // Single-quoted strings: '...'
        let singleQuotePattern = #"'(?:[^'\\]|\\.)*'"#
        applyColor(colors.string, to: text, pattern: singleQuotePattern)

        // Template literals / backticks: `...`
        let backtickPattern = #"`(?:[^`\\]|\\.)*`"#
        applyColor(colors.string, to: text, pattern: backtickPattern)

        // Multi-line strings (Swift): """..."""
        let multiLineStringPattern = #""{3}[\s\S]*?"{3}"#
        applyColor(colors.string, to: text, pattern: multiLineStringPattern)
    }

    private static func highlightNumbers(in text: NSMutableAttributedString) {
        // Hex: 0x1F, 0xFF
        let hexPattern = #"\b0[xX][0-9a-fA-F]+\b"#
        applyColor(colors.number, to: text, pattern: hexPattern)

        // Binary: 0b1010
        let binaryPattern = #"\b0[bB][01]+\b"#
        applyColor(colors.number, to: text, pattern: binaryPattern)

        // Floats: 3.14, 1.0e-5
        let floatPattern = #"\b\d+\.?\d*(?:[eE][+-]?\d+)?\b"#
        applyColor(colors.number, to: text, pattern: floatPattern)
    }

    private static func highlightKeywords(in text: NSMutableAttributedString, language: String?) {
        let keywords: [String]

        switch language?.lowercased() {
        case "swift":
            keywords = [
                "func", "let", "var", "if", "else", "for", "while", "return", "import",
                "class", "struct", "enum", "protocol", "extension", "init", "deinit",
                "guard", "defer", "switch", "case", "default", "break", "continue",
                "in", "is", "as", "try", "catch", "throw", "throws", "async", "await",
                "public", "private", "internal", "fileprivate", "static", "final",
                "override", "mutating", "nonmutating", "lazy", "weak", "unowned"
            ]
        case "javascript", "js", "typescript", "ts", "jsx", "tsx":
            keywords = [
                "function", "let", "const", "var", "if", "else", "for", "while", "return",
                "class", "extends", "import", "export", "default", "from", "async", "await",
                "try", "catch", "throw", "new", "typeof", "instanceof", "delete",
                "switch", "case", "break", "continue", "do", "in", "of", "static"
            ]
        case "python", "py":
            keywords = [
                "def", "class", "if", "else", "elif", "for", "while", "return", "import",
                "from", "as", "try", "except", "finally", "with", "lambda", "yield",
                "pass", "break", "continue", "raise", "assert", "global", "nonlocal",
                "async", "await", "and", "or", "not", "in", "is"
            ]
        default:
            // Generic keywords common across languages
            keywords = [
                "function", "func", "def", "let", "const", "var", "if", "else", "for",
                "while", "return", "class", "struct", "import", "export", "async", "await",
                "try", "catch", "throw", "new", "switch", "case", "break", "continue"
            ]
        }

        for keyword in keywords {
            let pattern = "\\b\(keyword)\\b"
            applyColor(colors.keyword, to: text, pattern: pattern)
        }
    }

    private static func highlightConstants(in text: NSMutableAttributedString) {
        let constants = ["true", "false", "nil", "null", "undefined", "None", "True", "False", "self", "this", "super"]

        for constant in constants {
            let pattern = "\\b\(constant)\\b"
            applyColor(colors.constant, to: text, pattern: pattern)
        }
    }

    private static func highlightTypes(in text: NSMutableAttributedString) {
        // Type declarations and constructor-ish usage.
        let declarationPattern = #"\b(?:class|struct|enum|protocol|interface|typealias|extends|implements|new)\s+([A-Za-z_][A-Za-z0-9_]*)"#
        applyColor(colors.type, to: text, pattern: declarationPattern, captureGroup: 1)

        // Capitalized identifiers often represent types across common languages.
        let capitalizedPattern = #"\b[A-Z][A-Za-z0-9_]*\b"#
        applyColor(colors.type, to: text, pattern: capitalizedPattern)
    }

    private static func highlightProperties(in text: NSMutableAttributedString) {
        // Dot-access properties and methods: object.property / object.method()
        let dotPropertyPattern = #"\.\s*([A-Za-z_][A-Za-z0-9_]*)"#
        applyColor(colors.property, to: text, pattern: dotPropertyPattern, captureGroup: 1)
    }

    private static func highlightFunctions(in text: NSMutableAttributedString) {
        // Function calls: functionName(
        let functionPattern = #"\b([a-zA-Z_][a-zA-Z0-9_]*)\s*\("#

        applyColor(colors.function, to: text, pattern: functionPattern, captureGroup: 1)
    }

    // MARK: - CSS Highlighting

    private static func highlightCSS(in text: NSMutableAttributedString) {
        // Order matters: comments first, then strings, then specific tokens

        // 1. Comments
        highlightComments(in: text)

        // 2. Strings
        highlightStrings(in: text)

        // 3. At-rules: @keyframes, @media, @import, etc.
        let atRulePattern = #"@[a-zA-Z-]+"#
        applyColor(colors.cssAtRule, to: text, pattern: atRulePattern)

        // 4. CSS Selectors (class, id, element, pseudo)
        // Class selectors: .className
        let classPattern = #"\.[a-zA-Z_-][a-zA-Z0-9_-]*"#
        applyColor(colors.cssSelector, to: text, pattern: classPattern)

        // ID selectors: #idName
        let idPattern = #"#[a-zA-Z_-][a-zA-Z0-9_-]*"#
        applyColor(colors.cssSelector, to: text, pattern: idPattern)

        // 5. Properties: opacity, transform, animation, etc.
        // Match word before ':'
        let propertyPattern = #"\b([a-z-]+)(?=\s*:)"#
        applyColor(colors.cssProperty, to: text, pattern: propertyPattern)

        // 6. CSS Keywords: from, to, forwards, infinite, etc.
        let cssKeywords = ["from", "to", "forwards", "backwards", "both", "infinite", "normal", "reverse", "alternate", "ease", "linear", "ease-in", "ease-out", "ease-in-out"]
        for keyword in cssKeywords {
            let pattern = "\\b\(keyword)\\b"
            applyColor(colors.cssKeyword, to: text, pattern: pattern)
        }

        // 7. CSS Functions: translate3d(), cubic-bezier(), rgba(), etc.
        let cssFunctionPattern = #"\b([a-z-]+)\s*\("#
        applyColor(colors.function, to: text, pattern: cssFunctionPattern, captureGroup: 1)

        // 8. Numbers and units: 0, 1, 20px, 1.2s, 100ms, etc.
        let numberUnitPattern = #"\b\d+\.?\d*(?:px|em|rem|%|s|ms|deg|vh|vw|ch)?\b"#
        applyColor(colors.cssValue, to: text, pattern: numberUnitPattern)
    }

    // MARK: - Helper

    private static func applyColor(
        _ color: NSColor,
        to text: NSMutableAttributedString,
        pattern: String,
        options: NSRegularExpression.Options = [],
        captureGroup: Int? = nil
    ) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return }
        let matches = regex.matches(in: text.string, range: NSRange(location: 0, length: text.length))

        for match in matches {
            let range = captureGroup.flatMap { group in
                guard group < match.numberOfRanges else { return nil }
                let candidate = match.range(at: group)
                return candidate.location == NSNotFound ? nil : candidate
            } ?? match.range

            guard range.location != NSNotFound else { continue }
            text.addAttribute(.foregroundColor, value: color, range: range)
        }
    }
}

// MARK: - Color Scheme

private struct ColorScheme {
    let keyword: NSColor
    let string: NSColor
    let comment: NSColor
    let number: NSColor
    let function: NSColor
    let type: NSColor
    let constant: NSColor
    let property: NSColor
    let plain: NSColor
    let background: NSColor
    let border: NSColor
    // CSS-specific
    let cssAtRule: NSColor
    let cssSelector: NSColor
    let cssProperty: NSColor
    let cssValue: NSColor
    let cssKeyword: NSColor
}

// MARK: - NSColor Hex Extension

private extension NSColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgbValue: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgbValue)

        let r = CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgbValue & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}
