# CLAUDE.md — LocalAssistant

## Project Overview
Native macOS desktop app (SwiftUI) providing a chat UI for locally-running Ollama LLM server. Zero external dependencies — Foundation + SwiftUI only.

## Tech Stack
- **Language:** Swift
- **UI Framework:** SwiftUI with `@Observable` macro
- **Platform:** macOS 26.2
- **Build System:** Xcode (.xcodeproj)
- **Dependencies:** None (Apple frameworks only)
- **Bundle ID:** `daniels.LocalAssistant`

## Architecture
MVVM pattern with reactive SwiftUI state management.

```
App/                → App entry point
Models/             → Data structures (ChatMessage, Conversation, MemoryModels)
ViewModels/         → @Observable state managers (Chat, AppStatus, Memory, Summary)
Views/              → SwiftUI views (ContentView, ChatView, ComposerView, MessageRowView)
Services/           → Business logic (OllamaClient, PromptBuilder, Persistence, Summarization)
```

### Data Flow
Views → ViewModels (`@Observable`) → Services → OllamaClient → Local Ollama HTTP API

### Key Components
- **OllamaClient** — HTTP client for Ollama at `127.0.0.1:11434`, handles streaming via `URLSession.bytes`
- **PromptBuilder** — Constructs prompts with [SYSTEM], [MEMORY], [SUMMARY], [CONVERSATION] sections
- **ChatPersistence** — Saves conversations as JSON files in `~/Library/Application Support/LocalAssistant/conversations/`
- **MemoryPersistence** — Saves user profile/facts to `~/Library/Application Support/LocalAssistant/memory.json`
- **SummarizationService** — Auto-summarizes when conversations exceed 40 messages, keeps last 16

## Conventions
- No third-party dependencies — use only Foundation and SwiftUI
- Use `@Observable` macro (not `@StateObject`/`ObservableObject`)
- Use `@Bindable` for two-way data binding in views
- Ollama model is hardcoded to `llama3`
- App sandbox is disabled — needed for process execution and local network access
- Process stdout/stderr redirected to null device
- Persistence uses JSON encoding in Application Support directory

## Build & Run
Open `LocalAssistant.xcodeproj` in Xcode and build (Cmd+B) / run (Cmd+R). Requires Ollama installed locally.
