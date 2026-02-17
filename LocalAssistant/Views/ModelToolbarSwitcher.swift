import SwiftUI

// MARK: - Toolbar Control

struct ModelToolbarSwitcherView: View {
    @State private var viewModel: ModelToolbarSwitcherViewModel

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
        .help("Select model")
        .accessibilityLabel("Model")
        .task {
            guard !RuntimeEnvironment.isXcodePreview else { return }
            await viewModel.loadIfNeeded()
        }
    }

    private var toolbarLabel: some View {
        HStack(spacing: 6) {
            if let iconSystemName {
                Image(systemName: iconSystemName)
                    .foregroundStyle(Color.white)
            }

            if viewModel.isLoading && viewModel.models.isEmpty {
                ProgressView()
                    .controlSize(.small)
                    .tint(Color.white)
            }

            Text(viewModel.selectedModelName)
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.white)
                .lineLimit(1)
                .truncationMode(.tail)

            Image(systemName: "chevron.down")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.5))
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var menuContent: some View {
        switch viewModel.loadState {
        case .idle, .loading:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Loading Models…")
            }
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
                            Text(model.name)
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
    let previewViewModel = ModelToolbarSwitcherViewModel(
        catalog: PreviewModelCatalog(
            models: [
                OllamaModel(name: "Llama3.2"),
                OllamaModel(name: "Qwen2.5-coder:14b"),
                OllamaModel(name: "Deepseek-r1:8b")
            ]
        ),
        selectionStore: InMemoryModelSelectionStore(initialValue: "qwen2.5-coder:14b"),
        persistenceKey: "preview.selectedModel",
        defaultModelName: "Llama3.2",
        fixedControlWidth: 220
    )

    NavigationStack {
        Text("Toolbar Host")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    ModelToolbarSwitcherView(
                        iconSystemName: "cpu",
                        viewModel: previewViewModel
                    )
                }
            }
    }
    .frame(width: 720, height: 420)
}
