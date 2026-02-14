import SwiftUI
import ServiceManagement

@main
struct LocalAssistantApp: App {
    @State private var statusVM: AppStatusViewModel
    @State private var chatVM: ChatViewModel
    @State private var summaryVM: SummaryViewModel
    @State private var savedPromptsVM: SavedPromptsViewModel

    init() {
        try? SMAppService.mainApp.register()

        let client = OllamaClient()
        let chatPersistence = ChatPersistence()
        let summarizationService = SummarizationService(ollamaClient: client)
        let summaryVM = SummaryViewModel(service: summarizationService)
        let searchService = SearchService()

        _statusVM = State(initialValue: AppStatusViewModel(client: client))
        _chatVM = State(initialValue: ChatViewModel(
            ollamaClient: client,
            chatPersistence: chatPersistence,
            summarizationService: summarizationService,
            summaryViewModel: summaryVM,
            searchService: searchService
        ))
        _summaryVM = State(initialValue: summaryVM)
        _savedPromptsVM = State(initialValue: SavedPromptsViewModel())
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                statusVM: statusVM,
                chatVM: chatVM,
                summaryVM: summaryVM,
                savedPromptsVM: savedPromptsVM
            )
            .preferredColorScheme(.dark)
            .task { await statusVM.ensureRunning() }
            .onAppear { styleWindow() }
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("New Conversation") {
                    chatVM.newConversation()
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }

        Settings {
            SettingsView(chatVM: chatVM)
                .preferredColorScheme(.dark)
        }
    }

    private func styleWindow() {
        DispatchQueue.main.async {
            guard let window = NSApplication.shared.windows.first else { return }
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.backgroundColor = NSColor(Color.appWindowBg)
            window.center()
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
