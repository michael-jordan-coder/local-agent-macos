import SwiftUI

// MARK: - Model Name Formatting

private enum ModelNameFormatter {
    /// Transforms raw Ollama model identifiers into human-readable display names.
    /// Examples:
    ///   "deepseek-coder:6.7b"  → "Deepseek Coder"
    ///   "qwen2.5-coder:14b"    → "Qwen 2.5 Coder"
    ///   "llama3.2"             → "Llama 3.2"
    ///   "gpt-oss:20b-cloud"    → "GPT OSS 20B"
    ///   "mistral:latest"       → "Mistral"
    static func displayName(for raw: String) -> String {
        // Split on ":" to separate name from tag
        let parts = raw.split(separator: ":", maxSplits: 1).map(String.init)
        let baseName = parts[0]
        let tag = parts.count > 1 ? parts[1] : nil

        // Only display the base name — drop the tag entirely (size, variant, "latest")
        return formatSegment(baseName)
    }

    private static func formatSegment(_ segment: String) -> String {
        // Split on hyphens
        let hyphenParts = segment.split(separator: "-").map(String.init)
        return hyphenParts.map { part in
            // Insert spaces between letters and digits: "llama3" → "llama 3", "qwen2.5" → "qwen 2.5"
            let expanded = expandLetterDigitBoundaries(part)
            let tokens = expanded.split(separator: " ").map(String.init)
            return tokens.map { formatToken($0) }.joined(separator: " ")
        }.joined(separator: " ")
    }

    private static func expandLetterDigitBoundaries(_ s: String) -> String {
        var result = ""
        var prev: Character?
        for char in s {
            if let p = prev {
                let prevIsLetter = p.isLetter
                let currIsDigit = char.isNumber || char == "."
                let prevIsDigit = p.isNumber || p == "."
                let currIsLetter = char.isLetter
                if (prevIsLetter && currIsDigit) || (prevIsDigit && currIsLetter) {
                    result += " "
                }
            }
            result.append(char)
            prev = char
        }
        return result
    }

    private static func formatToken(_ token: String) -> String {
        let lower = token.lowercased()

        // Size suffixes: "6.7b", "14b", "70b" → uppercase
        if lower.hasSuffix("b") || lower.hasSuffix("m") || lower.hasSuffix("k") {
            let prefix = String(lower.dropLast())
            if Double(prefix) != nil {
                return token.uppercased()
            }
        }

        // Pure numbers (version-like): keep as-is
        if Double(lower) != nil {
            return token
        }

        // Known acronyms
        let acronyms: Set<String> = ["gpt", "oss", "ai", "llm", "gguf", "ggml", "q4", "q5", "q8", "fp16"]
        if acronyms.contains(lower) {
            return token.uppercased()
        }

        // Default: capitalize first letter
        return token.prefix(1).uppercased() + token.dropFirst().lowercased()
    }
}

// MARK: - Toolbar Control

struct ModelToolbarSwitcherView: View {
    @State private var viewModel: ModelToolbarSwitcherViewModel
    @State private var isHovered = false

    private let iconSystemName: String?

    @MainActor
    init(
        iconSystemName: String? = nil,
        viewModel: ModelToolbarSwitcherViewModel? = nil
    ) {
        self.iconSystemName = iconSystemName
        _viewModel = State(initialValue: viewModel ?? ModelToolbarSwitcherViewModel())
    }

    var body: some View {
        Menu {
            menuContent
        } label: {
            toolbarLabel
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .help("Select model")
        .accessibilityLabel("Model")
        .task {
            guard !RuntimeEnvironment.isXcodePreview else { return }
            await viewModel.loadIfNeeded()
        }
    }

    // MARK: - Label

    private var toolbarLabel: some View {
        HStack(spacing: 5) {
            if viewModel.isLoading && viewModel.models.isEmpty {
                ProgressView()
                    .controlSize(.mini)
                    .tint(.secondary)
            }

            Text(ModelNameFormatter.displayName(for: viewModel.selectedModelName))
                .font(.callout.weight(.medium))
                .foregroundStyle(isHovered ? .primary : .secondary)
                .lineLimit(1)
                .truncationMode(.tail)

            Image(systemName: "chevron.down")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(isHovered ? .tertiary : .quaternary)
        }
    }

    // MARK: - Menu Content

    @ViewBuilder
    private var menuContent: some View {
        switch viewModel.loadState {
        case .idle, .loading:
            Text("Loading models\u{2026}")
                .foregroundStyle(.secondary)
                .disabled(true)

        case .failed(let message):
            Text(message)
                .foregroundStyle(.secondary)
                .disabled(true)

            Button("Retry") {
                Task { await viewModel.reload() }
            }

        case .loaded:
            if viewModel.models.isEmpty {
                Text("No models available")
                    .foregroundStyle(.secondary)
                    .disabled(true)
            } else {
                ForEach(viewModel.models) { model in
                    Button {
                        viewModel.selectModel(named: model.name)
                    } label: {
                        HStack {
                            Text(ModelNameFormatter.displayName(for: model.name))
                            Spacer(minLength: 16)
                            if model.name == viewModel.selectedModelName {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Divider()

            Button("Refresh Models") {
                Task { await viewModel.reload() }
            }
        }
    }
}

// MARK: - Preview

#Preview("Model Toolbar Switcher") {
    let vm = ModelToolbarSwitcherViewModel.preview(
        models: [
            OllamaModel(name: "llama3.2"),
            OllamaModel(name: "deepseek-coder:6.7b"),
            OllamaModel(name: "qwen2.5-coder:14b"),
            OllamaModel(name: "mistral:latest"),
            OllamaModel(name: "gpt-oss:20b-cloud")
        ],
        selected: "deepseek-coder:6.7b"
    )

    NavigationStack {
        Text("Toolbar Host")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    ModelToolbarSwitcherView(viewModel: vm)
                }
            }
    }
    .frame(width: 720, height: 420)
}
