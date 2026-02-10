import SwiftUI

struct ChatView: View {
    let messages: [ChatMessage]
    var isLoading: Bool = false
    var isPickingMention: Bool = false
    var onPickMention: ((ChatMessage) -> Void)?

    var body: some View {
        GeometryReader { geometry in
            if messages.isEmpty {
                EmptyStateView()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 32) {
                            ForEach(messages) { message in
                                MessageRowView(
                                    message: message,
                                    isStreaming: isLoading && message.id == messages.last?.id && message.role == "assistant",
                                    isPickingMention: isPickingMention,
                                    onPickMention: onPickMention
                                )
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, paddingFor(width: geometry.size.width))
                        .padding(.vertical, 24)
                    }
                    .onChange(of: messages.count) {
                        if let last = messages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                    .onAppear {
                        if let last = messages.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
    }

    private func paddingFor(width: CGFloat) -> CGFloat {
        if width < 600 {
            return 16
        } else if width < 900 {
            return 32
        } else {
            return 64
        }
    }
}

#Preview("ChatView") {
    let messages: [ChatMessage] = [
        ChatMessage(role: "system", content: "System initialized."),
        ChatMessage(role: "user", content: "Hello!"),
        ChatMessage(role: "assistant", content: "Hi there!\n\n```swift\nprint(\"Hello\")\n```")
    ]

    return ChatView(messages: messages)
        .frame(width: 600, height: 400)
}
