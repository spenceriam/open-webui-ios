import Foundation

/// Represents an AI model from any provider
struct AIModel: Identifiable, Codable {
    var id: String
    var name: String
    var provider: ModelProvider
    var capabilities: [Capability]
    var defaultParameters: ModelParameters
    var description: String?
    var tags: [String]?
    var metadata: [String: String]?
    
    init(
        id: String,
        name: String,
        provider: ModelProvider,
        capabilities: [Capability] = [.textGeneration],
        defaultParameters: ModelParameters = ModelParameters(),
        description: String? = nil,
        tags: [String]? = nil,
        metadata: [String: String]? = nil
    ) {
        self.id = id
        self.name = name
        self.provider = provider
        self.capabilities = capabilities
        self.defaultParameters = defaultParameters
        self.description = description
        self.tags = tags
        self.metadata = metadata
    }
    
    enum ModelProvider: String, Codable, CaseIterable {
        case ollama
        case openAI = "openai"
        case openRouter = "openrouter"
        
        var displayName: String {
            switch self {
            case .ollama: return "Ollama"
            case .openAI: return "OpenAI"
            case .openRouter: return "OpenRouter"
            }
        }
    }
    
    enum Capability: String, Codable, CaseIterable {
        case textGeneration = "text-generation"
        case chat = "chat"
        case imageGeneration = "image-generation"
        case embedding = "embedding"
        case voiceGeneration = "voice-generation"
        case functionCalling = "function-calling"
    }
}

/// Parameters for text generation
struct ModelParameters: Codable {
    var temperature: Double
    var topP: Double
    var topK: Int?
    var maxTokens: Int?
    var presencePenalty: Double?
    var frequencyPenalty: Double?
    var stop: [String]?
    
    init(
        temperature: Double = 0.7,
        topP: Double = 0.9,
        topK: Int? = nil,
        maxTokens: Int? = 2048,
        presencePenalty: Double? = nil,
        frequencyPenalty: Double? = nil,
        stop: [String]? = nil
    ) {
        self.temperature = temperature
        self.topP = topP
        self.topK = topK
        self.maxTokens = maxTokens
        self.presencePenalty = presencePenalty
        self.frequencyPenalty = frequencyPenalty
        self.stop = stop
    }
}