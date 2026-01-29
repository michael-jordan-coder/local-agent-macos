import Foundation
import Observation

@Observable
final class MemoryViewModel {
    private(set) var memory: LongTermMemory
    var selectedFacts: Set<String> = []
    var selectedPreferences: Set<String> = []
    var showClearConfirmation = false

    private let persistence: MemoryPersistence

    init(persistence: MemoryPersistence) {
        self.persistence = persistence
        self.memory = persistence.load()
    }

    func addFact(_ fact: String) {
        let trimmed = fact.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !memory.facts.contains(trimmed) else { return }
        memory.facts.append(trimmed)
        persistence.save(memory)
    }

    func addPreference(_ pref: String) {
        let trimmed = pref.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !memory.preferences.contains(trimmed) else { return }
        memory.preferences.append(trimmed)
        persistence.save(memory)
    }

    func removeSelectedFacts() {
        memory.facts.removeAll { selectedFacts.contains($0) }
        selectedFacts.removeAll()
        persistence.save(memory)
    }

    func removeSelectedPreferences() {
        memory.preferences.removeAll { selectedPreferences.contains($0) }
        selectedPreferences.removeAll()
        persistence.save(memory)
    }

    func clearAll() {
        memory = .default
        selectedFacts.removeAll()
        selectedPreferences.removeAll()
        persistence.save(memory)
    }

    func reload() {
        memory = persistence.load()
    }
}
