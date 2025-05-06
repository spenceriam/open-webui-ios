import Foundation

/// Represents a message in a chat conversation
struct Message: Identifiable, Codable {
    var id: UUID
    var content: String
    var role: Role
    var timestamp: Date
    var status: Status
    var metadata: [String: String]?
    var tags: [String]?
    
    init(
        id: UUID = UUID(),
        content: String,
        role: Role,
        timestamp: Date = Date(),
        status: Status = .delivered,
        metadata: [String: String]? = nil,
        tags: [String]? = nil
    ) {
        self.id = id
        self.content = content
        self.role = role
        self.timestamp = timestamp
        self.status = status
        self.metadata = metadata
        self.tags = tags
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
    
    // MARK: - Helper Properties
    
    var isCode: Bool {
        if content.hasPrefix("```") {
            return true
        }
        
        // Check if message is marked as code in metadata
        return metadata?["isCode"] == "true"
    }
    
    var language: String? {
        // Extract language from code blocks like ```python
        if content.hasPrefix("```") {
            let lines = content.split(separator: "\n")
            if let firstLine = lines.first {
                let lang = firstLine.dropFirst(3).trimmingCharacters(in: .whitespacesAndNewlines)
                if !lang.isEmpty {
                    return lang
                }
            }
        }
        
        // Check metadata
        return metadata?["language"]
    }
    
    var isEdited: Bool {
        return metadata?["edited"] == "true"
    }
    
    var hasAttachments: Bool {
        return metadata?["hasAttachments"] == "true"
    }
    
    var reactions: [String] {
        if let reactionsString = metadata?["reactions"] {
            return reactionsString.components(separatedBy: ",")
        }
        return []
    }
    
    // MARK: - Helper Methods
    
    mutating func addTag(_ tag: String) {
        if tags == nil {
            tags = []
        }
        if !tags!.contains(tag) {
            tags!.append(tag)
        }
    }
    
    mutating func removeTag(_ tag: String) {
        tags?.removeAll { $0 == tag }
    }
    
    mutating func addReaction(_ reaction: String) {
        var currentReactions = reactions
        if !currentReactions.contains(reaction) {
            currentReactions.append(reaction)
            if metadata == nil {
                metadata = [:]
            }
            metadata!["reactions"] = currentReactions.joined(separator: ",")
        }
    }
    
    mutating func removeReaction(_ reaction: String) {
        var currentReactions = reactions
        currentReactions.removeAll { $0 == reaction }
        if metadata == nil {
            metadata = [:]
        }
        metadata!["reactions"] = currentReactions.joined(separator: ",")
    }
    
    mutating func markAsEdited() {
        if metadata == nil {
            metadata = [:]
        }
        metadata!["edited"] = "true"
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
    var metadata: [String: String] = [:]
    
    init(
        id: UUID = UUID(),
        title: String,
        messages: [Message] = [],
        modelId: String,
        provider: Provider,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        folderIds: [UUID]? = nil,
        tags: [String]? = nil,
        metadata: [String: String] = [:]
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
        self.metadata = metadata
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
    
    // MARK: - Helper Properties
    
    var isPinned: Bool {
        get { return metadata["pinned"] == "true" }
        set { metadata["pinned"] = newValue ? "true" : "false" }
    }
    
    var folderId: UUID? {
        get {
            if let folderIdString = metadata["folderId"],
               let folderId = UUID(uuidString: folderIdString) {
                return folderId
            }
            return folderIds?.first
        }
        set {
            metadata["folderId"] = newValue?.uuidString
            
            // Also maintain compatibility with folderIds array
            if let newValue = newValue {
                if folderIds == nil {
                    folderIds = [newValue]
                } else if !folderIds!.contains(newValue) {
                    folderIds!.append(newValue)
                }
            } else {
                folderIds = nil
            }
        }
    }
    
    var isArchived: Bool {
        get { return metadata["archived"] == "true" }
        set { metadata["archived"] = newValue ? "true" : "false" }
    }
    
    var isFavorite: Bool {
        get { return metadata["favorite"] == "true" }
        set { metadata["favorite"] = newValue ? "true" : "false" }
    }
    
    var color: String? {
        get { return metadata["color"] }
        set { metadata["color"] = newValue }
    }
    
    // MARK: - Helper Methods
    
    mutating func addTag(_ tag: String) {
        if tags == nil {
            tags = []
        }
        if !tags!.contains(tag) {
            tags!.append(tag)
        }
    }
    
    mutating func removeTag(_ tag: String) {
        tags?.removeAll { $0 == tag }
    }
    
    mutating func addMessageAndUpdate(_ message: Message) {
        messages.append(message)
        updatedAt = Date()
    }
    
    mutating func clearMessages(keepSystemMessages: Bool = true) {
        if keepSystemMessages {
            messages = messages.filter { $0.role == .system }
        } else {
            messages = []
        }
        updatedAt = Date()
    }
    
    mutating func moveToFolder(_ folderId: UUID?) {
        self.folderId = folderId
        updatedAt = Date()
    }
}

/// Folder for organizing conversations
struct Folder: Identifiable, Codable {
    var id: UUID
    var name: String
    var conversationIds: [UUID]
    var createdAt: Date
    var updatedAt: Date
    var color: String?
    var icon: String?
    var metadata: [String: String]?
    
    init(
        id: UUID = UUID(),
        name: String,
        conversationIds: [UUID] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        color: String? = nil,
        icon: String? = nil,
        metadata: [String: String]? = nil
    ) {
        self.id = id
        self.name = name
        self.conversationIds = conversationIds
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.color = color
        self.icon = icon
        self.metadata = metadata
    }
    
    // MARK: - Helper Properties
    
    var isDefault: Bool {
        return metadata?["isDefault"] == "true"
    }
    
    var isArchived: Bool {
        get { return metadata?["archived"] == "true" }
        set { 
            if metadata == nil {
                metadata = [:]
            }
            metadata!["archived"] = newValue ? "true" : "false"
        }
    }
    
    var sortOrder: Int {
        get { 
            if let orderString = metadata?["sortOrder"], let order = Int(orderString) {
                return order
            }
            return 0
        }
        set {
            if metadata == nil {
                metadata = [:]
            }
            metadata!["sortOrder"] = String(newValue)
        }
    }
    
    // MARK: - Helper Methods
    
    mutating func addConversation(_ conversationId: UUID) {
        if !conversationIds.contains(conversationId) {
            conversationIds.append(conversationId)
            updatedAt = Date()
        }
    }
    
    mutating func removeConversation(_ conversationId: UUID) {
        conversationIds.removeAll { $0 == conversationId }
        updatedAt = Date()
    }
}