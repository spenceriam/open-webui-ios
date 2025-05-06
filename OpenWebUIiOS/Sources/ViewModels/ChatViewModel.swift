import Foundation
import Combine

class ChatViewModel: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var currentConversation: Conversation?
    @Published var isLoading: Bool = false
    @Published var error: Error?
    @Published var isStreaming: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    private let modelService: ModelService
    private let storageService: StorageService
    
    init(modelService: ModelService = ModelService(), storageService: StorageService = StorageService()) {
        self.modelService = modelService
        self.storageService = storageService
        loadConversations()
    }
    
    func loadConversations() {
        isLoading = true
        
        storageService.fetchConversations()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.error = error
                }
            } receiveValue: { [weak self] conversations in
                self?.conversations = conversations
            }
            .store(in: &cancellables)
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
        
        // If streaming is enabled, use the streaming API
        if useStreaming {
            self.isStreaming = true
            streamMessage(currentConversation, userMessage)
        } else {
            // Use the regular, non-streaming API
            generateMessage(currentConversation, userMessage)
        }
    }
    
    private func streamMessage(_ conversation: Conversation, _ userMessage: Message) {
        var streamedContent = ""
        
        modelService.generateStreamingResponse(conversation: conversation, userMessage: userMessage)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self = self else { return }
                self.isStreaming = false
                
                if case .failure(let error) = completion {
                    self.error = error
                    
                    // Update message status to failed
                    if var conversation = self.currentConversation {
                        if let index = conversation.messages.lastIndex(where: { $0.role == .assistant && $0.status == .streaming }) {
                            conversation.messages[index].status = .failed
                            self.currentConversation = conversation
                        }
                    }
                } else {
                    // Completion was successful, update the message status to delivered
                    if var conversation = self.currentConversation {
                        if let index = conversation.messages.lastIndex(where: { $0.role == .assistant && $0.status == .streaming }) {
                            conversation.messages[index].status = .delivered
                            self.currentConversation = conversation
                            
                            // Save the updated conversation when streaming completes
                            self.storageService.saveConversation(conversation)
                                .sink { _ in } receiveValue: { _ in }
                                .store(in: &self.cancellables)
                        }
                    }
                }
            } receiveValue: { [weak self] chunk in
                guard let self = self else { return }
                
                // Append the new chunk to the accumulated content
                streamedContent += chunk
                
                // Update message with streamed content so far
                if var conversation = self.currentConversation {
                    if let index = conversation.messages.lastIndex(where: { $0.role == .assistant && $0.status == .streaming }) {
                        conversation.messages[index].content = streamedContent
                        self.currentConversation = conversation
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func generateMessage(_ conversation: Conversation, _ userMessage: Message) {
        modelService.generateResponse(conversation: conversation, userMessage: userMessage)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self = self else { return }
                
                if case .failure(let error) = completion {
                    self.error = error
                    
                    // Update message status to failed
                    if var conversation = self.currentConversation {
                        if let index = conversation.messages.lastIndex(where: { $0.role == .assistant && $0.status == .sending }) {
                            conversation.messages[index].status = .failed
                            self.currentConversation = conversation
                        }
                    }
                }
            } receiveValue: { [weak self] response in
                guard let self = self else { return }
                
                // Update message with response
                if var conversation = self.currentConversation {
                    if let index = conversation.messages.lastIndex(where: { $0.role == .assistant && ($0.status == .sending || $0.status == .streaming) }) {
                        conversation.messages[index].content = response
                        conversation.messages[index].status = .delivered
                        self.currentConversation = conversation
                        
                        // Save the updated conversation
                        self.storageService.saveConversation(conversation)
                            .sink { _ in } receiveValue: { _ in }
                            .store(in: &self.cancellables)
                    }
                }
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
}