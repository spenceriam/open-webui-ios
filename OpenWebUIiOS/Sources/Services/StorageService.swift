import Foundation
import Combine
import CoreData

class StorageService {
    // Core Data persistent container
    private lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "OpenWebUI")
        
        // Create Core Data model programmatically as we're not using Xcode's Core Data model editor
        let model = NSManagedObjectModel()
        
        // Define Message entity
        let messageEntity = NSEntityDescription()
        messageEntity.name = "MessageEntity"
        messageEntity.managedObjectClassName = NSStringFromClass(MessageEntity.self)
        
        let messageIdAttribute = NSAttributeDescription()
        messageIdAttribute.name = "id"
        messageIdAttribute.attributeType = .UUIDAttributeType
        messageIdAttribute.isOptional = false
        
        let messageContentAttribute = NSAttributeDescription()
        messageContentAttribute.name = "content"
        messageContentAttribute.attributeType = .stringAttributeType
        messageContentAttribute.isOptional = false
        
        let messageRoleAttribute = NSAttributeDescription()
        messageRoleAttribute.name = "role"
        messageRoleAttribute.attributeType = .stringAttributeType
        messageRoleAttribute.isOptional = false
        
        let messageTimestampAttribute = NSAttributeDescription()
        messageTimestampAttribute.name = "timestamp"
        messageTimestampAttribute.attributeType = .dateAttributeType
        messageTimestampAttribute.isOptional = false
        
        let messageStatusAttribute = NSAttributeDescription()
        messageStatusAttribute.name = "status"
        messageStatusAttribute.attributeType = .stringAttributeType
        messageStatusAttribute.isOptional = false
        
        let messageMetadataAttribute = NSAttributeDescription()
        messageMetadataAttribute.name = "metadata"
        messageMetadataAttribute.attributeType = .transformableAttributeType
        messageMetadataAttribute.isOptional = true
        
        messageEntity.properties = [
            messageIdAttribute,
            messageContentAttribute,
            messageRoleAttribute,
            messageTimestampAttribute,
            messageStatusAttribute,
            messageMetadataAttribute
        ]
        
        // Define Conversation entity
        let conversationEntity = NSEntityDescription()
        conversationEntity.name = "ConversationEntity"
        conversationEntity.managedObjectClassName = NSStringFromClass(ConversationEntity.self)
        
        let conversationIdAttribute = NSAttributeDescription()
        conversationIdAttribute.name = "id"
        conversationIdAttribute.attributeType = .UUIDAttributeType
        conversationIdAttribute.isOptional = false
        
        let conversationTitleAttribute = NSAttributeDescription()
        conversationTitleAttribute.name = "title"
        conversationTitleAttribute.attributeType = .stringAttributeType
        conversationTitleAttribute.isOptional = false
        
        let conversationModelIdAttribute = NSAttributeDescription()
        conversationModelIdAttribute.name = "modelId"
        conversationModelIdAttribute.attributeType = .stringAttributeType
        conversationModelIdAttribute.isOptional = false
        
        let conversationProviderAttribute = NSAttributeDescription()
        conversationProviderAttribute.name = "provider"
        conversationProviderAttribute.attributeType = .stringAttributeType
        conversationProviderAttribute.isOptional = false
        
        let conversationCreatedAtAttribute = NSAttributeDescription()
        conversationCreatedAtAttribute.name = "createdAt"
        conversationCreatedAtAttribute.attributeType = .dateAttributeType
        conversationCreatedAtAttribute.isOptional = false
        
        let conversationUpdatedAtAttribute = NSAttributeDescription()
        conversationUpdatedAtAttribute.name = "updatedAt"
        conversationUpdatedAtAttribute.attributeType = .dateAttributeType
        conversationUpdatedAtAttribute.isOptional = false
        
        let conversationTagsAttribute = NSAttributeDescription()
        conversationTagsAttribute.name = "tags"
        conversationTagsAttribute.attributeType = .transformableAttributeType
        conversationTagsAttribute.isOptional = true
        
        let conversationFolderIdsAttribute = NSAttributeDescription()
        conversationFolderIdsAttribute.name = "folderIds"
        conversationFolderIdsAttribute.attributeType = .transformableAttributeType
        conversationFolderIdsAttribute.isOptional = true
        
        // Relationship from Conversation to Messages
        let messagesRelationship = NSRelationshipDescription()
        messagesRelationship.name = "messages"
        messagesRelationship.destinationEntity = messageEntity
        messagesRelationship.minCount = 0
        messagesRelationship.maxCount = 0
        messagesRelationship.deleteRule = .cascadeDeleteRule
        
        let conversationRelationship = NSRelationshipDescription()
        conversationRelationship.name = "conversation"
        conversationRelationship.destinationEntity = conversationEntity
        conversationRelationship.minCount = 1
        conversationRelationship.maxCount = 1
        conversationRelationship.deleteRule = .nullifyDeleteRule
        
        messagesRelationship.inverseRelationship = conversationRelationship
        conversationRelationship.inverseRelationship = messagesRelationship
        
        conversationEntity.properties = [
            conversationIdAttribute,
            conversationTitleAttribute,
            conversationModelIdAttribute,
            conversationProviderAttribute,
            conversationCreatedAtAttribute,
            conversationUpdatedAtAttribute,
            conversationTagsAttribute,
            conversationFolderIdsAttribute,
            messagesRelationship
        ]
        
        messageEntity.properties.append(conversationRelationship)
        
        // Define Folder entity
        let folderEntity = NSEntityDescription()
        folderEntity.name = "FolderEntity"
        folderEntity.managedObjectClassName = NSStringFromClass(FolderEntity.self)
        
        let folderIdAttribute = NSAttributeDescription()
        folderIdAttribute.name = "id"
        folderIdAttribute.attributeType = .UUIDAttributeType
        folderIdAttribute.isOptional = false
        
        let folderNameAttribute = NSAttributeDescription()
        folderNameAttribute.name = "name"
        folderNameAttribute.attributeType = .stringAttributeType
        folderNameAttribute.isOptional = false
        
        let folderCreatedAtAttribute = NSAttributeDescription()
        folderCreatedAtAttribute.name = "createdAt"
        folderCreatedAtAttribute.attributeType = .dateAttributeType
        folderCreatedAtAttribute.isOptional = false
        
        let folderUpdatedAtAttribute = NSAttributeDescription()
        folderUpdatedAtAttribute.name = "updatedAt"
        folderUpdatedAtAttribute.attributeType = .dateAttributeType
        folderUpdatedAtAttribute.isOptional = false
        
        let folderConversationIdsAttribute = NSAttributeDescription()
        folderConversationIdsAttribute.name = "conversationIds"
        folderConversationIdsAttribute.attributeType = .transformableAttributeType
        folderConversationIdsAttribute.isOptional = true
        
        folderEntity.properties = [
            folderIdAttribute,
            folderNameAttribute,
            folderCreatedAtAttribute,
            folderUpdatedAtAttribute,
            folderConversationIdsAttribute
        ]
        
        // Add entities to model
        model.entities = [messageEntity, conversationEntity, folderEntity]
        
        container.managedObjectModel = model
        
        container.loadPersistentStores { description, error in
            if let error = error {
                print("Failed to load Core Data stack: \(error)")
            }
        }
        
        return container
    }()
    
    // MARK: - Conversation Operations
    
    /// Fetches all conversations
    func fetchConversations() -> AnyPublisher<[Conversation], Error> {
        return fetchPaginatedConversations(page: 0, pageSize: 100)
    }
    
    /// Fetches conversations with pagination to reduce memory usage
    func fetchPaginatedConversations(page: Int, pageSize: Int = 20) -> AnyPublisher<[Conversation], Error> {
        Future<[Conversation], Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(StorageError.serviceUnavailable))
                return
            }
            
            let context = self.persistentContainer.viewContext
            let fetchRequest = NSFetchRequest<ConversationEntity>(entityName: "ConversationEntity")
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]
            fetchRequest.fetchLimit = pageSize
            fetchRequest.fetchOffset = page * pageSize
            
            // Monitor memory usage during this operation
            let memoryBefore = MemoryMonitor.shared.currentMemoryUsageMB
            
            do {
                let entities = try context.fetch(fetchRequest)
                let conversations = entities.map { self.mapToConversation($0) }
                
                // Log memory impact for debugging
                let memoryAfter = MemoryMonitor.shared.currentMemoryUsageMB
                let memoryImpact = memoryAfter - memoryBefore
                print("Memory impact of loading \(entities.count) conversations: \(String(format: "%.2f", memoryImpact)) MB")
                
                promise(.success(conversations))
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// Fetches a specific conversation
    func fetchConversation(_ id: UUID) -> AnyPublisher<Conversation?, Error> {
        return fetchConversation(id, messageLimit: 50)
    }
    
    /// Fetches a specific conversation with limited message loading
    func fetchConversation(_ id: UUID, messageLimit: Int? = nil) -> AnyPublisher<Conversation?, Error> {
        Future<Conversation?, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(StorageError.serviceUnavailable))
                return
            }
            
            let context = self.persistentContainer.viewContext
            let fetchRequest = NSFetchRequest<ConversationEntity>(entityName: "ConversationEntity")
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            
            do {
                let entities = try context.fetch(fetchRequest)
                if let entity = entities.first {
                    if let messageLimit = messageLimit {
                        // Limited message fetch for memory efficiency
                        let conversation = self.mapToConversationWithLimitedMessages(entity, messageLimit: messageLimit)
                        promise(.success(conversation))
                    } else {
                        // Full message load
                        let conversation = self.mapToConversation(entity)
                        promise(.success(conversation))
                    }
                } else {
                    promise(.success(nil))
                }
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// Fetches paginated messages for a specific conversation
    func fetchPaginatedMessages(conversationId: UUID, page: Int, pageSize: Int = 50) -> AnyPublisher<[Message], Error> {
        Future<[Message], Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(StorageError.serviceUnavailable))
                return
            }
            
            let context = self.persistentContainer.viewContext
            
            // First fetch the conversation entity
            let convFetch = NSFetchRequest<ConversationEntity>(entityName: "ConversationEntity")
            convFetch.predicate = NSPredicate(format: "id == %@", conversationId as CVarArg)
            
            do {
                guard let conversation = try context.fetch(convFetch).first else {
                    promise(.failure(StorageError.entityNotFound))
                    return
                }
                
                // Then fetch only the messages we need with pagination
                let messageFetch = NSFetchRequest<MessageEntity>(entityName: "MessageEntity")
                messageFetch.predicate = NSPredicate(format: "conversation == %@", conversation)
                messageFetch.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
                messageFetch.fetchLimit = pageSize
                messageFetch.fetchOffset = page * pageSize
                
                // Monitor memory usage during this operation
                let memoryBefore = MemoryMonitor.shared.currentMemoryUsageMB
                
                let messageEntities = try context.fetch(messageFetch)
                let messages = messageEntities.map { self.mapToMessage($0) }
                
                // Log memory impact for debugging
                let memoryAfter = MemoryMonitor.shared.currentMemoryUsageMB
                let memoryImpact = memoryAfter - memoryBefore
                print("Memory impact of loading \(messageEntities.count) messages: \(String(format: "%.2f", memoryImpact)) MB")
                
                promise(.success(messages))
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// Saves or updates a conversation
    func saveConversation(_ conversation: Conversation) -> AnyPublisher<Conversation, Error> {
        Future<Conversation, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(StorageError.serviceUnavailable))
                return
            }
            
            let context = self.persistentContainer.viewContext
            
            // Check if conversation already exists
            let fetchRequest = NSFetchRequest<ConversationEntity>(entityName: "ConversationEntity")
            fetchRequest.predicate = NSPredicate(format: "id == %@", conversation.id as CVarArg)
            
            do {
                let entities = try context.fetch(fetchRequest)
                let entity: ConversationEntity
                
                if let existingEntity = entities.first {
                    // Update existing entity
                    entity = existingEntity
                } else {
                    // Create new entity
                    entity = ConversationEntity(context: context)
                    entity.id = conversation.id
                    entity.createdAt = conversation.createdAt
                }
                
                // Update entity properties
                entity.title = conversation.title
                entity.modelId = conversation.modelId
                entity.provider = conversation.provider.rawValue
                entity.updatedAt = Date()
                entity.tags = conversation.tags as NSArray?
                entity.folderIds = conversation.folderIds as NSArray?
                
                // Update messages
                let existingMessages = entity.messages?.allObjects as? [MessageEntity] ?? []
                let existingMessageIds = existingMessages.map { $0.id }
                
                // Remove deleted messages
                for messageEntity in existingMessages {
                    if !conversation.messages.contains(where: { $0.id == messageEntity.id }) {
                        context.delete(messageEntity)
                    }
                }
                
                // Add new messages
                for message in conversation.messages {
                    if !existingMessageIds.contains(message.id) {
                        let messageEntity = MessageEntity(context: context)
                        messageEntity.id = message.id
                        messageEntity.content = message.content
                        messageEntity.role = message.role.rawValue
                        messageEntity.timestamp = message.timestamp
                        messageEntity.status = message.status.rawValue
                        messageEntity.metadata = message.metadata as NSDictionary?
                        messageEntity.conversation = entity
                    }
                }
                
                try context.save()
                
                // Fetch the updated conversation to ensure all relationships are properly loaded
                let updatedFetchRequest = NSFetchRequest<ConversationEntity>(entityName: "ConversationEntity")
                updatedFetchRequest.predicate = NSPredicate(format: "id == %@", conversation.id as CVarArg)
                if let updatedEntity = try context.fetch(updatedFetchRequest).first {
                    let updatedConversation = self.mapToConversation(updatedEntity)
                    promise(.success(updatedConversation))
                } else {
                    promise(.failure(StorageError.entityNotFound))
                }
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// Deletes a conversation
    func deleteConversation(_ id: UUID) -> AnyPublisher<Bool, Error> {
        Future<Bool, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(StorageError.serviceUnavailable))
                return
            }
            
            let context = self.persistentContainer.viewContext
            let fetchRequest = NSFetchRequest<ConversationEntity>(entityName: "ConversationEntity")
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            
            do {
                let entities = try context.fetch(fetchRequest)
                if let entity = entities.first {
                    context.delete(entity)
                    try context.save()
                    promise(.success(true))
                } else {
                    promise(.success(false))
                }
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Folder Operations
    
    /// Fetches all folders
    func fetchFolders() -> AnyPublisher<[Folder], Error> {
        Future<[Folder], Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(StorageError.serviceUnavailable))
                return
            }
            
            let context = self.persistentContainer.viewContext
            let fetchRequest = NSFetchRequest<FolderEntity>(entityName: "FolderEntity")
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
            
            do {
                let entities = try context.fetch(fetchRequest)
                let folders = entities.map { self.mapToFolder($0) }
                promise(.success(folders))
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// Saves or updates a folder
    func saveFolder(_ folder: Folder) -> AnyPublisher<Folder, Error> {
        Future<Folder, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(StorageError.serviceUnavailable))
                return
            }
            
            let context = self.persistentContainer.viewContext
            
            // Check if folder already exists
            let fetchRequest = NSFetchRequest<FolderEntity>(entityName: "FolderEntity")
            fetchRequest.predicate = NSPredicate(format: "id == %@", folder.id as CVarArg)
            
            do {
                let entities = try context.fetch(fetchRequest)
                let entity: FolderEntity
                
                if let existingEntity = entities.first {
                    // Update existing entity
                    entity = existingEntity
                } else {
                    // Create new entity
                    entity = FolderEntity(context: context)
                    entity.id = folder.id
                    entity.createdAt = folder.createdAt
                }
                
                // Update entity properties
                entity.name = folder.name
                entity.updatedAt = Date()
                entity.conversationIds = folder.conversationIds as NSArray?
                
                try context.save()
                
                let updatedFolder = self.mapToFolder(entity)
                promise(.success(updatedFolder))
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// Deletes a folder
    func deleteFolder(_ id: UUID) -> AnyPublisher<Bool, Error> {
        Future<Bool, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(StorageError.serviceUnavailable))
                return
            }
            
            let context = self.persistentContainer.viewContext
            let fetchRequest = NSFetchRequest<FolderEntity>(entityName: "FolderEntity")
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            
            do {
                let entities = try context.fetch(fetchRequest)
                if let entity = entities.first {
                    context.delete(entity)
                    try context.save()
                    promise(.success(true))
                } else {
                    promise(.success(false))
                }
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Mapping Methods
    
    private func mapToConversation(_ entity: ConversationEntity) -> Conversation {
        let messages = (entity.messages?.allObjects as? [MessageEntity] ?? [])
            .sorted { $0.timestamp < $1.timestamp }
            .map { self.mapToMessage($0) }
        
        return Conversation(
            id: entity.id,
            title: entity.title,
            messages: messages,
            modelId: entity.modelId,
            provider: Conversation.Provider(rawValue: entity.provider) ?? .openAI,
            createdAt: entity.createdAt,
            updatedAt: entity.updatedAt,
            folderIds: entity.folderIds as? [UUID],
            tags: entity.tags as? [String]
        )
    }
    
    private func mapToConversationWithLimitedMessages(_ entity: ConversationEntity, messageLimit: Int) -> Conversation {
        // Get all message entities and sort by timestamp
        let allMessages = (entity.messages?.allObjects as? [MessageEntity] ?? [])
            .sorted { $0.timestamp < $1.timestamp }
        
        // Only take the most recent messages up to the limit
        // For very large conversations, this dramatically reduces memory usage
        let limitedMessages: [MessageEntity]
        if allMessages.count > messageLimit {
            // Always include the first message for context
            let firstMessage = [allMessages.first].compactMap { $0 }
            
            // Then get the most recent messages up to (limit - 1)
            let recentMessages = Array(allMessages.suffix(messageLimit - 1))
            
            // Combine and sort
            limitedMessages = (firstMessage + recentMessages).sorted { $0.timestamp < $1.timestamp }
            
            print("Limiting conversation from \(allMessages.count) to \(limitedMessages.count) messages to reduce memory usage")
        } else {
            limitedMessages = allMessages
        }
        
        // Map to domain model
        let messages = limitedMessages.map { self.mapToMessage($0) }
        
        return Conversation(
            id: entity.id,
            title: entity.title,
            messages: messages,
            modelId: entity.modelId,
            provider: Conversation.Provider(rawValue: entity.provider) ?? .openAI,
            createdAt: entity.createdAt,
            updatedAt: entity.updatedAt,
            folderIds: entity.folderIds as? [UUID],
            tags: entity.tags as? [String],
            // Add a flag to indicate this conversation has limited messages loaded
            metadata: allMessages.count > messageLimit ? ["hasMoreMessages": "true", "totalMessages": "\(allMessages.count)"] : nil
        )
    }
    
    private func mapToMessage(_ entity: MessageEntity) -> Message {
        return Message(
            id: entity.id,
            content: entity.content,
            role: Message.Role(rawValue: entity.role) ?? .user,
            timestamp: entity.timestamp,
            status: Message.Status(rawValue: entity.status) ?? .delivered,
            metadata: entity.metadata as? [String: String]
        )
    }
    
    private func mapToFolder(_ entity: FolderEntity) -> Folder {
        return Folder(
            id: entity.id,
            name: entity.name,
            conversationIds: entity.conversationIds as? [UUID] ?? [],
            createdAt: entity.createdAt,
            updatedAt: entity.updatedAt
        )
    }
    
    // MARK: - Error Types
    
    enum StorageError: Error {
        case serviceUnavailable
        case entityNotFound
        case invalidData
    }
}

// MARK: - Core Data Entity Classes

class ConversationEntity: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var title: String
    @NSManaged var modelId: String
    @NSManaged var provider: String
    @NSManaged var createdAt: Date
    @NSManaged var updatedAt: Date
    @NSManaged var tags: NSArray?
    @NSManaged var folderIds: NSArray?
    @NSManaged var messages: NSSet?
}

class MessageEntity: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var content: String
    @NSManaged var role: String
    @NSManaged var timestamp: Date
    @NSManaged var status: String
    @NSManaged var metadata: NSDictionary?
    @NSManaged var conversation: ConversationEntity
}

class FolderEntity: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var name: String
    @NSManaged var createdAt: Date
    @NSManaged var updatedAt: Date
    @NSManaged var conversationIds: NSArray?
}