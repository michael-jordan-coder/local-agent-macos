import SwiftUI

struct SettingsView: View {
    @AppStorage("selectedModel") private var selectedModel: String = "llama3"
    @State private var availableModels: [OllamaModel] = []

    var body: some View {
        Form {
            Section("Model") {
                Picker("LLM Model", selection: $selectedModel) {
                    if availableModels.isEmpty {
                        Text(selectedModel).tag(selectedModel)
                    }
                    ForEach(availableModels) { model in
                        Text(model.name).tag(model.name)
                    }
                }
                .disabled(availableModels.isEmpty)
            }
            .task {
                do {
                    availableModels = try await OllamaClient().fetchModels()
                } catch {
                    print("Failed to fetch models: \(error)")
                }
            }

            Section("About") {
                HStack {
                    Image(systemName: "desktopcomputer")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading) {
                        Text("Local Assistant")
                            .font(.headline)
                        Text("Version 1.0")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)

                Text("Powered by Ollama")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 250)
    }
}

#Preview {
    SettingsView()
}
