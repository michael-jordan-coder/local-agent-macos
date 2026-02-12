import Foundation

enum AssistantMarkdownTokenizer {
    enum Segment: Equatable {
        case markdown(String)
        case code(language: String?, code: String, isClosed: Bool)
    }

    static func tokenize(_ input: String) -> [Segment] {
        let lines = splitLinesPreservingNewlines(input)
        var segments: [Segment] = []

        var markdownBuffer = ""
        var codeBuffer = ""
        var codeLanguage: String?
        var isInCodeFence = false

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)

            if isInCodeFence {
                if isFenceCloser(trimmedLine) {
                    segments.append(.code(language: codeLanguage, code: codeBuffer, isClosed: true))
                    codeBuffer = ""
                    codeLanguage = nil
                    isInCodeFence = false
                } else {
                    codeBuffer += line
                }
                continue
            }

            guard let language = openingFenceLanguage(from: trimmedLine) else {
                markdownBuffer += normalizeModelMarkdownLine(line)
                continue
            }

            if !markdownBuffer.isEmpty {
                segments.append(.markdown(markdownBuffer))
                markdownBuffer = ""
            }

            codeLanguage = language
            isInCodeFence = true
        }

        if isInCodeFence {
            segments.append(.code(language: codeLanguage, code: codeBuffer, isClosed: false))
        } else if !markdownBuffer.isEmpty || segments.isEmpty {
            segments.append(.markdown(markdownBuffer))
        }

        return segments
    }

    private static func normalizeModelMarkdownLine(_ line: String) -> String {
        let endsWithNewline = line.hasSuffix("\n")
        let rawLine = endsWithNewline ? String(line.dropLast()) : line

        let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("**"), trimmed.hasSuffix("**"), trimmed.count > 4 else {
            return line
        }

        let innerStart = trimmed.index(trimmed.startIndex, offsetBy: 2)
        let innerEnd = trimmed.index(trimmed.endIndex, offsetBy: -2)
        let inner = String(trimmed[innerStart..<innerEnd]).trimmingCharacters(in: .whitespaces)

        guard isHeadingLine(inner) else { return line }

        return endsWithNewline ? "\(inner)\n" : inner
    }

    private static func openingFenceLanguage(from trimmedLine: String) -> String? {
        guard trimmedLine.hasPrefix("```") else { return nil }

        let suffix = trimmedLine.dropFirst(3)
        let language = String(suffix).trimmingCharacters(in: .whitespaces)
        return language.isEmpty ? nil : language
    }

    private static func isFenceCloser(_ trimmedLine: String) -> Bool {
        guard trimmedLine.hasPrefix("```") else { return false }

        let suffix = trimmedLine.dropFirst(3)
        return suffix.allSatisfy { $0 == "`" || $0.isWhitespace }
    }

    private static func isHeadingLine(_ line: String) -> Bool {
        guard !line.isEmpty else { return false }

        var cursor = line.startIndex
        var markerCount = 0

        while cursor < line.endIndex, line[cursor] == "#" {
            markerCount += 1
            cursor = line.index(after: cursor)
        }

        guard markerCount > 0, markerCount <= 6, cursor < line.endIndex else { return false }

        let separator = line[cursor]
        guard separator == " " || separator == "\t" else { return false }

        let restStart = line.index(after: cursor)
        let rest = String(line[restStart...]).trimmingCharacters(in: .whitespaces)
        return !rest.isEmpty
    }

    private static func splitLinesPreservingNewlines(_ input: String) -> [String] {
        guard !input.isEmpty else { return [] }

        var result: [String] = []
        var lineStart = input.startIndex
        var cursor = input.startIndex

        while cursor < input.endIndex {
            if input[cursor] == "\n" {
                let next = input.index(after: cursor)
                result.append(String(input[lineStart..<next]))
                lineStart = next
            }
            cursor = input.index(after: cursor)
        }

        if lineStart < input.endIndex {
            result.append(String(input[lineStart..<input.endIndex]))
        }

        return result
    }
}
