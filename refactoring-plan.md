# Open WebUI iOS Refactoring Plan

This document outlines a comprehensive plan for refactoring the Open WebUI iOS application using modern Swift best practices. The plan is based on an analysis of the current codebase and aims to enhance performance, maintainability, and developer experience.

## Key Modernization Areas

1. **Swift Concurrency**
   - Replace Combine with modern async/await
   - Implement structured concurrency for better error handling
   - Use Actor model for thread safety

2. **State Management**
   - Move from @ObservableObject to the newer @Observable macro
   - Implement the Swift Composable Architecture (TCA) pattern
   - Adopt more structured binding patterns for views

3. **Network & Storage Layer**
   - Modernize network requests with URLSession async APIs
   - Implement better credential management
   - Enhance local persistence with improved Core Data integration

4. **UI Architecture**
   - Standardize responsive design patterns
   - Improve accessibility support
   - Enhance custom components

## Detailed Implementation Plan

### Phase 1: Modernize Core Services with Swift Concurrency

#### 1. Create Actor-Based Service Layer

```swift
// Original OllamaService implementation with Combine
final class OllamaService: ObservableObject {
    @Published var isConnected: Bool = false
    
    func fetchModels() -> AnyPublisher<[AIModel], Error> {
        // Implementation using Combine
    }
}

// Refactored version with Swift Actor
actor OllamaService {
    @MainActor @Published private(set) var isConnected: Bool = false
    
    func fetchModels() async throws -> [AIModel] {
        // Implementation using async/await
    }
    
    @MainActor func updateConnectionStatus(_ connected: Bool) {
        isConnected = connected
    }
}
```

#### 2. Refactor WebSocketService with AsyncStream

```swift
// Current WebSocketService using Combine
final class WebSocketService {
    private var webSocketTask: URLSessionWebSocketTask?
    private var publishers = Set<AnyCancellable>()
    
    func connect() -> AnyPublisher<WebSocketMessage, Error> {
        // Implementation using Combine
    }
}

// Refactored version with AsyncStream
actor WebSocketService {
    private var webSocketTask: URLSessionWebSocketTask?
    private var continuations: [String: AsyncStream<WebSocketMessage>.Continuation] = [:]
    
    func connect() -> AsyncStream<WebSocketMessage> {
        return AsyncStream { continuation in
            // Implementation using AsyncStream
            // Store continuation for later cancellation
        }
    }
    
    func disconnect(id: String) {
        continuations[id]?.finish()
        continuations[id] = nil
        
        if continuations.isEmpty {
            webSocketTask?.cancel()
            webSocketTask = nil
        }
    }
}
```

#### 3. KeychainService Modernization

```swift
// Current implementation with Combine
final class KeychainService {
    func storeAPIKey(_ key: String, forProvider: String) -> AnyPublisher<Void, Error> {
        // Implementation using Combine
    }
}

// Refactored version as an actor
actor KeychainService {
    func storeAPIKey(_ key: String, forProvider: String) async throws {
        // Implementation using async/await
    }
    
    func getAPIKey(forProvider: String) async throws -> String {
        // Implementation using async/await
    }
}
```

### Phase 2: Implement Core Architecture Patterns

#### 1. Adopt The Composable Architecture (TCA)

Create a foundation for using TCA principles:

```swift
// Feature definition
@Reducer
struct ChatFeature {
    @ObservableState
    struct State: Equatable {
        var messages: [Message] = []
        var isStreaming: Bool = false
        var currentInput: String = ""
        var selectedModel: AIModel?
    }
    
    enum Action {
        case messageInputChanged(String)
        case sendButtonTapped
        case messageReceived(String)
        case streamingStarted
        case streamingEnded
        case modelSelected(AIModel)
    }
    
    @Dependency(\.ollamaClient) var ollamaClient
    @Dependency(\.storageClient) var storageClient
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .messageInputChanged(input):
                state.currentInput = input
                return .none
                
            case .sendButtonTapped:
                guard !state.currentInput.isEmpty, let model = state.selectedModel else {
                    return .none
                }
                
                let message = Message(role: .user, content: state.currentInput)
                state.messages.append(message)
                state.currentInput = ""
                
                return .run { [messages = state.messages] send in
                    await send(.streamingStarted)
                    
                    do {
                        for try await chunk in ollamaClient.streamChat(
                            messages: messages, 
                            model: model
                        ) {
                            await send(.messageReceived(chunk))
                        }
                    } catch {
                        // Handle errors
                    }
                    
                    await send(.streamingEnded)
                }
                
            case let .messageReceived(content):
                if state.isStreaming {
                    if var lastMessage = state.messages.last, lastMessage.role == .assistant {
                        lastMessage.content += content
                        state.messages[state.messages.count - 1] = lastMessage
                    } else {
                        let newMessage = Message(role: .assistant, content: content)
                        state.messages.append(newMessage)
                    }
                }
                return .none
                
            case .streamingStarted:
                state.isStreaming = true
                return .none
                
            case .streamingEnded:
                state.isStreaming = false
                return .run { [messages = state.messages] _ in
                    try await storageClient.saveMessages(messages)
                }
                
            case let .modelSelected(model):
                state.selectedModel = model
                return .none
            }
        }
    }
}
```

#### 2. Define Dependencies Using Protocols

```swift
// Define protocol-based clients
protocol OllamaClientProtocol {
    func streamChat(messages: [Message], model: AIModel) -> AsyncThrowingStream<String, Error>
    func listModels() async throws -> [AIModel]
}

protocol StorageClientProtocol {
    func saveMessages(_ messages: [Message]) async throws
    func loadConversation(id: UUID) async throws -> [Message]
    func listConversations() async throws -> [Conversation]
}

// Create dependency registry
extension DependencyValues {
    var ollamaClient: OllamaClientProtocol {
        get { self[OllamaClient.self] }
        set { self[OllamaClient.self] = newValue }
    }
    
    var storageClient: StorageClientProtocol {
        get { self[StorageClient.self] }
        set { self[StorageClient.self] = newValue }
    }
}

// Implement live dependencies
struct OllamaClient: OllamaClientProtocol, DependencyKey {
    static let liveValue: OllamaClientProtocol = OllamaClient()
    
    func streamChat(messages: [Message], model: AIModel) -> AsyncThrowingStream<String, Error> {
        // Implementation
    }
    
    func listModels() async throws -> [AIModel] {
        // Implementation
    }
}
```

### Phase 3: UI Modernization

#### 1. Refactor Views with More Composition

```swift
// Current view implementation
struct ChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    
    var body: some View {
        VStack {
            // Many lines of implementation
        }
    }
}

// Refactored view with better composition
struct ChatView: View {
    @Bindable var store: StoreOf<ChatFeature>
    
    var body: some View {
        VStack {
            MessageListView(messages: store.messages)
            
            if store.isStreaming {
                TypingIndicator()
            }
            
            MessageInputView(
                text: $store.binding.currentInput,
                onSend: { store.send(.sendButtonTapped) }
            )
        }
    }
}

// Extracted reusable components
struct MessageListView: View {
    let messages: [Message]
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                ForEach(messages) { message in
                    MessageView(message: message)
                }
            }
            .padding()
        }
    }
}

struct MessageInputView: View {
    @Binding var text: String
    let onSend: () -> Void
    
    var body: some View {
        HStack {
            TextField("Type a message...", text: $text)
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(20)
            
            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
            }
            .disabled(text.isEmpty)
        }
        .padding()
    }
}
```

#### 2. Improve Accessibility

```swift
struct MessageView: View {
    let message: Message
    
    var body: some View {
        VStack(alignment: message.role == .user ? .trailing : .leading) {
            Text(message.role.rawValue.capitalized)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(message.content)
                .padding()
                .background(message.role == .user ? Color.blue : Color(.systemGray5))
                .foregroundColor(message.role == .user ? .white : .primary)
                .cornerRadius(12)
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(message.role.rawValue) said: \(message.content)")
    }
}
```

### Phase 4: Core Data and Storage Modernization

#### 1. Improve Core Data Integration

```swift
actor StorageService: StorageClientProtocol {
    private let container: NSPersistentContainer
    private let backgroundContext: NSManagedObjectContext
    
    init() {
        container = NSPersistentContainer(name: "OpenWebUI")
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Failed to load Core Data stack: \(error)")
            }
        }
        
        backgroundContext = container.newBackgroundContext()
        backgroundContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        backgroundContext.automaticallyMergesChangesFromParent = true
    }
    
    func saveMessages(_ messages: [Message]) async throws {
        try await backgroundContext.perform {
            // Implementation
            try self.backgroundContext.save()
        }
    }
    
    func loadConversation(id: UUID) async throws -> [Message] {
        try await backgroundContext.perform {
            // Implementation using NSPredicate
        }
    }
    
    func listConversations() async throws -> [Conversation] {
        try await backgroundContext.perform {
            // Implementation
        }
    }
}
```

#### 2. Implement Paginated Loading

```swift
extension StorageService {
    func loadConversationPaginated(id: UUID, page: Int, pageSize: Int) async throws -> [Message] {
        try await backgroundContext.perform {
            let fetchRequest: NSFetchRequest<MessageEntity> = MessageEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "conversationID == %@", id as CVarArg)
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
            fetchRequest.fetchLimit = pageSize
            fetchRequest.fetchOffset = page * pageSize
            
            let entities = try fetchRequest.execute()
            return entities.map { entity in
                // Convert entity to Message
                Message(/* ... */)
            }
        }
    }
}
```

### Phase 5: Performance Optimizations

#### 1. Improve Memory Management

```swift
// Add to ChatFeature
struct ChatFeature {
    // ...existing code
    
    enum CancelID { case chatStream }
    
    // Inside the reducer body
    case .streamingEnded:
        state.isStreaming = false
        return .concatenate(
            .cancel(CancelID.chatStream),
            .run { [messages = state.messages] _ in
                try await storageClient.saveMessages(messages)
            }
        )
        
    case .cancelStreaming:
        state.isStreaming = false
        return .cancel(CancelID.chatStream)
}
```

#### 2. Implement Lazy Loading for UI Elements

```swift
struct ConversationListView: View {
    @Bindable var store: StoreOf<ConversationListFeature>
    
    var body: some View {
        List {
            ForEach(store.conversations) { conversation in
                NavigationLink(
                    destination: LazyView(
                        ChatView(
                            store: store.scope(
                                state: \.chat,
                                action: \.chat
                            )
                        )
                    )
                ) {
                    ConversationRow(conversation: conversation)
                }
            }
        }
        .refreshable {
            await store.send(.refresh).finish()
        }
    }
}

struct LazyView<Content: View>: View {
    let build: () -> Content
    
    init(_ build: @autoclosure @escaping () -> Content) {
        self.build = build
    }
    
    var body: Content {
        build()
    }
}
```

## Implementation Phases

### Stage 1: Infrastructure Modernization
- Refactor service layer to use actors
- Convert network requests to async/await
- Update storage services to use Swift Concurrency

### Stage 2: State Management Overhaul
- Implement TCA pattern for one or two key features
- Create dependency protocols and implementations
- Add test infrastructure

### Stage 3: UI Modernization
- Refactor views with better composition
- Enhance accessibility
- Implement responsive design improvements

### Stage 4: Performance Optimization
- Add memory management optimizations
- Implement efficient data loading patterns
- Fine-tune UI rendering

## Testing Strategy

- Implement TCA TestStore for unit testing
- Create in-memory Core Data stack for testing
- Add UI tests using ViewInspector or XCTest
- Create performance benchmarks

## Migration Plan

To minimize disruption, implement changes incrementally:

1. Start with infrastructure services (non-UI)
2. Gradually migrate individual screens/features
3. Update the dependency injection system
4. Implement comprehensive testing for each migrated component

This approach allows maintaining a working app throughout the refactoring process.