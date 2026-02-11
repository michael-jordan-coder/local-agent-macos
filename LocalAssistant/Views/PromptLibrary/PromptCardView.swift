import SwiftUI

struct PromptCardView: View {
    let prompt: SavedPrompt
    var onCopy: () -> Void
    var onEdit: () -> Void
    var onDelete: () -> Void
    var onApply: () -> Void

    @State private var isHovered = false
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: title + pin badge
            HStack(alignment: .top) {
                Text(prompt.title.isEmpty ? "Untitled" : prompt.title)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                if prompt.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // Content preview
            Text(prompt.content)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            // Footer: date + hover actions
            HStack(spacing: 6) {
                Text(prompt.updatedAt, format: .relative(presentation: .named))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Spacer()

                if isHovered || copied {
                    HStack(spacing: 2) {
                        Button {
                            onApply()
                        } label: {
                            Image(systemName: "play.fill")
                                .font(.caption2)
                                .frame(width: 24, height: 24)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .help("Apply to Conversation")

                        Button {
                            onCopy()
                            withAnimation(.easeInOut(duration: 0.15)) { copied = true }
                            Task {
                                try? await Task.sleep(for: .seconds(1.5))
                                withAnimation(.easeInOut(duration: 0.15)) { copied = false }
                            }
                        } label: {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                .font(.caption2)
                                .frame(width: 24, height: 24)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(copied ? .green : .secondary)
                        .help(copied ? "Copied" : "Copy")

                        Button {
                            onEdit()
                        } label: {
                            Image(systemName: "pencil")
                                .font(.caption2)
                                .frame(width: 24, height: 24)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .help("Edit")

                        Button {
                            onDelete()
                        } label: {
                            Image(systemName: "trash")
                                .font(.caption2)
                                .frame(width: 24, height: 24)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .help("Delete")
                    }
                    .transition(.opacity)
                }
            }
        }
        .padding(14)
        .frame(minHeight: 120)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: isHovered ? 0.14 : 0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color(white: isHovered ? 0.25 : 0.18), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .contextMenu {
            Button {
                onApply()
            } label: {
                Label("Apply to Conversation", systemImage: "play")
            }

            Button {
                onCopy()
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }

            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Divider()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

#Preview("PromptCardView") {
    let prompt = SavedPrompt(
        title: "Code Review Lens",
        content: "Focus on bugs, regressions, and missing tests before discussing style refinements.",
        isPinned: true
    )
    return PromptCardView(
        prompt: prompt,
        onCopy: {},
        onEdit: {},
        onDelete: {},
        onApply: {}
    )
    .frame(width: 320, height: 180)
    .padding()
    .background(Color.black)
}
