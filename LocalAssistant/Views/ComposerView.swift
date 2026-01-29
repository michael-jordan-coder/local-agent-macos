import SwiftUI

struct ComposerView: View {
    @Bindable var chatVM: ChatViewModel

    var body: some View {
        VStack(spacing: 8) {
            if let error = chatVM.error {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.system(size: 13))
            }

            HStack(spacing: 12) {
             Image(systemName: "plus")
                    .font(Font.system(size: 24, weight: .medium))
                    
                TextField("Ask anything…", text: $chatVM.input)
                    .font(.body)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(Color.secondary.opacity(0.4), lineWidth: 1)
                    )
                    .onSubmit {
                        guard canSend else { return }
                        Task { await chatVM.send() }
                    }

                if chatVM.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
        .padding(16)
    }

    private var canSend: Bool {
        !chatVM.input.trimmingCharacters(in: .whitespaces).isEmpty && !chatVM.isLoading
    }
}
#Preview("ComposerView") {
    let client = OllamaClient()
    let chatPersistence = ChatPersistence()
    let memoryPersistence = MemoryPersistence()
    let summarizationService = SummarizationService(ollamaClient: client)
    let summaryVM = SummaryViewModel(service: summarizationService)

    let chatVM = ChatViewModel(
        ollamaClient: client,
        chatPersistence: chatPersistence,
        memoryPersistence: memoryPersistence,
        summarizationService: summarizationService,
        summaryViewModel: summaryVM
    )

    return ComposerView(chatVM: chatVM)
        .frame(width: 600)
        .padding()
}

