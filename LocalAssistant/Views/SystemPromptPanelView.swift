import SwiftUI

struct SystemPromptPanelView: View {
    @Bindable var chatVM: ChatViewModel
    @State private var draftPrompt: String = ""
    @State private var showTooltip: Bool = false
    @State private var applyState: ApplyState = .clean
    let placeholderText: String = "This conversation is about **conceptual thinking**. Be direct. Use real-world examples. Avoid code unless requested."

    enum ApplyState {
        case clean, dirty, confirmed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 4) {
                Text("Session System Prompt")
                    .font(.title.bold())
                Image(systemName: "questionmark.circle")
                    .foregroundStyle(.secondary)
                    .popover(isPresented: $showTooltip, arrowEdge: .bottom) {
                        Text("Set custom instructions that guide how the AI responds for this session.")
                            .font(.callout)
                            .padding(10)
                            .frame(width: 220)
                    }
                    .onHover { hovering in
                        showTooltip = hovering
                    }
            }
          

            ZStack(alignment: .topLeading) {
                if draftPrompt.isEmpty {
                    Text(placeholderText)
                        .foregroundStyle(.secondary)
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 14)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $draftPrompt)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 14)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 200)
                    .scrollContentBackground(.hidden)
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color(nsColor: .separatorColor))
            )

            HStack(spacing: 8) {
                Spacer()

                Button {
                    draftPrompt = ""
                    chatVM.resetSessionSystemPrompt()
                    applyState = .clean
                } label: {
                    Text("Reset")
                }
                .controlSize(.large)
                .buttonStyle(.bordered)
                .disabled(chatVM.sessionSystemPrompt.isEmpty && draftPrompt.isEmpty)

                Button {
                    chatVM.applySessionSystemPrompt(draftPrompt)
                    withAnimation(.easeInOut(duration: 0.2)) {
                        applyState = .confirmed
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if applyState == .confirmed {
                                applyState = .clean
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        if applyState == .confirmed {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.semibold))
                                .transition(.scale.combined(with: .opacity))
                        }
                        Text(applyState == .confirmed ? "Applied" : "Apply")
                            .contentTransition(.interpolate)
                    }
                    .foregroundStyle(applyState == .confirmed ? .white : .white)
                }
                .controlSize(.large)
                .tint(applyState == .confirmed ? .green : nil)
                .buttonStyle(.borderedProminent)
                .disabled(applyState != .dirty)
            }
        }
        .padding()
        .onAppear {
            draftPrompt = chatVM.sessionSystemPrompt
        }
        .onChange(of: draftPrompt) {
            guard applyState != .confirmed else { return }
            let isDirty = !draftPrompt.isEmpty && draftPrompt != chatVM.sessionSystemPrompt
            applyState = isDirty ? .dirty : .clean
        }
    }

}
#Preview("SystemPromptPanelView") {
    let client = OllamaClient()
    let chatPersistence = ChatPersistence()
    let summarizationService = SummarizationService(ollamaClient: client)
    let summaryVM = SummaryViewModel(service: summarizationService)

    let chatVM = ChatViewModel(
        ollamaClient: client,
        chatPersistence: chatPersistence,
        summarizationService: summarizationService,
        summaryViewModel: summaryVM
    )
    chatVM.sessionSystemPrompt = "You are a helpful assistant."

    return SystemPromptPanelView(chatVM: chatVM)
        .frame(width: 380)
        .padding()
}

