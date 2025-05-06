import Foundation
import Combine

class ModelService {
    private let ollamaService: OllamaService
    private let openAIService: OpenAIService
    private let openRouterService: OpenRouterService
    
    init(
        ollamaService: OllamaService = OllamaService(),
        openAIService: OpenAIService = OpenAIService(),
        openRouterService: OpenRouterService = OpenRouterService()
    ) {
        self.ollamaService = ollamaService
        self.openAIService = openAIService
        self.openRouterService = openRouterService
    }
    
    /// Generates a response from the appropriate AI provider based on the conversation
    func generateResponse(conversation: Conversation, userMessage: Message) -> AnyPublisher<String, Error> {
        switch conversation.provider {
        case .ollama:
            return ollamaService.generateChatResponse(
                modelId: conversation.modelId,
                messages: conversation.messages
            )
        case .openAI:
            return openAIService.generateChatResponse(
                modelId: conversation.modelId,
                messages: conversation.messages
            )
        case .openRouter:
            return openRouterService.generateChatResponse(
                modelId: conversation.modelId,
                messages: conversation.messages
            )
        }
    }
    
    /// Generates a streaming response from the appropriate AI provider
    func generateStreamingResponse(conversation: Conversation, userMessage: Message) -> AnyPublisher<String, Error> {
        switch conversation.provider {
        case .ollama:
            return ollamaService.generateStreamingChatResponse(
                modelId: conversation.modelId,
                messages: conversation.messages
            )
        case .openAI:
            return openAIService.generateStreamingChatResponse(
                modelId: conversation.modelId,
                messages: conversation.messages
            )
        case .openRouter:
            return openRouterService.generateStreamingChatResponse(
                modelId: conversation.modelId,
                messages: conversation.messages
            )
        }
    }
    
    /// Fetches available models from a specific provider
    func fetchAvailableModels(provider: AIModel.ModelProvider) -> AnyPublisher<[AIModel], Error> {
        switch provider {
        case .ollama:
            return ollamaService.fetchAvailableModels()
        case .openAI:
            return openAIService.fetchAvailableModels()
        case .openRouter:
            return openRouterService.fetchAvailableModels()
        }
    }
    
    /// Fetches all available models from all configured providers
    func fetchAllAvailableModels() -> AnyPublisher<[AIModel], Error> {
        // Combine results from all providers
        let ollamaModels = ollamaService.fetchAvailableModels()
            .catch { error -> AnyPublisher<[AIModel], Error> in
                // If fetching fails, return empty array
                print("Failed to fetch Ollama models: \(error)")
                return Just([]).setFailureType(to: Error.self).eraseToAnyPublisher()
            }
        
        let openAIModels = openAIService.fetchAvailableModels()
            .catch { error -> AnyPublisher<[AIModel], Error> in
                print("Failed to fetch OpenAI models: \(error)")
                return Just([]).setFailureType(to: Error.self).eraseToAnyPublisher()
            }
        
        let openRouterModels = openRouterService.fetchAvailableModels()
            .catch { error -> AnyPublisher<[AIModel], Error> in
                print("Failed to fetch OpenRouter models: \(error)")
                return Just([]).setFailureType(to: Error.self).eraseToAnyPublisher()
            }
        
        // Merge all models together
        return Publishers.CombineLatest3(ollamaModels, openAIModels, openRouterModels)
            .map { ollama, openAI, openRouter in
                return ollama + openAI + openRouter
            }
            .eraseToAnyPublisher()
    }
}

/// Implement provider-specific services with placeholder implementations.
/// These will be expanded in future implementations.

class OllamaService {
    func generateChatResponse(modelId: String, messages: [Message]) -> AnyPublisher<String, Error> {
        // This is a placeholder implementation
        // Will be implemented with actual network calls in the future
        return Just("This is a placeholder response from Ollama model \(modelId).")
            .setFailureType(to: Error.self)
            .delay(for: .seconds(1), scheduler: DispatchQueue.global())
            .eraseToAnyPublisher()
    }
    
    func fetchAvailableModels() -> AnyPublisher<[AIModel], Error> {
        // Placeholder implementation
        return Just([
            AIModel(id: "llama2", name: "Llama 2", provider: .ollama),
            AIModel(id: "mistral", name: "Mistral", provider: .ollama),
            AIModel(id: "codellama", name: "Code Llama", provider: .ollama)
        ])
        .setFailureType(to: Error.self)
        .delay(for: .seconds(0.5), scheduler: DispatchQueue.global())
        .eraseToAnyPublisher()
    }
}

class OpenAIService {
    func generateChatResponse(modelId: String, messages: [Message]) -> AnyPublisher<String, Error> {
        // Placeholder implementation
        return Just("This is a placeholder response from OpenAI model \(modelId).")
            .setFailureType(to: Error.self)
            .delay(for: .seconds(1), scheduler: DispatchQueue.global())
            .eraseToAnyPublisher()
    }
    
    func fetchAvailableModels() -> AnyPublisher<[AIModel], Error> {
        // Placeholder implementation
        return Just([
            AIModel(id: "gpt-4", name: "GPT-4", provider: .openAI),
            AIModel(id: "gpt-3.5-turbo", name: "GPT-3.5 Turbo", provider: .openAI)
        ])
        .setFailureType(to: Error.self)
        .delay(for: .seconds(0.5), scheduler: DispatchQueue.global())
        .eraseToAnyPublisher()
    }
}

class OpenRouterService {
    func generateChatResponse(modelId: String, messages: [Message]) -> AnyPublisher<String, Error> {
        // Placeholder implementation
        return Just("This is a placeholder response from OpenRouter model \(modelId).")
            .setFailureType(to: Error.self)
            .delay(for: .seconds(1), scheduler: DispatchQueue.global())
            .eraseToAnyPublisher()
    }
    
    func fetchAvailableModels() -> AnyPublisher<[AIModel], Error> {
        // Placeholder implementation
        return Just([
            AIModel(id: "anthropic/claude-3-opus", name: "Claude 3 Opus", provider: .openRouter),
            AIModel(id: "google/gemini-pro", name: "Gemini Pro", provider: .openRouter),
            AIModel(id: "meta-llama/llama-3-70b", name: "Llama 3 70B", provider: .openRouter)
        ])
        .setFailureType(to: Error.self)
        .delay(for: .seconds(0.5), scheduler: DispatchQueue.global())
        .eraseToAnyPublisher()
    }
}