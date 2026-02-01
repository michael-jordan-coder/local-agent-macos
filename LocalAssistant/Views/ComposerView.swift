import SwiftUI
import UniformTypeIdentifiers

struct ComposerView: View {
    @Bindable var chatVM: ChatViewModel
    @State private var isImporting = false

    var body: some View {
        VStack(spacing: 8) {
            if let error = chatVM.error {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            // Pick-mode banner
            if chatVM.isPickingMention {
                HStack(spacing: 6) {
                    Image(systemName: "hand.tap")
                        .font(.caption)
                    Text("Tap an assistant message to reference it")
                        .font(.caption)
                    Spacer()
                    Button("Cancel") {
                        chatVM.isPickingMention = false
                    }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor.opacity(0.08))
                )
                .padding(.horizontal)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Image Preview Row
            if !chatVM.selectedImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(chatVM.selectedImages.enumerated()), id: \.offset) { index, data in
                            if let nsImage = NSImage(data: data) {
                                ZStack(alignment: .topTrailing) {
                                    Image(nsImage: nsImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 60, height: 60)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))

                                    Button {
                                        chatVM.removeImage(at: index)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.white, .black.opacity(0.5))
                                            .font(.system(size: 16))
                                            .background(Circle().fill(.white).padding(2))
                                    }
                                    .buttonStyle(.plain)
                                    .offset(x: 6, y: -6)
                                }
                                .padding(.top, 6)
                                .padding(.trailing, 6)
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .frame(height: 70)
            }

            // Mention Chip
            if let mentioned = chatVM.mentionedMessage {
                HStack(spacing: 6) {
                    Image(systemName: "text.quote")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(mentioned.content.prefix(80))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer()
                    Button {
                        chatVM.clearMention()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.5))
                )
                .padding(.horizontal, 10)
            }

            HStack(alignment: .bottom, spacing: 10) {
                // Plus / Attachment Button
                Button(action: {
                    isImporting = true
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .background(.gray.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .fileImporter(
                    isPresented: $isImporting,
                    allowedContentTypes: [.png, .jpeg],
                    allowsMultipleSelection: true
                ) { result in
                    switch result {
                    case .success(let urls):
                        for url in urls {
                            let access = url.startAccessingSecurityScopedResource()
                            defer { if access { url.stopAccessingSecurityScopedResource() } }

                            if let data = try? Data(contentsOf: url) {
                                chatVM.attachImage(data)
                            }
                        }
                    case .failure(let error):
                        print("Import failed: \(error.localizedDescription)")
                    }
                }

                // Mention Button
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        chatVM.isPickingMention.toggle()
                    }
                } label: {
                    Image(systemName: "text.quote")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(chatVM.isPickingMention ? Color.accentColor : .secondary)
                        .frame(width: 32, height: 32)
                        .background(chatVM.isPickingMention ? Color.accentColor.opacity(0.15) : Color.gray.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(!chatVM.hasAssistantMessages)

                // Text Input
                TextField("Ask anything…", text: $chatVM.input, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .padding(.vertical, 8)
                    .frame(minHeight: 24)
                    .onKeyPress { press in
                        guard press.key == .return else { return .ignored }
                        if press.modifiers.contains(.shift) {
                            return .ignored
                        }
                        if canSend {
                            chatVM.send()
                        }
                        return .handled
                    }

                // Send Button or Loading Indicator
                if chatVM.isLoading {
                    Button(action: {
                        chatVM.stop()
                    }) {
                        Image(systemName: "square.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.primary)
                            .frame(width: 32, height: 32)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 2)
                } else {
                    Button(action: {
                        chatVM.send()
                    }) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(canSend ? Color.primary : Color.secondary.opacity(0.5))
                            .frame(width: 32, height: 32)
                            .background(canSend ? Color.primary.opacity(0.1) : Color.gray.opacity(0.15))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSend)
                    .padding(.bottom, 2)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color(nsColor: .textBackgroundColor))
                    .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 3)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(.gray.opacity(0.15), lineWidth: 1)
                    )
            )
        }
        .padding(.vertical, 16)
        .padding(.horizontal)
    }

    private var canSend: Bool {
        (!chatVM.input.trimmingCharacters(in: .whitespaces).isEmpty || !chatVM.selectedImages.isEmpty) && !chatVM.isLoading
    }
}

#Preview("ComposerView") {
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

    return ZStack {
        Color.gray.opacity(0.1).ignoresSafeArea()
        ComposerView(chatVM: chatVM)
            .frame(width: 600)
    }
}
