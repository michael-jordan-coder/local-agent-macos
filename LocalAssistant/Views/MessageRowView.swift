import SwiftUI

struct MessageRowView: View {
    let message: ChatMessage
    var isStreaming: Bool = false

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
            Text(message.content)
                .textSelection(.enabled)
                .padding(10)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Assistant (left-aligned, SF icon, code blocks)

    private var assistantRow: some View {
        HStack(alignment: .top, spacing: 8) {
            Group {
                if isStreaming {
                    SpinnerView()
                } else {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 20)
            .padding(.top, 3)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Self.parseContent(message.content)) { segment in
                    switch segment.kind {
                    case .text(let text):
                        Text(text)
                            .font(.title)
                            .textSelection(.enabled)
                    case .codeBlock(let language, let code):
                        CodeBlockView(language: language, code: code)
                    }
                }
            }

            Spacer(minLength: 80)
        }
    }

    // MARK: - System (dimmed)

    private var systemRow: some View {
        Text(message.content)
            .font(.title)
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
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
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
