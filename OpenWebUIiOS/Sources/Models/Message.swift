import Foundation

/// Represents a message in a chat conversation
struct Message: Identifiable, Codable {
    var id: UUID
    var content: String
    var role: Role
    var timestamp: Date
    var status: Status
    var metadata: [String: String]?
    
    init(
        id: UUID = UUID(),
        content: String,
        role: Role,
        timestamp: Date = Date(),
        status: Status = .delivered,
        metadata: [String: String]? = nil
    ) {
        self.id = id
        self.content = content
        self.role = role
        self.timestamp = timestamp
        self.status = status
        self.metadata = metadata
    }
    
    enum Role: String, Codable {
        case user
        case assistant
        case system
    }
    
    enum Status: String, Codable {
        case sending
        case delivered
        case failed
        case streaming
    }
}

/// Represents a conversation with an AI model
struct Conversation: Identifiable, Codable {
    var id: UUID
    var title: String
    var messages: [Message]
    var modelId: String
    var provider: Provider
    var createdAt: Date
    var updatedAt: Date
    var folderIds: [UUID]?
    var tags: [String]?
    
    init(
        id: UUID = UUID(),
        title: String,
        messages: [Message] = [],
        modelId: String,
        provider: Provider,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        folderIds: [UUID]? = nil,
        tags: [String]? = nil
    ) {
        self.id = id
        self.title = title
        self.messages = messages
        self.modelId = modelId
        self.provider = provider
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.folderIds = folderIds
        self.tags = tags
    }
    
    enum Provider: String, Codable, CaseIterable, Identifiable {
        case ollama
        case openAI = "openai"
        case openRouter = "openrouter"
        
        var id: String { self.rawValue }
        
        var displayName: String {
            switch self {
            case .ollama: return "Ollama"
            case .openAI: return "OpenAI"
            case .openRouter: return "OpenRouter"
            }
        }
    }
}

/// Folder for organizing conversations
struct Folder: Identifiable, Codable {
    var id: UUID
    var name: String
    var conversationIds: [UUID]
    var createdAt: Date
    var updatedAt: Date
    
    init(
        id: UUID = UUID(),
        name: String,
        conversationIds: [UUID] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.conversationIds = conversationIds
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}