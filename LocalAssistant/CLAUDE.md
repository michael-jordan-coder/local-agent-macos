# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview
Native macOS desktop app (SwiftUI) providing a chat UI for locally-running Ollama LLM server. Zero cloud dependencies — all inference on-device via Ollama at `127.0.0.1:11434`.

## Tech Stack
- **Language:** Swift — **UI:** SwiftUI with `@Observable` macro — **Platform:** macOS 26.2
- **Build System:** Xcode (.xcodeproj) — **Bundle ID:** `daniels.LocalAssistant`
- **Dependencies:** Apple frameworks only (Foundation, SwiftUI, CryptoKit, ServiceManagement, Markdown)

## Build & Run
```bash
# Build
xcodebuild -project LocalAssistant.xcodeproj -scheme LocalAssistant -configuration Debug build

# Run
# Open LocalAssistant.xcodeproj in Xcode → Cmd+R. Requires Ollama installed locally.

# Tests (in-source, no separate test target)
# Tests live inside the app target guarded by #if canImport(XCTest)
# Run via Xcode: Cmd+U (Product → Test)
```

## Architecture
MVVM with `@Observable` macro. All ViewModels are `@MainActor @Observable final class`. Services are stateless structs injected via constructors.

### Dependency Wiring
`LocalAssistantApp.init()` creates all services and ViewModels once, passes them down through the view hierarchy. No environment objects — direct property injection.

### Data Flow (send message)
```
ComposerView → ChatViewModel.send()
  → ImageProcessor.process() (downscale to 1024px, JPEG 82%, SHA256-keyed base64 cache)
  → PromptBuilder.build() (assembles [SYSTEM] + [SUMMARY] + [CONVERSATION] + [SEARCH_RESULTS] + [REFERENCED] + user message)
  → OllamaClient.streamGenerate() (URLSession.bytes, JSONL)
  → tokens batched (180 chars OR 24ms flush interval) → UI update
  → ChatPersistence.save() after stream complete
  → auto-summarize if messages > 40 (trims to last 16 + summary)
```

### Prompt Construction (PromptBuilder)
Static enum utility. Sections assembled in order: `[SYSTEM]` (hardcoded instructions) → `[SUMMARY]` (if exists) → `[CONVERSATION]` (last 16 messages) → `[SEARCH_RESULTS]` (if `/search` used) → `[REFERENCED]` (if mention selected, first 500 chars) → new user message.

### Markdown Rendering Pipeline
Two-layer system — the current path used in `MessageRowView`:
```
MarkdownView(markdown:theme:)
  → MarkdownRenderer.render() (Apple swift-markdown AST walker → MarkdownDocumentModel)
  → MarkdownBlocksView renders blocks: headings, paragraphs, lists, tables, blockquotes, thematic breaks
  → Code blocks: SyntaxHighlighter (regex-based, Cursor Dark palette — Swift, JS/TS, Python, CSS, generic)
  → Inline text: MarkdownInlineAttributedBuilder → AttributedString
```
Legacy `AssistantMarkdownTokenizer` still exists (tested) — splits raw text into `.markdown`/`.code` segments for streaming unclosed fences.

### Key Services
- **OllamaClient** — Shared `URLSession` (120s timeout, max 2 conn/host). Endpoints: `/api/tags`, `/api/generate` (stream + non-stream), reachability check, process launch (tries 3 binary paths)
- **SearchService** — DuckDuckGo HTML scraping with regex parser, triggered by `/search` command
- **ChatPersistence** — One JSON file per conversation in `~/Library/Application Support/LocalAssistant/conversations/`
- **SavedPromptPersistence** — Same pattern, `saved-prompts/` directory
- **SummarizationService** — Non-streaming via `OllamaClient.generate()`, saves to `summary.txt`, truncates input at 16k chars

### ViewModels
- **ChatViewModel** — Central orchestrator: conversations, streaming, persistence, summarization, mention state, `/search` command
- **SidebarViewModel** — Projects ChatViewModel state into sorted/grouped sections (pinned, date-grouped). Manages rename flow, tab switching (Chats/Prompts)
- **AppStatusViewModel** — Polls Ollama reachability, auto-launches process, status enum (idle/checking/starting/ready/failed)
- **ModelToolbarSwitcherViewModel** — Fetches model list from Ollama, persists selection to UserDefaults. Self-contained (created via `@State` in view)
- **SavedPromptsViewModel** — CRUD for saved prompt library

## Conventions
- No third-party dependencies — Apple frameworks only
- Use `@Observable` macro, never `@StateObject`/`ObservableObject`
- Use `@Bindable` for two-way data binding in views
- App sandbox disabled — required for `Process.run()` (Ollama launch) and local network access
- Model selection stored in UserDefaults (`selectedModel`), changeable via toolbar switcher
- Persistence uses `try?` throughout — errors silently swallowed
- All async code is pure async/await — no Combine
- Preview isolation: `RuntimeEnvironment.isXcodePreview` gates Ollama startup; services accept temp directory overloads for previews
- Window styling: transparent titlebar, forced dark background (`Color(white: 0.08)`)
- `SMAppService.mainApp.register()` enables auto-launch at login

### Persistence Locations
- Conversations: `~/Library/Application Support/LocalAssistant/conversations/{UUID}.json`
- Saved prompts: `~/Library/Application Support/LocalAssistant/saved-prompts/{UUID}.json`
- Summary: `~/Library/Application Support/LocalAssistant/summary.txt`
- Settings: UserDefaults (`selectedModel`)
