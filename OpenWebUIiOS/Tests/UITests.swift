import XCTest

final class OpenWebUIiOSUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUp() {
        super.setUp()
        
        // In UI tests we need to continuously launch the application
        app = XCUIApplication()
        
        // Set a flag to skip onboarding for most tests
        app.launchArguments = ["-uitesting"]
        
        // We can also set launch environment to configure the app state
        app.launchEnvironment = ["UI_TEST_MODE": "true"]
        
        continueAfterFailure = false
    }
    
    // MARK: - Onboarding Flow Tests
    
    func testOnboardingFlow() {
        // Remove the uitesting flag to show onboarding
        app.launchArguments = []
        app.launch()
        
        // Check first onboarding screen (Provider Selection)
        XCTAssert(app.staticTexts["Welcome to Open WebUI"].exists)
        XCTAssert(app.staticTexts["Choose a provider to get started"].exists)
        
        // Select Ollama provider
        app.buttons["Ollama"].tap()
        
        // Tap Next
        app.buttons["Next"].tap()
        
        // Check second onboarding screen (Configuration)
        XCTAssert(app.staticTexts["Configure Ollama"].exists)
        XCTAssert(app.textFields["Server URL"].exists)
        
        // Enter server URL
        let serverUrlField = app.textFields["Server URL"]
        serverUrlField.tap()
        serverUrlField.typeText("http://localhost:11434")
        
        // Tap Next
        app.buttons["Next"].tap()
        
        // Check third onboarding screen (Permissions)
        XCTAssert(app.staticTexts["Review Permissions"].exists)
        XCTAssert(app.staticTexts["Network Access"].exists)
        XCTAssert(app.staticTexts["Local Network"].exists)
        
        // Tap Finish
        app.buttons["Finish"].tap()
        
        // Verify we're in the main app
        XCTAssert(app.navigationBars["Open WebUI"].exists)
    }
    
    // MARK: - Navigation Tests
    
    func testMainNavigation() {
        app.launch()
        
        // Verify main navigation elements
        XCTAssert(app.navigationBars["Open WebUI"].exists)
        
        // Test sidebar sections
        let conversationsButton = app.buttons["Conversations"]
        XCTAssert(conversationsButton.exists)
        conversationsButton.tap()
        
        let providersButton = app.buttons["Providers"]
        XCTAssert(providersButton.exists)
        providersButton.tap()
        
        let settingsButton = app.buttons["Settings"]
        XCTAssert(settingsButton.exists)
        settingsButton.tap()
        
        // Navigation to Settings view
        app.buttons["All Settings"].tap()
        XCTAssert(app.navigationBars["Settings"].exists)
        
        // Navigate back
        app.navigationBars["Settings"].buttons.element(boundBy: 0).tap()
    }
    
    // MARK: - Chat Flow Tests
    
    func testBasicChatFlow() {
        app.launch()
        
        // Tap on the text input
        let chatInputField = app.textFields["Type a message..."]
        XCTAssert(chatInputField.exists)
        chatInputField.tap()
        
        // Type a message
        chatInputField.typeText("Hello, AI assistant!")
        
        // Tap send button
        app.buttons["Send"].tap()
        
        // Wait for response to appear
        let predicate = NSPredicate(format: "exists == true")
        let assistantMessage = app.staticTexts.matching(predicate).element(boundBy: 1)
        
        // Note: In a real test, you'd need to handle the async nature of the AI response
        // This is simplified for the example
        expectation(for: predicate, evaluatedWith: assistantMessage, handler: nil)
        waitForExpectations(timeout: 5, handler: nil)
        
        // Verify message bubbles exist
        XCTAssert(app.staticTexts["Hello, AI assistant!"].exists)
    }
    
    // MARK: - API Key Management Tests
    
    func testAPIKeyManagement() {
        app.launch()
        
        // Navigate to API Key Management
        app.buttons["Settings"].tap()
        app.buttons["Manage API Keys"].tap()
        
        // Verify we're on the API Key screen
        XCTAssert(app.navigationBars["API Keys"].exists)
        
        // Test adding an OpenAI API key
        let addKeyButton = app.buttons["Add Key"].firstMatch
        XCTAssert(addKeyButton.exists)
        addKeyButton.tap()
        
        // Enter API key
        let secureTextField = app.secureTextFields.firstMatch
        XCTAssert(secureTextField.exists)
        secureTextField.tap()
        secureTextField.typeText("test_openai_key_12345")
        
        // Save the key
        app.buttons["Save"].tap()
        
        // Verify key is saved
        XCTAssert(app.staticTexts["API key saved successfully"].exists)
        
        // Navigate back
        app.buttons["Done"].tap()
    }
    
    // MARK: - Provider Selection Tests
    
    func testProviderSelection() {
        app.launch()
        
        // Navigate to Providers section
        app.buttons["Providers"].tap()
        
        // Verify provider options exist
        XCTAssert(app.buttons["Ollama"].exists)
        XCTAssert(app.buttons["OpenAI"].exists)
        XCTAssert(app.buttons["OpenRouter"].exists)
        
        // Select OpenAI provider
        app.buttons["OpenAI"].tap()
        
        // Verify provider detail screen
        XCTAssert(app.staticTexts["Configure OpenAI"].exists)
        
        // Navigate back
        app.navigationBars.buttons.element(boundBy: 0).tap()
    }
    
    // MARK: - Conversation Management Tests
    
    func testConversationManagement() {
        app.launch()
        
        // Navigate to Conversation Management
        app.buttons["Conversations"].tap()
        app.buttons["Manage All Conversations"].tap()
        
        // Verify we're on the conversation list screen
        XCTAssert(app.navigationBars["Conversations"].exists)
        
        // Create a new conversation (assuming there's a + button)
        app.buttons["New Conversation"].tap()
        
        // Enter a conversation message
        let chatInputField = app.textFields["Type a message..."]
        chatInputField.tap()
        chatInputField.typeText("This is a test conversation")
        app.buttons["Send"].tap()
        
        // Go back to conversation list
        app.navigationBars.buttons.element(boundBy: 0).tap()
        
        // Verify new conversation exists
        XCTAssert(app.staticTexts["New Conversation"].exists)
        
        // Test conversation options (long press)
        let conversationCell = app.cells.element(boundBy: 0)
        conversationCell.press(forDuration: 1.0)
        
        // Check if context menu appears
        XCTAssert(app.buttons["Rename"].exists)
        XCTAssert(app.buttons["Delete"].exists)
        
        // Cancel menu
        app.tap() // Tap outside to dismiss
    }
    
    // MARK: - Theme Testing
    
    func testThemeToggle() {
        app.launch()
        
        // Get the theme toggle button in the navigation bar
        let themeToggle = app.navigationBars["Open WebUI"].buttons.element(boundBy: 0)
        XCTAssert(themeToggle.exists)
        
        // Toggle theme
        themeToggle.tap()
        
        // Toggle back
        themeToggle.tap()
    }
}