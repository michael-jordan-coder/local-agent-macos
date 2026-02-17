import Foundation
import Observation

// MARK: - Dependencies

@MainActor
protocol ModelCatalogProviding {
    func fetchModels() async throws -> [OllamaModel]
}

extension OllamaClient: ModelCatalogProviding {}

@MainActor
protocol ModelSelectionStoring {
    func loadSelection(forKey key: String) -> String?
    func saveSelection(_ selection: String, forKey key: String)
}

struct UserDefaultsModelSelectionStore: ModelSelectionStoring {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadSelection(forKey key: String) -> String? {
        defaults.string(forKey: key)
    }

    func saveSelection(_ selection: String, forKey key: String) {
        defaults.set(selection, forKey: key)
    }
}

// MARK: - View Model

@MainActor
@Observable
final class ModelToolbarSwitcherViewModel {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(message: String)
    }

    let fixedControlWidth: CGFloat

    private(set) var models: [OllamaModel] = []
    private(set) var loadState: LoadState = .idle
    private(set) var selectedModelName: String

    private let catalog: ModelCatalogProviding
    private let selectionStore: ModelSelectionStoring
    private let persistenceKey: String
    private let defaultModelName: String

    init(
        catalog: ModelCatalogProviding,
        selectionStore: ModelSelectionStoring,
        persistenceKey: String = "selectedModel",
        defaultModelName: String = "gpt-oss:20b-cloud",
        fixedControlWidth: CGFloat = 220
    ) {
        self.catalog = catalog
        self.selectionStore = selectionStore
        self.persistenceKey = persistenceKey
        self.defaultModelName = defaultModelName
        self.fixedControlWidth = fixedControlWidth

        self.selectedModelName = selectionStore.loadSelection(forKey: persistenceKey) ?? defaultModelName
    }

    convenience init(
        persistenceKey: String = "selectedModel",
        defaultModelName: String = "gpt-oss:20b-cloud",
        fixedControlWidth: CGFloat = 220
    ) {
        self.init(
            catalog: OllamaClient(),
            selectionStore: UserDefaultsModelSelectionStore(),
            persistenceKey: persistenceKey,
            defaultModelName: defaultModelName,
            fixedControlWidth: fixedControlWidth
        )
    }

    var isLoading: Bool {
        if case .loading = loadState {
            return true
        }
        return false
    }

    var errorMessage: String? {
        if case .failed(let message) = loadState {
            return message
        }
        return nil
    }

    func loadIfNeeded() async {
        guard case .idle = loadState else { return }
        await reload()
    }

    func reload() async {
        loadState = .loading

        do {
            let fetched = try await catalog.fetchModels()
            models = fetched
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

            reconcileSelection()
            loadState = .loaded
        } catch {
            // Keep selection usable even if loading fails.
            loadState = .failed(message: "Unable to load models")
        }
    }

    func selectModel(named name: String) {
        guard selectedModelName != name else { return }
        selectedModelName = name
        selectionStore.saveSelection(name, forKey: persistenceKey)
    }

    private func reconcileSelection() {
        guard !models.isEmpty else {
            selectionStore.saveSelection(selectedModelName, forKey: persistenceKey)
            return
        }

        if models.contains(where: { $0.name == selectedModelName }) {
            selectionStore.saveSelection(selectedModelName, forKey: persistenceKey)
            return
        }

        if let exactDefault = models.first(where: { $0.name == defaultModelName }) {
            selectModel(named: exactDefault.name)
            return
        }

        if let first = models.first {
            selectModel(named: first.name)
        }
    }
}

#if DEBUG
struct InMemoryModelSelectionStore: ModelSelectionStoring {
    private final class Box {
        var value: String?
        init(value: String?) { self.value = value }
    }

    private let box: Box

    init(initialValue: String?) {
        box = Box(value: initialValue)
    }

    func loadSelection(forKey key: String) -> String? {
        _ = key
        return box.value
    }

    func saveSelection(_ selection: String, forKey key: String) {
        _ = key
        box.value = selection
    }
}

/// A catalog that returns static data instantly — no network, no delay.
struct StaticModelCatalog: ModelCatalogProviding {
    let models: [OllamaModel]
    func fetchModels() async throws -> [OllamaModel] { models }
}

extension ModelToolbarSwitcherViewModel {
    /// Creates a VM with pre-loaded state for Xcode previews.
    /// No network, no disk I/O, no delays — pure in-memory.
    static func preview(
        models: [OllamaModel],
        selected: String
    ) -> ModelToolbarSwitcherViewModel {
        let vm = ModelToolbarSwitcherViewModel(
            catalog: StaticModelCatalog(models: models),
            selectionStore: InMemoryModelSelectionStore(initialValue: selected)
        )
        vm.models = models
        vm.loadState = .loaded
        vm.selectedModelName = selected
        return vm
    }
}
#endif
