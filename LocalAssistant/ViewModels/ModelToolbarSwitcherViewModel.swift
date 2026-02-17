import Foundation
import Observation
import os

// MARK: - Dependencies

protocol ModelCatalogProviding {
    func fetchModels(source: String) async throws -> [OllamaModel]
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

private let log = Logger(subsystem: "daniels.LocalAssistant", category: "ModelToolbarSwitcherVM")

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

    private let instanceID = UUID().uuidString
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
        log.info("Init instance=\(self.instanceID, privacy: .public) selected=\(self.selectedModelName, privacy: .public)")
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
        log.info("loadIfNeeded instance=\(self.instanceID, privacy: .public) state=\(String(describing: self.loadState), privacy: .public)")
        guard case .idle = loadState else { return }
        await reload()
    }

    func reload() async {
        let startedAt = Date()
        log.info("reload begin instance=\(self.instanceID, privacy: .public)")
        loadState = .loading

        do {
            let fetched = try await catalog.fetchModels(source: "ModelToolbarSwitcher.reload")
            models = fetched
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

            reconcileSelection()
            loadState = .loaded
            let elapsedMs = Int(Date().timeIntervalSince(startedAt) * 1000)
            log.info("reload end instance=\(self.instanceID, privacy: .public) modelCount=\(self.models.count) elapsedMs=\(elapsedMs)")
        } catch {
            // Keep selection usable even if loading fails.
            loadState = .failed(message: "Unable to load models")
            let elapsedMs = Int(Date().timeIntervalSince(startedAt) * 1000)
            log.error("reload failed instance=\(self.instanceID, privacy: .public) elapsedMs=\(elapsedMs) error=\(error.localizedDescription, privacy: .public)")
        }
    }

    func selectModel(named name: String) {
        guard selectedModelName != name else { return }
        let previous = selectedModelName
        let startedAt = Date()
        log.info("switch begin instance=\(self.instanceID, privacy: .public) from=\(previous, privacy: .public) to=\(name, privacy: .public)")
        selectedModelName = name
        selectionStore.saveSelection(name, forKey: persistenceKey)
        let elapsedMs = Int(Date().timeIntervalSince(startedAt) * 1000)
        log.info("switch end instance=\(self.instanceID, privacy: .public) selected=\(self.selectedModelName, privacy: .public) elapsedMs=\(elapsedMs)")
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
    func fetchModels(source: String) async throws -> [OllamaModel] {
        _ = source
        return models
    }
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
