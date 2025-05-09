import Foundation
import Combine

// MARK: - Dependency Key Definition

/// Protocol for dependency keys that provide a live value
protocol DependencyKey {
    associatedtype Value
    static var liveValue: Value { get }
    static var previewValue: Value { get }
    static var testValue: Value { get }
}

/// Default implementation for preview and test values to inherit from live value
extension DependencyKey {
    static var previewValue: Value { liveValue }
    static var testValue: Value { liveValue }
}

// MARK: - Dependency Values

/// Registry for app-wide dependencies
struct DependencyValues {
    private var storage: [ObjectIdentifier: Any] = [:]
    
    /// Access or set a dependency by its key type
    subscript<Key: DependencyKey>(key: Key.Type) -> Key.Value {
        get {
            let id = ObjectIdentifier(key)
            guard let value = storage[id] as? Key.Value else {
                fatalError("Dependency \(key) not registered")
            }
            return value
        }
        set {
            let id = ObjectIdentifier(key)
            storage[id] = newValue
        }
    }
    
    /// Singleton instance of dependency values
    private static var current = DependencyValues()
    
    /// Access the current dependency values
    static var live: DependencyValues {
        get { current }
        set { current = newValue }
    }
    
    /// Preview dependencies for SwiftUI previews
    static var preview: DependencyValues {
        var values = DependencyValues()
        
        // Register all preview dependencies
        values[OllamaClient.self] = OllamaClient.previewValue
        values[StorageClient.self] = StorageClient.previewValue
        // Add other preview dependencies as needed
        
        return values
    }
    
    /// Test dependencies for unit tests
    static var test: DependencyValues {
        var values = DependencyValues()
        
        // Register all test dependencies
        values[OllamaClient.self] = OllamaClient.testValue
        values[StorageClient.self] = StorageClient.testValue
        // Add other test dependencies as needed
        
        return values
    }
}

// MARK: - Property Wrapper

/// Property wrapper for injecting dependencies
@propertyWrapper
struct Dependency<Value> {
    private let keyPath: KeyPath<DependencyValues, Value>
    
    var wrappedValue: Value {
        DependencyValues.live[keyPath: keyPath]
    }
    
    init(_ keyPath: KeyPath<DependencyValues, Value>) {
        self.keyPath = keyPath
    }
}

// MARK: - Define Dependency Keys and Extensions

// Ollama Client
struct OllamaClient: OllamaClientProtocol, DependencyKey {
    private let ollamaService: OllamaServiceActor
    
    init(ollamaService: OllamaServiceActor) {
        self.ollamaService = ollamaService
    }
    
    func streamChat(messages: [Message], model: AIModel) -> AsyncThrowingStream<String, Error> {
        return ollamaService.generateStreamingChatResponse(modelId: model.id, messages: messages)
    }
    
    func fetchModels() async throws -> [AIModel] {
        return try await ollamaService.fetchAvailableModels()
    }
    
    // MARK: - Dependency Key Conformance
    
    static var liveValue: OllamaClientProtocol {
        let discoveryService = DiscoveryServiceActor(powerMonitor: PowerMonitor.shared)
        let ollamaService = OllamaServiceActor(discoveryService: discoveryService)
        return OllamaClient(ollamaService: ollamaService)
    }
    
    static var previewValue: OllamaClientProtocol {
        PreviewOllamaClient()
    }
    
    static var testValue: OllamaClientProtocol {
        TestOllamaClient()
    }
}

// Storage Client
struct StorageClient: StorageClientProtocol, DependencyKey {
    private let storageService: StorageServiceProtocol
    
    init(storageService: StorageServiceProtocol) {
        self.storageService = storageService
    }
    
    func saveConversation(_ conversation: Conversation) async throws {
        try await storageService.saveConversation(conversation)
    }
    
    func updateConversation(_ conversation: Conversation) async throws {
        try await storageService.updateConversation(conversation)
    }
    
    func saveMessages(_ messages: [Message]) async throws {
        try await storageService.saveMessages(messages)
    }
    
    func updateMessage(_ message: Message) async throws {
        try await storageService.updateMessage(message)
    }
    
    func loadConversation(id: UUID) async throws -> Conversation? {
        return try await storageService.loadConversation(id: id)
    }
    
    func loadMessages(conversationId: UUID) async throws -> [Message] {
        return try await storageService.loadMessages(conversationId: conversationId)
    }
    
    func deleteConversation(_ id: UUID) async throws {
        try await storageService.deleteConversation(id)
    }
    
    // MARK: - Dependency Key Conformance
    
    static var liveValue: StorageClientProtocol {
        // Return the live implementation using the actual storage service
        let storageService = StorageServiceActor()
        return StorageClient(storageService: storageService)
    }
    
    static var previewValue: StorageClientProtocol {
        PreviewStorageClient()
    }
    
    static var testValue: StorageClientProtocol {
        TestStorageClient()
    }
}

// Main Queue
struct MainQueueKey: DependencyKey {
    static var liveValue: AnySchedulerOf<DispatchQueue> {
        DispatchQueue.main.eraseToAnyScheduler()
    }
}

// MARK: - Dependency Extensions

extension DependencyValues {
    var ollamaClient: OllamaClientProtocol {
        get { self[OllamaClient.self] }
        set { self[OllamaClient.self] = newValue }
    }
    
    var storageClient: StorageClientProtocol {
        get { self[StorageClient.self] }
        set { self[StorageClient.self] = newValue }
    }
    
    var mainQueue: AnySchedulerOf<DispatchQueue> {
        get { self[MainQueueKey.self] }
        set { self[MainQueueKey.self] = newValue }
    }
}

// MARK: - Scheduler Type

/// Type erasing scheduler for consistent scheduler types
struct AnySchedulerOf<SchedulerTimeType: Strideable> where SchedulerTimeType.Stride: SchedulerTimeIntervalConvertible {
    private let _schedule: (@escaping () -> Void) -> Void
    private let _scheduleAfter: (SchedulerTimeType, @escaping () -> Void) -> Void
    
    init<S: Scheduler>(_ scheduler: S) where S.SchedulerTimeType == SchedulerTimeType {
        _schedule = { scheduler.schedule($0) }
        _scheduleAfter = { time, work in
            scheduler.schedule(after: time, action: work)
        }
    }
    
    func schedule(_ action: @escaping () -> Void) {
        _schedule(action)
    }
    
    func schedule(after time: SchedulerTimeType, action: @escaping () -> Void) {
        _scheduleAfter(time, action)
    }
}

extension DispatchQueue {
    func eraseToAnyScheduler() -> AnySchedulerOf<DispatchQueue.SchedulerTimeType> {
        AnySchedulerOf(self)
    }
}

// MARK: - Protocol Extensions for Scheduler

protocol SchedulerTimeIntervalConvertible {
    static func seconds(_ s: Int) -> Self
    static func seconds(_ s: Double) -> Self
    static func milliseconds(_ ms: Int) -> Self
    static func microseconds(_ us: Int) -> Self
    static func nanoseconds(_ ns: Int) -> Self
}

extension DispatchTimeInterval: SchedulerTimeIntervalConvertible {
    static func seconds(_ s: Int) -> Self {
        .seconds(s)
    }
    
    static func seconds(_ s: Double) -> Self {
        .milliseconds(Int(s * 1000))
    }
    
    static func milliseconds(_ ms: Int) -> Self {
        .milliseconds(ms)
    }
    
    static func microseconds(_ us: Int) -> Self {
        .microseconds(us)
    }
    
    static func nanoseconds(_ ns: Int) -> Self {
        .nanoseconds(ns)
    }
}

// MARK: - Preview Implementations

/// Preview implementation of OllamaClient for SwiftUI previews
class PreviewOllamaClient: OllamaClientProtocol {
    func streamChat(messages: [Message], model: AIModel) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                // Simulate streaming with a delay
                let responseText = "This is a simulated response for preview purposes. I'm an AI assistant powered by \(model.name)."
                
                for character in responseText {
                    try await Task.sleep(nanoseconds: 20_000_000) // 20ms delay
                    continuation.yield(String(character))
                }
                
                continuation.finish()
            }
        }
    }
    
    func fetchModels() async throws -> [AIModel] {
        return [
            AIModel(id: "llama2", name: "Llama 2", provider: .ollama),
            AIModel(id: "mistral", name: "Mistral", provider: .ollama),
            AIModel(id: "codellama", name: "Code Llama", provider: .ollama)
        ]
    }
}

/// Preview implementation of StorageClient for SwiftUI previews
class PreviewStorageClient: StorageClientProtocol {
    private var conversations: [UUID: Conversation] = [:]
    private var messages: [UUID: [Message]] = [:]
    
    func saveConversation(_ conversation: Conversation) async throws {
        conversations[conversation.id] = conversation
    }
    
    func updateConversation(_ conversation: Conversation) async throws {
        conversations[conversation.id] = conversation
    }
    
    func saveMessages(_ messages: [Message]) async throws {
        for message in messages {
            if let conversationId = message.conversationId {
                if self.messages[conversationId] == nil {
                    self.messages[conversationId] = []
                }
                self.messages[conversationId]?.append(message)
            }
        }
    }
    
    func updateMessage(_ message: Message) async throws {
        if let conversationId = message.conversationId,
           let index = messages[conversationId]?.firstIndex(where: { $0.id == message.id }) {
            messages[conversationId]?[index] = message
        }
    }
    
    func loadConversation(id: UUID) async throws -> Conversation? {
        return conversations[id]
    }
    
    func loadMessages(conversationId: UUID) async throws -> [Message] {
        return messages[conversationId] ?? []
    }
    
    func deleteConversation(_ id: UUID) async throws {
        conversations.removeValue(forKey: id)
        messages.removeValue(forKey: id)
    }
}

// MARK: - Test Implementations

/// Test implementation of OllamaClient for unit tests
class TestOllamaClient: OllamaClientProtocol {
    var modelsToReturn: [AIModel] = [
        AIModel(id: "test-model", name: "Test Model", provider: .ollama)
    ]
    
    var errorToThrow: Error?
    var recordedMessages: [Message] = []
    var recordedModel: AIModel?
    
    func streamChat(messages: [Message], model: AIModel) -> AsyncThrowingStream<String, Error> {
        self.recordedMessages = messages
        self.recordedModel = model
        
        return AsyncThrowingStream { continuation in
            Task {
                if let error = errorToThrow {
                    continuation.finish(throwing: error)
                    return
                }
                
                let responseText = "Test response"
                
                for character in responseText {
                    continuation.yield(String(character))
                }
                
                continuation.finish()
            }
        }
    }
    
    func fetchModels() async throws -> [AIModel] {
        if let error = errorToThrow {
            throw error
        }
        return modelsToReturn
    }
}

/// Test implementation of StorageClient for unit tests
class TestStorageClient: StorageClientProtocol {
    var savedConversations: [Conversation] = []
    var savedMessages: [Message] = []
    var conversationsToReturn: [UUID: Conversation] = [:]
    var messagesToReturn: [UUID: [Message]] = [:]
    var errorToThrow: Error?
    
    func saveConversation(_ conversation: Conversation) async throws {
        if let error = errorToThrow {
            throw error
        }
        savedConversations.append(conversation)
        conversationsToReturn[conversation.id] = conversation
    }
    
    func updateConversation(_ conversation: Conversation) async throws {
        if let error = errorToThrow {
            throw error
        }
        if let index = savedConversations.firstIndex(where: { $0.id == conversation.id }) {
            savedConversations[index] = conversation
        } else {
            savedConversations.append(conversation)
        }
        conversationsToReturn[conversation.id] = conversation
    }
    
    func saveMessages(_ messages: [Message]) async throws {
        if let error = errorToThrow {
            throw error
        }
        savedMessages.append(contentsOf: messages)
        
        // Also organize by conversation ID
        for message in messages {
            if let conversationId = message.conversationId {
                if messagesToReturn[conversationId] == nil {
                    messagesToReturn[conversationId] = []
                }
                messagesToReturn[conversationId]?.append(message)
            }
        }
    }
    
    func updateMessage(_ message: Message) async throws {
        if let error = errorToThrow {
            throw error
        }
        
        if let index = savedMessages.firstIndex(where: { $0.id == message.id }) {
            savedMessages[index] = message
        } else {
            savedMessages.append(message)
        }
        
        if let conversationId = message.conversationId {
            if let index = messagesToReturn[conversationId]?.firstIndex(where: { $0.id == message.id }) {
                messagesToReturn[conversationId]?[index] = message
            } else if messagesToReturn[conversationId] != nil {
                messagesToReturn[conversationId]?.append(message)
            } else {
                messagesToReturn[conversationId] = [message]
            }
        }
    }
    
    func loadConversation(id: UUID) async throws -> Conversation? {
        if let error = errorToThrow {
            throw error
        }
        return conversationsToReturn[id]
    }
    
    func loadMessages(conversationId: UUID) async throws -> [Message] {
        if let error = errorToThrow {
            throw error
        }
        return messagesToReturn[conversationId] ?? []
    }
    
    func deleteConversation(_ id: UUID) async throws {
        if let error = errorToThrow {
            throw error
        }
        savedConversations.removeAll { $0.id == id }
        conversationsToReturn.removeValue(forKey: id)
        messagesToReturn.removeValue(forKey: id)
    }
}

// MARK: - Storage Service Protocol

/// Protocol for the Core Data storage service
protocol StorageServiceProtocol {
    func saveConversation(_ conversation: Conversation) async throws
    func updateConversation(_ conversation: Conversation) async throws
    func saveMessages(_ messages: [Message]) async throws
    func updateMessage(_ message: Message) async throws
    func loadConversation(id: UUID) async throws -> Conversation?
    func loadMessages(conversationId: UUID) async throws -> [Message]
    func deleteConversation(_ id: UUID) async throws
}

/// Actor for thread-safe Core Data operations
actor StorageServiceActor: StorageServiceProtocol {
    // Implement Core Data operations here
    // For brevity, implementation is omitted
    
    func saveConversation(_ conversation: Conversation) async throws {
        // Placeholder implementation
    }
    
    func updateConversation(_ conversation: Conversation) async throws {
        // Placeholder implementation
    }
    
    func saveMessages(_ messages: [Message]) async throws {
        // Placeholder implementation
    }
    
    func updateMessage(_ message: Message) async throws {
        // Placeholder implementation
    }
    
    func loadConversation(id: UUID) async throws -> Conversation? {
        // Placeholder implementation
        return nil
    }
    
    func loadMessages(conversationId: UUID) async throws -> [Message] {
        // Placeholder implementation
        return []
    }
    
    func deleteConversation(_ id: UUID) async throws {
        // Placeholder implementation
    }
}