import Foundation
import SwiftUI
import OSLog

/// Chat feature implemented using TCA (The Composable Architecture) principles
@Reducer
struct ChatFeature {
    // MARK: - State
    
    @ObservableState
    struct State: Equatable {
        var messages: [Message] = []
        var conversation: Conversation?
        var isStreaming: Bool = false
        var inputText: String = ""
        var selectedModel: AIModel?
        var availableModels: [AIModel] = []
        var isModelSelectionPresented: Bool = false
        var isReconnecting: Bool = false
        var error: String?
        
        /// Convenience property to determine if we have a valid model selected
        var canSendMessage: Bool {
            return !inputText.isEmpty && selectedModel != nil && !isStreaming
        }
    }
    
    // MARK: - Actions
    
    enum Action: Equatable {
        // UI actions
        case messageInputChanged(String)
        case sendButtonTapped
        case modelSelectionButtonTapped
        case modelSelected(AIModel)
        case modelSelectionDismissed
        case retryButtonTapped
        case clearChatButtonTapped
        case cancelStreamingButtonTapped
        
        // Internal actions (Not directly triggered by UI)
        case modelsLoaded([AIModel])
        case messagesLoaded([Message])
        case streamingStarted
        case messageChunkReceived(String)
        case streamingEnded
        case errorOccurred(String)
        case reconnectSucceeded
        case reconnectFailed
    }
    
    // MARK: - Dependencies
    
    @Dependency(\.ollamaClient) private var ollamaClient
    @Dependency(\.storageClient) private var storageClient
    @Dependency(\.mainQueue) private var mainQueue
    
    private let logger = Logger(subsystem: "com.openwebui.ios", category: "ChatFeature")
    
    // MARK: - Cancellation IDs
    
    private enum CancelID {
        case messageStreaming
        case modelLoading
    }
    
    // MARK: - Reducer
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            // MARK: - UI Actions
                
            case let .messageInputChanged(text):
                state.inputText = text
                return .none
                
            case .sendButtonTapped:
                guard state.canSendMessage, let model = state.selectedModel else {
                    return .none
                }
                
                // Create and add the user message
                let userMessage = Message(role: .user, content: state.inputText)
                state.messages.append(userMessage)
                state.inputText = ""
                
                // Ensure we have a conversation
                let conversationId = state.conversation?.id ?? UUID()
                if state.conversation == nil {
                    state.conversation = Conversation(
                        id: conversationId,
                        title: userMessage.content.prefix(30).trimmingCharacters(in: .whitespacesAndNewlines),
                        lastMessageDate: Date(),
                        modelId: model.id,
                        provider: model.provider
                    )
                }
                
                // Start streaming the response
                return .concatenate(
                    .send(.streamingStarted),
                    .run { [messages = state.messages, selectedModel = model] send in
                        do {
                            // Create an initial assistant message
                            let assistantMessage = Message(
                                id: UUID(),
                                conversationId: conversationId,
                                role: .assistant,
                                content: "",
                                timestamp: Date()
                            )
                            
                            // Save the conversation and messages
                            try await storageClient.saveConversation(state.conversation!)
                            try await storageClient.saveMessages([userMessage, assistantMessage])
                            
                            // Start streaming the response
                            for try await chunk in ollamaClient.streamChat(
                                messages: messages,
                                model: selectedModel
                            ) {
                                await send(.messageChunkReceived(chunk))
                            }
                            
                            await send(.streamingEnded)
                        } catch {
                            logger.error("Failed to stream chat: \(error.localizedDescription)")
                            await send(.errorOccurred("Failed to get response: \(error.localizedDescription)"))
                            await send(.streamingEnded)
                        }
                    }
                    .cancellable(id: CancelID.messageStreaming)
                )
                
            case .modelSelectionButtonTapped:
                state.isModelSelectionPresented = true
                
                // Load models if we don't have any
                return state.availableModels.isEmpty ? .run { send in
                    do {
                        let models = try await ollamaClient.fetchModels()
                        await send(.modelsLoaded(models))
                    } catch {
                        logger.error("Failed to load models: \(error.localizedDescription)")
                        await send(.errorOccurred("Failed to load models: \(error.localizedDescription)"))
                    }
                }
                .cancellable(id: CancelID.modelLoading) : .none
                
            case let .modelSelected(model):
                state.selectedModel = model
                state.isModelSelectionPresented = false
                
                // Update conversation model if needed
                if var conversation = state.conversation {
                    conversation.modelId = model.id
                    conversation.provider = model.provider
                    state.conversation = conversation
                    
                    // Save the updated conversation
                    return .run { [conversation] _ in
                        try await storageClient.updateConversation(conversation)
                    }
                }
                
                return .none
                
            case .modelSelectionDismissed:
                state.isModelSelectionPresented = false
                return .none
                
            case .retryButtonTapped:
                state.error = nil
                state.isReconnecting = true
                
                return .run { send in
                    do {
                        // Try to reconnect by loading models
                        let models = try await ollamaClient.fetchModels()
                        await send(.modelsLoaded(models))
                        await send(.reconnectSucceeded)
                    } catch {
                        logger.error("Reconnection failed: \(error.localizedDescription)")
                        await send(.reconnectFailed)
                    }
                }
                
            case .clearChatButtonTapped:
                state.messages = []
                
                // Clear the conversation from storage
                if let conversation = state.conversation {
                    return .run { [conversation] _ in
                        try await storageClient.deleteConversation(conversation.id)
                    }
                }
                
                return .none
                
            case .cancelStreamingButtonTapped:
                return .cancel(id: CancelID.messageStreaming)
                
            // MARK: - Internal Actions
                
            case let .modelsLoaded(models):
                state.availableModels = models
                
                // If we don't have a selected model yet, select the first one
                if state.selectedModel == nil, let firstModel = models.first {
                    state.selectedModel = firstModel
                }
                
                return .none
                
            case let .messagesLoaded(messages):
                state.messages = messages
                return .none
                
            case .streamingStarted:
                state.isStreaming = true
                
                // Create an initial empty assistant message
                state.messages.append(Message(role: .assistant, content: ""))
                
                return .none
                
            case let .messageChunkReceived(chunk):
                // Update the last message with the new content
                if state.isStreaming, var lastMessage = state.messages.last, lastMessage.role == .assistant {
                    lastMessage.content += chunk
                    state.messages[state.messages.count - 1] = lastMessage
                    
                    // Save the updated message
                    return .run { [lastMessage] _ in
                        try await storageClient.updateMessage(lastMessage)
                    }
                }
                
                return .none
                
            case .streamingEnded:
                state.isStreaming = false
                
                // Update the conversation's last message date
                if var conversation = state.conversation {
                    conversation.lastMessageDate = Date()
                    state.conversation = conversation
                    
                    return .run { [conversation] _ in
                        try await storageClient.updateConversation(conversation)
                    }
                }
                
                return .none
                
            case let .errorOccurred(message):
                state.error = message
                state.isStreaming = false
                return .none
                
            case .reconnectSucceeded:
                state.isReconnecting = false
                state.error = nil
                return .none
                
            case .reconnectFailed:
                state.isReconnecting = false
                state.error = "Failed to reconnect to the server. Please check your connection and try again."
                return .none
            }
        }
    }
}

// MARK: - Chat Feature View

struct ChatView: View {
    @Bindable var store: StoreOf<ChatFeature>
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Message list
            MessageListView(messages: store.messages)
            
            // Input area
            HStack(spacing: 12) {
                Button(action: {
                    store.send(.modelSelectionButtonTapped)
                }) {
                    Label("Model", systemImage: "cube")
                        .labelStyle(.iconOnly)
                        .font(.system(size: 20))
                }
                
                TextField("Message", text: $store.inputText, axis: .vertical)
                    .padding(10)
                    .background(Color(.systemGray6))
                    .cornerRadius(18)
                    .focused($isInputFocused)
                    .onChange(of: store.inputText) { oldValue, newValue in
                        store.send(.messageInputChanged(newValue))
                    }
                
                if store.isStreaming {
                    Button(action: {
                        store.send(.cancelStreamingButtonTapped)
                    }) {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.red)
                    }
                } else {
                    Button(action: {
                        store.send(.sendButtonTapped)
                        isInputFocused = false
                    }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(store.canSendMessage ? .blue : .gray)
                    }
                    .disabled(!store.canSendMessage)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemBackground).opacity(0.8))
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundColor(Color(.systemGray4)),
                alignment: .top
            )
        }
        .overlay(
            Group {
                if let error = store.error {
                    ErrorView(message: error) {
                        store.send(.retryButtonTapped)
                    }
                }
            }
        )
        .sheet(isPresented: $store.isModelSelectionPresented) {
            ModelSelectionView(
                models: store.availableModels,
                selectedModel: store.selectedModel,
                onModelSelected: { model in
                    store.send(.modelSelected(model))
                },
                onDismiss: {
                    store.send(.modelSelectionDismissed)
                }
            )
        }
    }
}

// MARK: - Helper Views

/// Displays a list of messages
struct MessageListView: View {
    let messages: [Message]
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(messages) { message in
                        MessageBubbleView(message: message)
                            .id(message.id)
                    }
                }
                .padding()
            }
            .onChange(of: messages) { oldValue, newValue in
                if let lastMessage = newValue.last {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }
}

/// Displays a message bubble
struct MessageBubbleView: View {
    let message: Message
    
    var body: some View {
        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
            Text(message.role.rawValue.capitalized)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(message.content.isEmpty ? " " : message.content)
                .padding()
                .background(
                    message.role == .user 
                    ? Color.blue.opacity(0.8)
                    : Color(.systemGray5)
                )
                .foregroundColor(message.role == .user ? .white : .primary)
                .cornerRadius(12)
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(message.role.rawValue) said: \(message.content)")
    }
}

/// Displays an error message with a retry button
struct ErrorView: View {
    let message: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.yellow)
            
            Text(message)
                .font(.headline)
                .multilineTextAlignment(.center)
            
            Button("Retry", action: onRetry)
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color(.systemBackground).opacity(0.9))
        .cornerRadius(16)
        .shadow(radius: 10)
        .padding(32)
    }
}

/// Displays a list of available models
struct ModelSelectionView: View {
    let models: [AIModel]
    let selectedModel: AIModel?
    let onModelSelected: (AIModel) -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationView {
            List {
                ForEach(models) { model in
                    ModelRowView(
                        model: model,
                        isSelected: model.id == selectedModel?.id
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onModelSelected(model)
                    }
                }
            }
            .navigationTitle("Select Model")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onDismiss)
                }
            }
        }
    }
}

/// Displays a row for a model in the selection list
struct ModelRowView: View {
    let model: AIModel
    let isSelected: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.name)
                    .font(.headline)
                
                Text(model.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Dependencies

/// Protocol for Ollama API client operations
protocol OllamaClientProtocol {
    func streamChat(messages: [Message], model: AIModel) -> AsyncThrowingStream<String, Error>
    func fetchModels() async throws -> [AIModel]
}

/// Protocol for storing and retrieving conversations and messages
protocol StorageClientProtocol {
    func saveConversation(_ conversation: Conversation) async throws
    func updateConversation(_ conversation: Conversation) async throws
    func saveMessages(_ messages: [Message]) async throws
    func updateMessage(_ message: Message) async throws
    func loadConversation(id: UUID) async throws -> Conversation?
    func loadMessages(conversationId: UUID) async throws -> [Message]
    func deleteConversation(_ id: UUID) async throws
}