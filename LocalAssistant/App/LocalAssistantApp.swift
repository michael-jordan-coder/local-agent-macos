import SwiftUI
import ServiceManagement

@main
struct LocalAssistantApp: App {
    @State private var statusVM: AppStatusViewModel
    @State private var chatVM: ChatViewModel
    @State private var summaryVM: SummaryViewModel
    @State private var savedPromptsVM: SavedPromptsViewModel

    init() {
        let isPreview = RuntimeEnvironment.isXcodePreview

        if !isPreview {
            try? SMAppService.mainApp.register()
        }

        let client = OllamaClient()
        let chatPersistence: ChatPersistence
        let summarizationService: SummarizationService
        let searchService = SearchService()

        if isPreview {
            let tempDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
                .appendingPathComponent("LocalAssistantPreview", isDirectory: true)
            chatPersistence = ChatPersistence(directory: tempDir.appendingPathComponent("conversations", isDirectory: true))
            summarizationService = SummarizationService(
                ollamaClient: client,
                fileURL: tempDir.appendingPathComponent("summary.txt")
            )
        } else {
            chatPersistence = ChatPersistence()
            summarizationService = SummarizationService(ollamaClient: client)
        }

        let summaryVM = SummaryViewModel(service: summarizationService)

        _statusVM = State(initialValue: isPreview
            ? AppStatusViewModel(previewStatus: .ready)
            : AppStatusViewModel(client: client)
        )
        _chatVM = State(initialValue: ChatViewModel(
            ollamaClient: client,
            chatPersistence: chatPersistence,
            summarizationService: summarizationService,
            summaryViewModel: summaryVM,
            searchService: searchService
        ))
        _summaryVM = State(initialValue: summaryVM)
        if isPreview {
            let tempDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
                .appendingPathComponent("LocalAssistantPreview", isDirectory: true)
            _savedPromptsVM = State(initialValue: SavedPromptsViewModel(
                persistence: SavedPromptPersistence(directory: tempDir.appendingPathComponent("saved-prompts", isDirectory: true))
            ))
        } else {
            _savedPromptsVM = State(initialValue: SavedPromptsViewModel())
        }
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
            .task {
                guard !RuntimeEnvironment.isXcodePreview else { return }
                await statusVM.ensureRunning()
            }
            .onAppear {
                guard !RuntimeEnvironment.isXcodePreview else { return }
                styleWindow()
            }
        }
        .windowToolbarStyle(.unified(showsTitle: false))
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
            window.title = ""
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.backgroundColor = NSColor(Color.appWindowBg)
            window.center()
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
