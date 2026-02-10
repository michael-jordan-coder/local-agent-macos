# Implementation Plan: Prompt Library — Card-Based UI

## What Already Exists
- **`SavedPrompt` model** — `id`, `title`, `content`, `createdAt`, `lastUsedAt`, `isPinned`
- **`SavedPromptPersistence`** — JSON CRUD in `~/Library/Application Support/LocalAssistant/saved-prompts/`
- **`SavedPromptsViewModel`** — full ViewModel with add/update/delete/pin/sort/markUsed
- **`SavedPromptsListView`** — sidebar list with search, pin/delete context menus
- **`SavedPromptEditorView`** — detail editor with save/apply/delete
- **`ContentView`** — `SidebarTab.prompts` already routes to the above

## What Needs to Change

### Task 1: Extend Model — Add `updatedAt` field
**File:** `Models/SavedPrompt.swift`
- Add `updatedAt: Date` property
- Add backward-compatible `init(from decoder:)` that decodes `updatedAt` with `decodeIfPresent`, falling back to `createdAt`
- Default `updatedAt` to `.now` in the main `init`

### Task 2: Update ViewModel — Add `copy()` + `updatedAt` handling
**File:** `ViewModels/SavedPromptsViewModel.swift`
- `updatePrompt()`: set `updatedAt = .now` on save
- Add `func copyToClipboard(id: UUID)` using `NSPasteboard.general`
- Update `sortedPrompts` to sort by `updatedAt` (descending) instead of `lastUsedAt ?? createdAt`

### Task 3: Build Card-Based Library View
**New file:** `Views/PromptLibrary/PromptLibraryView.swift`
- Top-level view shown in the detail column when sidebar tab is `.prompts`
- `.searchable` text field filtering by title + content (case-insensitive)
- `LazyVGrid` with adaptive columns for card layout
- Empty state for no prompts / no search results
- "New Prompt" button in a toolbar or header area

### Task 4: Build Prompt Card Component
**New file:** `Views/PromptLibrary/PromptCardView.swift`
- Shows: title, snippet (first ~3 lines of content), updatedAt date
- Hover state reveals action buttons: Copy, Edit, Delete
- Right-click context menu: Copy / Edit / Delete
- Visual design: rounded rect card with subtle border, dark theme consistent

### Task 5: Build Edit Sheet
**New file:** `Views/PromptLibrary/PromptEditSheet.swift`
- Sheet with title TextField + content TextEditor
- Save button (disabled if content is empty)
- Cancel button
- Used for both creating new and editing existing prompts

### Task 6: Wire Into ContentView
**File:** `Views/ContentView.swift`
- Replace `SavedPromptEditorView` in the detail column with `PromptLibraryView`
- Remove the old `SavedPromptsListView` from the sidebar (the library view handles everything in the detail pane now)
- Keep the sidebar tab toggle — `.prompts` now shows the full library in detail
- Sidebar in prompts mode can either show a minimal list or be empty (library is the detail)

### Task 7: Delete Confirmation
- Built into `PromptCardView` or `PromptLibraryView`
- `.confirmationDialog` on delete action: "Delete this prompt?" with destructive confirm

## File Change Summary

| File | Action |
|------|--------|
| `Models/SavedPrompt.swift` | Modify — add `updatedAt`, backward-compat decoding |
| `ViewModels/SavedPromptsViewModel.swift` | Modify — add `copy()`, `updatedAt` handling |
| `Views/PromptLibrary/PromptLibraryView.swift` | **New** — card grid with search |
| `Views/PromptLibrary/PromptCardView.swift` | **New** — individual card component |
| `Views/PromptLibrary/PromptEditSheet.swift` | **New** — edit/create sheet |
| `Views/ContentView.swift` | Modify — route to new library view |

## Design Decisions
1. **Reuse existing persistence** — `SavedPromptPersistence` and `SavedPromptsViewModel` are solid. No need to create new stores.
2. **No SwiftData** — project uses JSON persistence throughout. Staying consistent.
3. **Card grid in detail pane** — the library lives in the detail column. Sidebar can show a simple list or be hidden.
4. **Keep "Apply to Conversation"** — cards should have an "Apply" action that sets the prompt as the system prompt for the current conversation and switches back to chats tab.
5. **Dark theme** — consistent with existing `Color(white: ...)` palette used throughout.
