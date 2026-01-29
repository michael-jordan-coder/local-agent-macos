# LocalAssistant - Project Memory

## Overview
Native macOS desktop app (SwiftUI) providing a chat UI for locally-running Ollama LLM server. No external dependencies.

## Architecture
- **Pattern:** MVVM with SwiftUI + `@Observable` macro
- **Entry:** `LocalAssistantApp.swift` → creates `OllamaManager`, passes to `ContentView`
- **State:** `OllamaManager` — observable, manages Ollama process lifecycle (idle → checking → starting → ready → failed)
- **UI:** `ContentView` — chat interface with streaming responses, status indicators
- **Networking:** HTTP to `127.0.0.1:11434` (Ollama default), streaming JSON line-by-line via `URLSession.bytes`

## File Map
| File | Role |
|------|------|
| `LocalAssistantApp.swift` | App entry, window setup, ServiceManagement registration |
| `ContentView.swift` | Main chat UI, sends prompts to Ollama `/api/generate`, streams responses |
| `OllamaManager.swift` | Ollama process detection/launch, status state machine |
| `Info.plist` | NSAllowsLocalNetworking, local network usage description |
| `LocalAssistant.entitlements` | Empty (sandbox disabled) |

## Key Details
- **Model:** Hardcoded `llama3`
- **Sandbox:** Disabled (`ENABLE_APP_SANDBOX = NO`)
- **Ollama paths tried:** `/usr/local/bin/ollama`, `/opt/homebrew/bin/ollama`, `/usr/bin/env ollama`
- **Startup timeout:** 12 seconds, polls every 400ms
- **Min window:** 500×400
- **Deployment target:** macOS 26.2
- **Bundle ID:** `daniels.LocalAssistant`
- **Team:** S37Z3294YB

## Decisions & Conventions
- No third-party dependencies — Foundation + SwiftUI only
- Process stdout/stderr sent to null device
- Default placeholder text is intentionally irreverent

## Status
- Single commit (`0fcf35e Initial Commit`) + uncommitted work adding OllamaManager, entitlements, Info.plist, and refactored views
