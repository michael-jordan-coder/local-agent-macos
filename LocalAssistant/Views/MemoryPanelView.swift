import SwiftUI

struct MemoryPanelView: View {
    @Bindable var memoryVM: MemoryViewModel
    var lastUserMessage: String?

    var body: some View {
        Section("Memory") {
            GroupBox("Profile") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Name: \(memoryVM.memory.userProfile.name)")
                    Text("Language: \(memoryVM.memory.userProfile.language)")
                    Text("Tone: \(memoryVM.memory.userProfile.tone)")
                }
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox("Facts (\(memoryVM.memory.facts.count))") {
                VStack(alignment: .leading, spacing: 4) {
                    if memoryVM.memory.facts.isEmpty {
                        Text("No facts stored.").foregroundStyle(.secondary)
                    } else {
                        ForEach(memoryVM.memory.facts, id: \.self) { fact in
                            HStack {
                                Image(systemName: memoryVM.selectedFacts.contains(fact)
                                      ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(memoryVM.selectedFacts.contains(fact) ? Color.accentColor : Color.secondary)
                                    .onTapGesture {
                                        if memoryVM.selectedFacts.contains(fact) {
                                            memoryVM.selectedFacts.remove(fact)
                                        } else {
                                            memoryVM.selectedFacts.insert(fact)
                                        }
                                    }
                                Text(fact)
                            }
                        }
                    }
                }
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox("Preferences (\(memoryVM.memory.preferences.count))") {
                VStack(alignment: .leading, spacing: 4) {
                    if memoryVM.memory.preferences.isEmpty {
                        Text("No preferences stored.").foregroundStyle(.secondary)
                    } else {
                        ForEach(memoryVM.memory.preferences, id: \.self) { pref in
                            HStack {
                                Image(systemName: memoryVM.selectedPreferences.contains(pref)
                                      ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(memoryVM.selectedPreferences.contains(pref) ? Color.accentColor : Color.secondary)
                                    .onTapGesture {
                                        if memoryVM.selectedPreferences.contains(pref) {
                                            memoryVM.selectedPreferences.remove(pref)
                                        } else {
                                            memoryVM.selectedPreferences.insert(pref)
                                        }
                                    }
                                Text(pref)
                            }
                        }
                    }
                }
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Button("Remember Last") {
                    if let msg = lastUserMessage { memoryVM.addFact(msg) }
                }
                .disabled(lastUserMessage == nil)

                Button("Forget Selected") {
                    memoryVM.removeSelectedFacts()
                    memoryVM.removeSelectedPreferences()
                }
                .disabled(memoryVM.selectedFacts.isEmpty && memoryVM.selectedPreferences.isEmpty)
            }

            Button("Clear All Memory", role: .destructive) {
                memoryVM.showClearConfirmation = true
            }
            .alert("Clear All Memory?", isPresented: $memoryVM.showClearConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) { memoryVM.clearAll() }
            } message: {
                Text("This will reset all stored facts, preferences, and profile to defaults.")
            }
        }
    }
}
