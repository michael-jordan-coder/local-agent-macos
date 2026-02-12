# LocalAssistant Xcode -> Electron Migration Guide

## Goal
Rebuild the current macOS SwiftUI/Xcode app as an Electron app **without losing functionality**.

This guide is based on the current project in:
- `LocalAssistant.xcodeproj`
- `LocalAssistant/App`, `LocalAssistant/ViewModels`, `LocalAssistant/Views`, `LocalAssistant/Services`, `LocalAssistant/Models`

## 1. Current Feature Inventory (Must Keep)

## Core Runtime
- Local Ollama integration at `http://127.0.0.1:11434`
- App startup health check + auto-launch Ollama if needed
- Streaming token response rendering
- Cancel/stop streaming

## Chat Features
- Conversation list (create, delete, rename, pin, search, date-grouping)
- Per-conversation system prompt
- Mention/reference an earlier assistant message
- Image attachments (png/jpeg)
- Markdown rendering for assistant messages
- Code block rendering + copy-to-clipboard
- Copy assistant messages

## Prompt Library
- Save prompt templates
- Pin/unpin prompts
- Edit/delete prompts
- Apply a saved prompt to current conversation

## Summarization + Context Management
- Auto-summarize when message count > 40
- Keep only summary + last 16 messages
- Summary persisted to `summary.txt`

## Persistence
- JSON conversation files in `~/Library/Application Support/LocalAssistant/conversations`
- JSON saved prompts in `~/Library/Application Support/LocalAssistant/saved-prompts`
- Settings (currently `selectedModel`) persisted locally

## 2. Recommended Electron Stack
- Electron + TypeScript
- React + Vite for renderer UI
- `contextIsolation: true` + preload bridge
- `marked` or `markdown-it` for markdown rendering
- `highlight.js` or `shiki` for code blocks
- `sharp` for image downscale (replacement for `ImageProcessor`)
- `electron-store` (or keep custom JSON files for strict parity)

## 3. Target Architecture

## Main Process (`src/main`)
Owns privileged/system functionality:
- Ollama reachability, model list, streaming requests
- Launching Ollama process (`child_process.spawn`)
- File persistence for conversations/prompts/summary
- Image preprocessing (downscale/compress/base64)

## Preload (`src/preload`)
Exposes a small, typed API to renderer via `contextBridge`.

## Renderer (`src/renderer`)
Owns UI + state:
- Sidebar, chat panel, composer, system prompt panel, settings, prompt library
- Subscribes to streamed tokens from main process

## 4. Swift/Xcode -> Electron Mapping

| Current Swift file | Responsibility | Electron target |
|---|---|---|
| `LocalAssistant/App/LocalAssistantApp.swift` | App startup, service wiring, window setup | `src/main/index.ts` (BrowserWindow + startup orchestration) |
| `LocalAssistant/ViewModels/ChatViewModel.swift` | chat orchestration, send/stream, summarize, mention | `src/renderer/state/chatStore.ts` + IPC calls to main services |
| `LocalAssistant/ViewModels/AppStatusViewModel.swift` | Ollama readiness state | `src/renderer/state/appStatusStore.ts` + `ipcRenderer.invoke('ollama:ensureRunning')` |
| `LocalAssistant/Services/OllamaClient.swift` | tags/generate/stream/launch | `src/main/services/ollamaService.ts` |
| `LocalAssistant/Services/ChatPersistence.swift` | conversation JSON I/O | `src/main/services/conversationRepo.ts` |
| `LocalAssistant/Services/SavedPromptPersistence.swift` | prompt JSON I/O | `src/main/services/promptRepo.ts` |
| `LocalAssistant/Services/SummarizationService.swift` | summary generation and file | `src/main/services/summaryService.ts` |
| `LocalAssistant/Services/PromptBuilder.swift` | prompt construction | `src/main/services/promptBuilder.ts` |
| `LocalAssistant/Services/ImageProcessor.swift` | downscale + base64 cache | `src/main/services/imageService.ts` |
| `LocalAssistant/Views/*` | SwiftUI screens/components | React components in `src/renderer/components/*` |

## 5. Implementation Plan (Phased)

## Phase 0: Scaffold Electron App
From repo root:

```bash
npm create electron-vite@latest electron -- --template react-ts
cd electron
npm i
npm i sharp markdown-it highlight.js
```

## Phase 1: Define Shared Types
Create `src/shared/types.ts` with strict parity fields:
- `ChatMessage { id, role, content, images?, timestamp, mentionPreview? }`
- `Conversation { id, title, messages, createdAt, systemPrompt?, isPinned }`
- `SavedPrompt { id, title, content, createdAt, updatedAt, lastUsedAt?, isPinned }`

Use ISO date strings across IPC boundary.

## Phase 2: Build Main-Process Services
Implement these services first:
- `ollamaService.ts`
- `promptBuilder.ts`
- `conversationRepo.ts`
- `promptRepo.ts`
- `summaryService.ts`
- `imageService.ts`

Important parity rules to preserve:
- Ollama URL fixed to `127.0.0.1:11434`
- Summarization trigger: `> 40` messages
- Keep: last `16` messages + summary system message
- Mention truncation: `500` chars for prompt, `80` chars preview in saved user message
- Stream flush batching: about `180` chars or every `24ms`

## Phase 3: IPC Contract
Create typed IPC handlers/events.

Invoke channels:
- `ollama:ensureRunning`
- `ollama:fetchModels`
- `chat:loadAll`
- `chat:newConversation`
- `chat:updateConversation`
- `chat:deleteConversation`
- `chat:deleteAll`
- `chat:send` (starts a stream)
- `chat:stop`
- `prompt:loadAll`
- `prompt:save`
- `prompt:update`
- `prompt:delete`
- `summary:load`

Stream events (main -> renderer):
- `chat:streamToken` `{ conversationId, requestId, token }`
- `chat:streamDone` `{ conversationId, requestId }`
- `chat:streamError` `{ conversationId, requestId, message }`

## Phase 4: Rebuild UI in React
Suggested component mapping:
- `ContentView.swift` -> `AppLayout.tsx`
- `SidebarView.swift` -> `Sidebar.tsx`
- `ChatView.swift` + `MessageRowView.swift` -> `ChatThread.tsx` + `MessageItem.tsx`
- `ComposerView.swift` -> `Composer.tsx`
- `SystemPromptPanelView.swift` -> `SystemPromptPanel.tsx`
- `PromptLibraryView.swift` + detail/edit views -> `PromptLibrary/*`
- `SettingsView.swift` -> `SettingsDialog.tsx`

## Phase 5: Data Migration and Compatibility
To keep old user data:
- Read from `~/Library/Application Support/LocalAssistant/...` in Electron main process.
- Preserve same JSON field names.
- Keep backward-compatible defaults for missing legacy fields (`isPinned`, `updatedAt`, etc.).

## Phase 6: Packaging (macOS)
Use `electron-builder` for `.dmg`.

Required steps for distribution:
- macOS code signing
- Hardened runtime
- Notarization (Apple Developer account)

Your Xcode target currently has sandbox disabled; keep Electron unsandboxed unless you explicitly redesign around sandbox constraints.

## 6. Example Main-Process Snippets

## Launch Ollama (equivalent to `launchProcess()`)
```ts
import { spawn } from 'node:child_process';
import { access } from 'node:fs/promises';
import { constants } from 'node:fs';

const candidates: Array<[string, string[]]> = [
  ['/usr/local/bin/ollama', ['serve']],
  ['/opt/homebrew/bin/ollama', ['serve']],
  ['/usr/bin/env', ['ollama', 'serve']],
];

export async function launchOllama(): Promise<boolean> {
  for (const [bin, args] of candidates) {
    try {
      await access(bin, constants.X_OK);
      const child = spawn(bin, args, { stdio: 'ignore', detached: true });
      child.unref();
      return true;
    } catch {
      // try next
    }
  }
  return false;
}
```

## Streaming parse (JSONL)
```ts
export async function streamGenerate(
  body: Record<string, unknown>,
  onToken: (token: string) => void,
): Promise<void> {
  const res = await fetch('http://127.0.0.1:11434/api/generate', {
    method: 'POST',
    headers: { 'content-type': 'application/json', connection: 'keep-alive' },
    body: JSON.stringify({ ...body, stream: true }),
  });

  if (!res.body) throw new Error('No stream body');

  const reader = res.body.getReader();
  const decoder = new TextDecoder();
  let buffer = '';

  while (true) {
    const { value, done } = await reader.read();
    if (done) break;
    buffer += decoder.decode(value, { stream: true });

    const lines = buffer.split('\n');
    buffer = lines.pop() ?? '';

    for (const line of lines) {
      if (!line.trim()) continue;
      const chunk = JSON.parse(line) as { response?: string; done?: boolean };
      if (chunk.response) onToken(chunk.response);
      if (chunk.done) return;
    }
  }
}
```

## 7. Security Baseline
- `nodeIntegration: false`
- `contextIsolation: true`
- Validate every IPC input in main process
- Do not expose raw `ipcRenderer` to window
- Only expose narrow preload API (`window.localAssistant.*`)

## 8. Parity Test Checklist
Run before replacing the Xcode app:

1. App starts with Ollama already running.
2. App starts and launches Ollama when not running.
3. Streaming response appears progressively and can be stopped.
4. Image attachments are accepted, previewed, and sent.
5. Mention mode injects referenced content correctly.
6. Conversation CRUD/pin/rename/search works.
7. Prompt library CRUD/pin/apply/copy works.
8. Auto-summary triggers at >40 messages and trims to 16 recent.
9. Existing JSON data from Application Support loads unchanged.
10. Model picker loads `/api/tags` and persists selected model.

## 9. Suggested Migration Order for This Repo
1. Build Electron app in a new `electron/` folder (do not delete Swift project yet).
2. Port `Services` layer first (Ollama + persistence + summarization + prompt builder).
3. Port `ChatViewModel` behavior into renderer state store with IPC bridge.
4. Rebuild UI and wire to already-working backend services.
5. Run parity checklist.
6. Freeze Swift app only after Electron parity is complete.

This order minimizes risk and lets you verify behavior incrementally.
