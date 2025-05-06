import XCTest
import CoreData
@testable import OpenWebUIiOS

final class StorageServiceTests: XCTestCase {
    
    // MARK: - Test Properties
    
    private var storageService: StorageService!
    private var secureStorageService: SecureStorageService!
    private var testContainer: NSPersistentContainer!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        
        // Create an in-memory Core Data stack for testing
        testContainer = createInMemoryPersistentContainer()
        
        // Initialize the storage service with the test container
        storageService = StorageService(container: testContainer)
        
        // Initialize secure storage service
        secureStorageService = SecureStorageService()
    }
    
    override func tearDown() {
        // Clean up the Core Data stack
        testContainer = nil
        storageService = nil
        secureStorageService = nil
        super.tearDown()
    }
    
    private func createInMemoryPersistentContainer() -> NSPersistentContainer {
        let container = NSPersistentContainer(name: "OpenWebUIiOS")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Failed to load in-memory persistent store: \(error), \(error.userInfo)")
            }
        }
        
        return container
    }
    
    // MARK: - Test Conversation CRUD Operations
    
    func testCreateAndFetchConversation() {
        // Given
        let title = "Test Conversation"
        let modelId = "gpt-4"
        
        // When: Create a conversation
        let conversation = storageService.createConversation(title: title, modelId: modelId)
        
        // Then: Verify the conversation was created with correct attributes
        XCTAssertNotNil(conversation)
        XCTAssertEqual(conversation.title, title)
        XCTAssertEqual(conversation.modelId, modelId)
        XCTAssertNotNil(conversation.id)
        XCTAssertNotNil(conversation.createdAt)
        
        // When: Fetch the conversation
        let fetchedConversation = storageService.getConversation(by: conversation.id!)
        
        // Then: Verify the fetched conversation matches the created one
        XCTAssertNotNil(fetchedConversation)
        XCTAssertEqual(fetchedConversation?.id, conversation.id)
        XCTAssertEqual(fetchedConversation?.title, title)
        XCTAssertEqual(fetchedConversation?.modelId, modelId)
    }
    
    func testUpdateConversation() {
        // Given
        let conversation = storageService.createConversation(title: "Original Title", modelId: "gpt-3.5-turbo")
        let newTitle = "Updated Title"
        
        // When
        conversation.title = newTitle
        storageService.saveContext()
        
        // Then
        let fetchedConversation = storageService.getConversation(by: conversation.id!)
        XCTAssertEqual(fetchedConversation?.title, newTitle)
    }
    
    func testDeleteConversation() {
        // Given
        let conversation = storageService.createConversation(title: "To Be Deleted", modelId: "gpt-4")
        let conversationId = conversation.id!
        
        // When
        storageService.deleteConversation(conversation)
        
        // Then
        let fetchedConversation = storageService.getConversation(by: conversationId)
        XCTAssertNil(fetchedConversation)
    }
    
    func testFetchAllConversations() {
        // Given
        storageService.createConversation(title: "Conversation 1", modelId: "gpt-3.5-turbo")
        storageService.createConversation(title: "Conversation 2", modelId: "gpt-4")
        storageService.createConversation(title: "Conversation 3", modelId: "llama2")
        
        // When
        let conversations = storageService.fetchAllConversations()
        
        // Then
        XCTAssertEqual(conversations.count, 3)
    }
    
    // MARK: - Test Message Operations
    
    func testAddMessageToConversation() {
        // Given
        let conversation = storageService.createConversation(title: "Test Conversation", modelId: "gpt-4")
        
        // When
        let userMessage = storageService.addMessage(
            to: conversation,
            content: "Hello, AI!",
            role: .user
        )
        
        let assistantMessage = storageService.addMessage(
            to: conversation,
            content: "Hello, human! How can I help you?",
            role: .assistant
        )
        
        // Then
        XCTAssertEqual(conversation.messages?.count, 2)
        XCTAssertNotNil(userMessage.id)
        XCTAssertEqual(userMessage.content, "Hello, AI!")
        XCTAssertEqual(userMessage.role, "user")
        
        XCTAssertNotNil(assistantMessage.id)
        XCTAssertEqual(assistantMessage.content, "Hello, human! How can I help you?")
        XCTAssertEqual(assistantMessage.role, "assistant")
    }
    
    func testFetchMessagesForConversation() {
        // Given
        let conversation = storageService.createConversation(title: "Message Test", modelId: "gpt-4")
        storageService.addMessage(to: conversation, content: "Message 1", role: .user)
        storageService.addMessage(to: conversation, content: "Response 1", role: .assistant)
        storageService.addMessage(to: conversation, content: "Message 2", role: .user)
        
        // When
        let messages = storageService.fetchMessages(for: conversation)
        
        // Then
        XCTAssertEqual(messages.count, 3)
        
        // Check if messages are sorted by createdAt (oldest first)
        if messages.count >= 3 {
            XCTAssertEqual(messages[0].content, "Message 1")
            XCTAssertEqual(messages[1].content, "Response 1")
            XCTAssertEqual(messages[2].content, "Message 2")
        }
    }
    
    // MARK: - Test Folders and Tags
    
    func testCreateAndFetchFolder() {
        // Given
        let folderName = "Test Folder"
        
        // When
        let folder = storageService.createFolder(name: folderName)
        
        // Then
        XCTAssertNotNil(folder)
        XCTAssertEqual(folder.name, folderName)
        
        // When: Fetch all folders
        let folders = storageService.fetchAllFolders()
        
        // Then
        XCTAssertEqual(folders.count, 1)
        XCTAssertEqual(folders.first?.name, folderName)
    }
    
    func testAddConversationToFolder() {
        // Given
        let folder = storageService.createFolder(name: "Work")
        let conversation = storageService.createConversation(title: "Meeting Notes", modelId: "gpt-4")
        
        // When
        storageService.addConversation(conversation, to: folder)
        
        // Then
        XCTAssertEqual(folder.conversations?.count, 1)
        
        // When: Fetch conversations in folder
        let conversationsInFolder = storageService.fetchConversations(in: folder)
        
        // Then
        XCTAssertEqual(conversationsInFolder.count, 1)
        XCTAssertEqual(conversationsInFolder.first?.title, "Meeting Notes")
    }
    
    // MARK: - Test Secure Storage
    
    func testEncryptAndDecryptString() {
        // Given
        let sensitiveData = "This is sensitive information that should be encrypted"
        
        // When
        var encryptedString: String?
        var decryptedString: String?
        
        do {
            encryptedString = try secureStorageService.encryptString(sensitiveData)
            decryptedString = try secureStorageService.decryptString(encryptedString!)
        } catch {
            XCTFail("Encryption/decryption failed with error: \(error)")
        }
        
        // Then
        XCTAssertNotNil(encryptedString)
        XCTAssertNotEqual(encryptedString, sensitiveData) // Ensure it's actually encrypted
        XCTAssertEqual(decryptedString, sensitiveData) // Ensure it decrypts correctly
    }
    
    func testEncryptAndDecryptData() {
        // Given
        let originalData = "Test data for encryption".data(using: .utf8)!
        
        // When
        var encryptedData: Data?
        var decryptedData: Data?
        
        do {
            encryptedData = try secureStorageService.encrypt(originalData)
            decryptedData = try secureStorageService.decrypt(encryptedData!)
        } catch {
            XCTFail("Encryption/decryption failed with error: \(error)")
        }
        
        // Then
        XCTAssertNotNil(encryptedData)
        XCTAssertNotEqual(encryptedData, originalData) // Should be different
        XCTAssertEqual(decryptedData, originalData) // Should match original after decryption
    }
}