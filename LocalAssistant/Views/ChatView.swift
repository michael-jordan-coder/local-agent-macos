import SwiftUI

struct ChatView: View {
    let messages: [ChatMessage]
    var isLoading: Bool = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(messages) { message in
                        MessageRowView(
                            message: message,
                            isStreaming: isLoading && message.id == messages.last?.id && message.role == "assistant"
                        )
                    }
                }
                .padding(64)
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
#Preview("ChatView") {
    let messages: [ChatMessage] = [
        ChatMessage(role: "system", content: "System initialized."),
        ChatMessage(role: "user", content: "Hello!"),
        ChatMessage(role: "assistant", content: "Hi there!\n\n```swift\nprint(\"Hello\")\n```")
    ]

    return ChatView(messages: messages)
        .frame(width: 600, height: 400)
}

