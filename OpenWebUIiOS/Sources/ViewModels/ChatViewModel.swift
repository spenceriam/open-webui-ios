import Foundation
import Combine
import UIKit

class ChatViewModel: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var currentConversation: Conversation?
    @Published var isLoading: Bool = false
    @Published var error: Error?
    @Published var isStreaming: Bool = false
    @Published var hasMoreConversations: Bool = false
    @Published var loadingMoreMessages: Bool = false
    @Published var hasInterruptedMessages: Bool = false
    @Published var offerResumption: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    private let modelService: ModelService
    private let storageService: StorageService
    
    // Pagination state
    private var currentConversationPage = 0
    private let conversationPageSize = 15
    private var hasReachedEndOfConversations = false
    
    // Memory and power monitoring
    private let memoryMonitor = MemoryMonitor.shared
    private let powerMonitor = PowerMonitor.shared
    
    // Background task management
    private let backgroundTaskService = BackgroundTaskService.shared
    
    init(modelService: ModelService = ModelService(), storageService: StorageService = StorageService()) {
        self.modelService = modelService
        self.storageService = storageService
        
        // Register for memory pressure notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryPressure),
            name: NSNotification.Name("ReduceMemoryPressure"),
            object: nil
        )
        
        // Register for app lifecycle notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppEnteringBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppEnteringForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        
        // Check for interrupted messages
        checkForInterruptedMessages()
        
        loadConversations()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func loadConversations() {
        isLoading = true
        currentConversationPage = 0
        hasReachedEndOfConversations = false
        
        storageService.fetchPaginatedConversations(page: currentConversationPage, pageSize: conversationPageSize)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.error = error
                }
            } receiveValue: { [weak self] conversations in
                guard let self = self else { return }
                self.conversations = conversations
                // Check if there might be more conversations
                self.hasMoreConversations = conversations.count >= self.conversationPageSize
                
                // Log memory usage for debugging
                print("Memory usage after loading conversations: \(self.memoryMonitor.formattedMemoryUsage())")
            }
            .store(in: &cancellables)
    }
    
    func loadMoreConversations() {
        // Don't load more if we're already loading or reached the end
        if isLoading || hasReachedEndOfConversations {
            return
        }
        
        isLoading = true
        currentConversationPage += 1
        
        storageService.fetchPaginatedConversations(page: currentConversationPage, pageSize: conversationPageSize)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.error = error
                }
            } receiveValue: { [weak self] newConversations in
                guard let self = self else { return }
                
                if newConversations.isEmpty {
                    self.hasReachedEndOfConversations = true
                    self.hasMoreConversations = false
                } else {
                    // Append new conversations
                    self.conversations.append(contentsOf: newConversations)
                    // Update flag if we received fewer than requested
                    self.hasMoreConversations = newConversations.count >= self.conversationPageSize
                }
                
                // Log memory usage for debugging
                print("Memory usage after loading more conversations: \(self.memoryMonitor.formattedMemoryUsage())")
            }
            .store(in: &cancellables)
    }
    
    @objc private func handleMemoryPressure() {
        // Clear cached conversations except current one
        if let currentId = currentConversation?.id {
            let filteredConversations = conversations.filter { $0.id == currentId }
            if filteredConversations.count != conversations.count {
                print("Reducing memory pressure by clearing \(conversations.count - filteredConversations.count) cached conversations")
                conversations = filteredConversations
            }
        }
        
        // Reset pagination state
        currentConversationPage = 0
        hasReachedEndOfConversations = false
        hasMoreConversations = true
    }
    
    func createNewConversation(title: String, model: AIModel) -> Conversation {
        let conversation = Conversation(
            title: title,
            modelId: model.id,
            provider: Conversation.Provider(rawValue: model.provider.rawValue) ?? .openAI
        )
        
        storageService.saveConversation(conversation)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.error = error
                }
            } receiveValue: { [weak self] savedConversation in
                self?.conversations.append(savedConversation)
                self?.currentConversation = savedConversation
            }
            .store(in: &cancellables)
        
        return conversation
    }
    
    func sendMessage(_ content: String, useStreaming: Bool = true) {
        guard var currentConversation = currentConversation else { return }
        
        // Clear any offer for resumption
        offerResumption = false
        
        let userMessage = Message(
            content: content,
            role: .user
        )
        
        currentConversation.messages.append(userMessage)
        self.currentConversation = currentConversation
        
        let assistantMessage = Message(
            content: "",
            role: .assistant,
            status: useStreaming ? .streaming : .sending
        )
        
        currentConversation.messages.append(assistantMessage)
        self.currentConversation = currentConversation
        
        // Register message for potential background processing
        let pendingMessageId = assistantMessage.id.uuidString
        let conversationId = currentConversation.id.uuidString
        backgroundTaskService.addPendingMessage(pendingMessageId, conversationID: conversationId)
        
        // Check if we should use streaming based on power state
        let shouldStream = useStreaming && powerMonitor.shouldUsePowerIntensiveFeature("streaming")
        
        // If streaming is enabled and allowed by power state, use the streaming API
        if shouldStream {
            self.isStreaming = true
            streamMessage(currentConversation, userMessage, assistantMessage)
        } else {
            // Use the regular, non-streaming API for better battery efficiency
            generateMessage(currentConversation, userMessage, assistantMessage)
        }
    }
    
    private func streamMessage(_ conversation: Conversation, _ userMessage: Message, _ assistantMessage: Message = Message(content: "", role: .assistant, status: .streaming)) {
        var streamedContent = ""
        let messageId = assistantMessage.id.uuidString
        
        modelService.generateStreamingResponse(conversation: conversation, userMessage: userMessage)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self = self else { return }
                self.isStreaming = false
                
                if case .failure(let error) = completion {
                    self.error = error
                    
                    // Update message status to failed
                    if var conversation = self.currentConversation {
                        if let index = conversation.messages.lastIndex(where: { $0.id == assistantMessage.id }) {
                            conversation.messages[index].status = .failed
                            self.currentConversation = conversation
                        }
                    }
                } else {
                    // Completion was successful, update the message status to delivered
                    if var conversation = self.currentConversation {
                        if let index = conversation.messages.lastIndex(where: { $0.id == assistantMessage.id }) {
                            conversation.messages[index].status = .delivered
                            self.currentConversation = conversation
                            
                            // Save the updated conversation when streaming completes
                            self.storageService.saveConversation(conversation)
                                .sink { _ in } receiveValue: { _ in }
                                .store(in: &self.cancellables)
                                
                            // Clear from background tasks since it's complete
                            self.backgroundTaskService.clearPartialResponse(for: messageId)
                        }
                    }
                }
            } receiveValue: { [weak self] chunk in
                guard let self = self else { return }
                
                // Append the new chunk to the accumulated content
                streamedContent += chunk
                
                // Update message with streamed content so far
                if var conversation = self.currentConversation {
                    if let index = conversation.messages.lastIndex(where: { $0.id == assistantMessage.id }) {
                        conversation.messages[index].content = streamedContent
                        self.currentConversation = conversation
                        
                        // Save partial content in case we're sent to background
                        self.backgroundTaskService.savePartialResponse(
                            messageID: messageId, 
                            content: streamedContent
                        )
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func generateMessage(_ conversation: Conversation, _ userMessage: Message, _ assistantMessage: Message) {
        let messageId = assistantMessage.id.uuidString
        
        modelService.generateResponse(conversation: conversation, userMessage: userMessage)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self = self else { return }
                
                if case .failure(let error) = completion {
                    self.error = error
                    
                    // Update message status to failed
                    if var conversation = self.currentConversation {
                        if let index = conversation.messages.lastIndex(where: { $0.id == assistantMessage.id }) {
                            conversation.messages[index].status = .failed
                            self.currentConversation = conversation
                        }
                    }
                }
            } receiveValue: { [weak self] response in
                guard let self = self else { return }
                
                // Update message with response
                if var conversation = self.currentConversation {
                    if let index = conversation.messages.lastIndex(where: { $0.id == assistantMessage.id }) {
                        conversation.messages[index].content = response
                        conversation.messages[index].status = .delivered
                        self.currentConversation = conversation
                        
                        // Save the updated conversation
                        self.storageService.saveConversation(conversation)
                            .sink { _ in } receiveValue: { _ in }
                            .store(in: &self.cancellables)
                        
                        // Clear from background tasks since it's complete
                        self.backgroundTaskService.clearPartialResponse(for: messageId)
                    }
                }
                
                // Save partial response in case of interruption
                self.backgroundTaskService.savePartialResponse(
                    messageID: messageId, 
                    content: response
                )
            }
            .store(in: &cancellables)
    }
    
    func loadMoreMessagesForCurrentConversation() {
        guard let conversation = currentConversation,
              let hasMoreMessages = conversation.metadata["hasMoreMessages"],
              hasMoreMessages == "true",
              !loadingMoreMessages else {
            return
        }
        
        loadingMoreMessages = true
        let totalMessagesLoaded = conversation.messages.count
        let page = totalMessagesLoaded / 50 // Using 50 as page size
        
        storageService.fetchPaginatedMessages(conversationId: conversation.id, page: page)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.loadingMoreMessages = false
                if case .failure(let error) = completion {
                    self?.error = error
                }
            } receiveValue: { [weak self] newMessages in
                guard let self = self, var conversation = self.currentConversation else { return }
                
                // Only add messages that we don't already have
                let existingIds = Set(conversation.messages.map { $0.id })
                let filteredMessages = newMessages.filter { !existingIds.contains($0.id) }
                
                // Merge messages and sort by timestamp
                if !filteredMessages.isEmpty {
                    var allMessages = conversation.messages + filteredMessages
                    allMessages.sort { $0.timestamp < $1.timestamp }
                    conversation.messages = allMessages
                    
                    // Update metadata to reflect if we've loaded all messages
                    if let totalMessagesStr = conversation.metadata["totalMessages"],
                       let totalMessages = Int(totalMessagesStr),
                       conversation.messages.count >= totalMessages {
                        conversation.metadata["hasMoreMessages"] = "false"
                    }
                    
                    self.currentConversation = conversation
                }
                
                // Log memory usage for debugging
                print("Memory usage after loading more messages: \(self.memoryMonitor.formattedMemoryUsage())")
            }
            .store(in: &cancellables)
    }

    func deleteConversation(_ conversationId: UUID) {
        storageService.deleteConversation(conversationId)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.error = error
                }
            } receiveValue: { [weak self] success in
                if success {
                    self?.conversations.removeAll { $0.id == conversationId }
                    if self?.currentConversation?.id == conversationId {
                        self?.currentConversation = nil
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Lifecycle and Recovery
    
    @objc func handleAppEnteringBackground() {
        print("App entering background - preparing chat resources")
        
        // Release memory-intensive resources
        if memoryMonitor.isMemoryUsageHigh {
            handleMemoryPressure()
        }
        
        // If currently streaming, save the partial response
        if isStreaming, let conversation = currentConversation {
            if let assistantMessage = conversation.messages.last(where: { $0.role == .assistant && $0.status == .streaming }) {
                print("Saving state of streaming message before backgrounding")
                
                // Add to background task service for potential background processing
                backgroundTaskService.addPendingMessage(
                    assistantMessage.id.uuidString,
                    conversationID: conversation.id.uuidString
                )
            }
        }
    }
    
    @objc func handleAppEnteringForeground() {
        print("App entering foreground - checking for recoverable messages")
        
        // Check for interrupted messages that need recovery
        checkForInterruptedMessages()
    }
    
    private func checkForInterruptedMessages() {
        // Check if we have any partial responses that need recovery
        backgroundTaskService.recoverPartialResponses { [weak self] partialResponses in
            guard let self = self, !partialResponses.isEmpty else { return }
            
            print("Found \(partialResponses.count) interrupted messages to recover")
            
            // Mark that we have interrupted messages
            self.hasInterruptedMessages = true
            
            // If we're already showing a conversation, check if it has any recoverable messages
            if var conversation = self.currentConversation {
                var hasUpdatedMessage = false
                
                for (messageID, content) in partialResponses {
                    if let index = conversation.messages.firstIndex(where: { $0.id.uuidString == messageID }) {
                        // If message exists but has no content, or is marked as streaming
                        if conversation.messages[index].content.isEmpty || 
                           conversation.messages[index].status == .streaming {
                            
                            // Update with partial content and mark as partial
                            conversation.messages[index].content = content
                            conversation.messages[index].status = .partial
                            hasUpdatedMessage = true
                        }
                    }
                }
                
                if hasUpdatedMessage {
                    // Update the conversation with recovered message
                    self.currentConversation = conversation
                    
                    // Offer to resume
                    self.offerResumption = true
                }
            }
        }
    }
    
    /// Resume messages that were interrupted
    func resumeInterruptedMessages() {
        guard let conversation = currentConversation, offerResumption else { return }
        
        // Find messages marked as partial
        let partialMessages = conversation.messages.filter { $0.status == .partial }
        
        for partialMessage in partialMessages {
            // Find the user message that triggered this response
            if let userMessageIndex = conversation.messages.lastIndex(where: { 
                $0.role == .user && $0.timestamp < partialMessage.timestamp 
            }) {
                let userMessage = conversation.messages[userMessageIndex]
                
                // Resume the message generation
                if powerMonitor.shouldUsePowerIntensiveFeature("streaming") {
                    // Create a continuation message with the partial content
                    var continuationMessage = partialMessage
                    continuationMessage.status = .streaming
                    
                    // If there's an existing one with the same ID, update it
                    if var updatedConversation = currentConversation,
                       let index = updatedConversation.messages.firstIndex(where: { $0.id == partialMessage.id }) {
                        updatedConversation.messages[index] = continuationMessage
                        currentConversation = updatedConversation
                        
                        isStreaming = true
                        streamMessage(updatedConversation, userMessage, continuationMessage)
                    }
                } else {
                    // Use non-streaming API for battery efficiency
                    var sendingMessage = partialMessage
                    sendingMessage.status = .sending
                    
                    // Update the message
                    if var updatedConversation = currentConversation,
                       let index = updatedConversation.messages.firstIndex(where: { $0.id == partialMessage.id }) {
                        updatedConversation.messages[index] = sendingMessage
                        currentConversation = updatedConversation
                        
                        generateMessage(updatedConversation, userMessage, sendingMessage)
                    }
                }
                
                // Reset offer state
                offerResumption = false
                break // Resume one at a time
            }
        }
    }
    
    func prepareForBackground() {
        // Release memory-intensive resources
        if memoryMonitor.isMemoryUsageHigh {
            handleMemoryPressure()
        }
        
        // Save any streaming messages for potential recovery
        handleAppEnteringBackground()
    }
}