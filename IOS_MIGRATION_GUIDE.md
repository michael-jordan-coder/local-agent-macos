# LocalAssistant iOS Migration Guide

## Goal
Port the current macOS SwiftUI app to iOS while maintaining all core functionality and optimizing the UX for mobile devices.

This guide is based on the current project in:
- `LocalAssistant.xcodeproj`
- `LocalAssistant/App`, `LocalAssistant/ViewModels`, `LocalAssistant/Views`, `LocalAssistant/Services`, `LocalAssistant/Models`

## 1. Current Feature Inventory (Must Keep)

### Core Runtime
- Local Ollama integration at `http://127.0.0.1:11434`
- App startup health check + auto-launch Ollama if needed (iOS: show warning/instructions instead)
- Streaming token response rendering
- Cancel/stop streaming

### Chat Features
- Conversation list (create, delete, rename, pin, search, date-grouping)
- Per-conversation system prompt
- Mention/reference an earlier assistant message
- Image attachments (png/jpeg)
- Markdown rendering for assistant messages
- Code block rendering + copy-to-clipboard
- Copy assistant messages

### Prompt Library
- Save prompt templates
- Pin/unpin prompts
- Edit/delete prompts
- Apply a saved prompt to current conversation

### Summarization + Context Management
- Auto-summarize when message count > 40
- Keep only summary + last 16 messages
- Summary persisted to `summary.txt`

### Persistence
- JSON conversation files in `~/Library/Application Support/LocalAssistant/conversations`
- JSON saved prompts in `~/Library/Application Support/LocalAssistant/saved-prompts`
- Settings (selectedModel) persisted locally

## 2. iOS-Specific Considerations

### Network Connectivity
- **Challenge**: iOS apps typically run behind cellular/WiFi, not localhost
- **Solution**: Support remote Ollama instances via custom URL config
  - Allow users to set Ollama server URL in Settings
  - Support HTTPS for remote Ollama servers
  - Implement connection retry logic with exponential backoff
  - Cache models locally for offline browsing

### Data Persistence
- Use `FileManager` in `~/Documents/LocalAssistant/` instead of Application Support
- Implement CloudKit syncing (optional) for multi-device sync
- Use UserDefaults for app settings
- Consider Core Data for larger datasets (conversations, prompts)

### App Lifecycle
- Save conversation state on app backgrounding
- Resume last active conversation on app launch
- Handle memory warnings gracefully
- Implement state restoration for interrupted operations

## 3. Recommended iOS Tech Stack

### Core Framework
- **SwiftUI** 2.0+ (iOS 15+)
- **Combine** for reactive data flow
- **AsyncAwait** for network requests

### Networking
- **URLSession** with `AsyncStream` for streaming responses
- **Alamofire** (optional) for advanced networking
- Support HTTP/2 server push

### UI Components
- **MarkdownUI** or **MarkdownView** for markdown rendering
- **SyntaxHighlighter** for code blocks
- **PhotosUI** for image selection (iOS 16+)
- **UIViewRepresentable** for legacy components if needed

### Storage
- **FileManager** for JSON files
- **UserDefaults** for simple settings
- **Core Data** (optional) for complex queries
- **Keychain** for sensitive data (API keys if needed)

### Image Handling
- **ImageRenderer** (iOS 16+) for image downscaling
- Native image compression via `UIImage`

## 4. Project Structure

```
LocalAssistant/
├── App/
│   ├── LocalAssistantApp.swift
│   └── AppDelegate.swift (if needed for lifecycle)
├── Views/
│   ├── ContentView.swift
│   ├── ConversationListView.swift
│   ├── ChatView.swift
│   ├── MessageView.swift
│   ├── PromptLibraryView.swift
│   ├── SettingsView.swift
│   └── Components/
│       ├── MarkdownView.swift
│       ├── CodeBlockView.swift
│       ├── ImageAttachmentView.swift
│       └── ConversationCell.swift
├── ViewModels/
│   ├── ChatViewModel.swift
│   ├── ConversationListViewModel.swift
│   ├── PromptLibraryViewModel.swift
│   └── SettingsViewModel.swift
├── Models/
│   ├── Conversation.swift
│   ├── Message.swift
│   ├── SavedPrompt.swift
│   └── AppSettings.swift
├── Services/
│   ├── OllamaService.swift
│   ├── StorageService.swift
│   ├── ImageProcessingService.swift
│   └── SummarizationService.swift
└── Resources/
    ├── Localizable.strings (i18n)
    └── Assets.xcassets
```

## 5. UI Adaptations for iOS

### Chat View
- Single-column layout (no conversation sidebar on iPhone)
- Use NavigationStack for conversation navigation
- Implement pull-to-refresh for loading older messages
- Bottom message input bar with:
  - Text input field
  - Image attachment button (⬆️ or 📎)
  - Send button
  - Prompt library quick-access (🎯 button)

### Conversation List
- Full-screen list on iPhone
- Use NavigationSplitView on iPad for sidebar
- Swipe-to-delete conversations
- Long-press context menu for pin/unpin/rename/delete
- Search bar at top with live filtering

### Prompt Library
- Tab or Sheet-based access
- Grid layout on iPad, list on iPhone
- In-place editing with swipe actions

### Settings
- Standard Settings app integration with SettingsView
- Support for dynamic type (larger text sizes)
- Haptic feedback for interactions

## 6. iOS-Specific Features to Add

### Adaptive UI
- Support Dynamic Type (accessibility)
- Respect Light/Dark mode preferences
- iPad-optimized layouts (SplitView, Sidebar)

### Keyboard Management
- Auto-dismiss keyboard after sending message
- Safe Area handling for notch/Dynamic Island
- Input accessory view for hardware keyboard

### Performance Optimizations
- Lazy load conversation lists (pagination)
- Image downsampling on receipt
- Memory management for large conversations
- Debounce search queries

### User Experience
- Activity indicator during connection attempts
- Network status indicator in UI
- Toast notifications for errors
- Haptic feedback on send

## 7. Network Architecture (Critical for iOS)

### Ollama Service Refactor
```swift
// Before (macOS localhost)
let baseURL = "http://127.0.0.1:11434"

// After (iOS flexible)
struct OllamaConfig: Codable {
    var baseURL: String  // e.g., "http://192.168.1.100:11434"
    var timeout: TimeInterval = 30
    var requiresAuth: Bool = false
    var username: String?
    var password: String?
}
```

### Connection Flow
1. Read OllamaConfig from UserDefaults
2. Attempt connection with retry logic
3. Show setup screen if unreachable
4. Allow users to configure custom URL in Settings
5. Implement network status monitoring with `Network.framework`

## 8. Deployment Checklist

- [ ] iOS 15+ minimum deployment target
- [ ] iPad optimization (landscape, split view)
- [ ] Network connectivity handling
- [ ] Image attachment security (sandboxing)
- [ ] Data privacy compliance (GDPR, etc.)
- [ ] App Store submission review compliance
- [ ] Beta testing on various device sizes
- [ ] Accessibility testing (VoiceOver, Dynamic Type)
- [ ] Battery and memory profiling

## 9. Migration Path (Recommended Order)

1. **Phase 1**: Core UI + Navigation
   - ContentView with tab/navigation structure
   - ConversationListView
   - ChatView with basic messaging

2. **Phase 2**: Ollama Integration
   - Refactor OllamaService for flexible network
   - Implement streaming responses
   - Error handling and retry logic

3. **Phase 3**: Rich Features
   - Markdown rendering
   - Image attachments
   - Code block syntax highlighting

4. **Phase 4**: Polish & Optimization
   - Settings and configuration
   - Prompt library
   - Accessibility and performance

5. **Phase 5**: Testing & Deployment
   - Unit and UI tests
   - Beta testing
   - App Store submission

## 10. Known Challenges & Solutions

| Challenge | iOS Impact | Solution |
|-----------|-----------|----------|
| Localhost networking | Cannot access host machine's Ollama | Support remote Ollama URLs |
| Background execution | App suspends when backgrounded | Save state on pause, restore on resume |
| Memory constraints | Limited RAM on iPhones | Implement lazy loading, pagination |
| Network variability | WiFi/cellular switching | Implement robust retry and offline caching |
| File system access | Sandboxed app directory | Use FileManager in Documents folder |
| Long-running tasks | 30s execution limit in background | Implement foreground streaming only |

## 11. Xcode Project Setup

```bash
# Create new iOS target in existing project
# File > New > Target > iOS App

# Or create separate project (recommended for cleaner separation)
xcode new LocalAssistant-iOS --type app

# Shared code approach:
# - Keep Models in shared framework
# - Keep Services in shared framework
# - Platform-specific Views and ViewModels
```

## 12. Testing Strategy

### Unit Tests
- OllamaService network calls
- Message processing and summarization
- Data model validation
- Storage layer operations

### UI Tests
- Navigation flow
- Message sending/receiving
- Image attachment upload
- Settings persistence

### Manual Testing
- Real device testing (iPhone 13, 14, 15)
- iPad testing (portrait + landscape)
- Various network conditions (Xcode Network Link Conditioner)
- Memory pressure scenarios

## 13. Future Enhancements (Post-Launch)

- Push notifications for model responses
- Voice input (Speech Recognition framework)
- Photo library integration for context
- iCloud sync for conversations
- Apple Watch companion app
- Shortcuts automation support
- Share sheet integration
