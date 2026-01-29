import SwiftUI
import ServiceManagement

@main
struct LocalAssistantApp: App {
    @State private var statusVM: AppStatusViewModel
    @State private var chatVM: ChatViewModel
    @State private var memoryVM: MemoryViewModel
    @State private var summaryVM: SummaryViewModel

    init() {
        try? SMAppService.mainApp.register()

        let client = OllamaClient()
        let chatPersistence = ChatPersistence()
        let memoryPersistence = MemoryPersistence()
        let summarizationService = SummarizationService(ollamaClient: client)
        let summaryVM = SummaryViewModel(service: summarizationService)

        _statusVM = State(initialValue: AppStatusViewModel(client: client))
        _chatVM = State(initialValue: ChatViewModel(
            ollamaClient: client,
            chatPersistence: chatPersistence,
            memoryPersistence: memoryPersistence,
            summarizationService: summarizationService,
            summaryViewModel: summaryVM
        ))
        _memoryVM = State(initialValue: MemoryViewModel(persistence: memoryPersistence))
        _summaryVM = State(initialValue: summaryVM)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                statusVM: statusVM,
                chatVM: chatVM,
                memoryVM: memoryVM,
                summaryVM: summaryVM
            )
            .task { await statusVM.ensureRunning() }
            .onAppear { centerWindow() }
        }
    }

    private func centerWindow() {
        DispatchQueue.main.async {
            guard let window = NSApplication.shared.windows.first else { return }
            window.center()
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
