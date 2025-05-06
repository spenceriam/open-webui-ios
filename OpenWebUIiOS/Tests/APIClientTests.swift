import XCTest
@testable import OpenWebUIiOS

final class APIClientTests: XCTestCase {
    
    // MARK: - Test Properties
    
    private var ollamaService: OllamaService!
    private var openAIService: OpenAIService!
    private var openRouterService: OpenRouterService!
    private var mockURLSession: MockURLSession!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        mockURLSession = MockURLSession()
        
        ollamaService = OllamaService()
        ollamaService.urlSession = mockURLSession
        
        openAIService = OpenAIService()
        openAIService.urlSession = mockURLSession
        
        openRouterService = OpenRouterService()
        openRouterService.urlSession = mockURLSession
    }
    
    override func tearDown() {
        ollamaService = nil
        openAIService = nil
        openRouterService = nil
        mockURLSession = nil
        super.tearDown()
    }
    
    // MARK: - Ollama Tests
    
    func testOllamaModelListRequest() {
        // Given
        let expectedURL = URL(string: "http://localhost:11434/api/tags")!
        let jsonResponse = """
        {
            "models": [
                {
                    "name": "llama2",
                    "modified_at": "2023-06-10T15:22:09.8353459Z"
                },
                {
                    "name": "mistral",
                    "modified_at": "2023-06-12T09:14:42.1356733Z"
                }
            ]
        }
        """.data(using: .utf8)!
        
        mockURLSession.mockResponse = (jsonResponse, HTTPURLResponse(url: expectedURL, statusCode: 200, httpVersion: nil, headerFields: nil)!, nil)
        
        // When
        let expectation = expectation(description: "Fetch models from Ollama")
        var receivedModels: [AIModel] = []
        
        ollamaService.fetchAvailableModels()
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    XCTFail("Error: \(error)")
                }
            }, receiveValue: { models in
                receivedModels = models
                expectation.fulfill()
            })
            .store(in: &ollamaService.cancellables)
        
        // Then
        waitForExpectations(timeout: 1)
        XCTAssertEqual(mockURLSession.lastURL?.absoluteString, expectedURL.absoluteString)
        XCTAssertEqual(receivedModels.count, 2)
        XCTAssertEqual(receivedModels[0].name, "llama2")
        XCTAssertEqual(receivedModels[1].name, "mistral")
    }
    
    func testOllamaServerStatus() {
        // Given
        let expectedURL = URL(string: "http://localhost:11434/api/version")!
        let jsonResponse = """
        {
            "version": "0.1.14"
        }
        """.data(using: .utf8)!
        
        mockURLSession.mockResponse = (jsonResponse, HTTPURLResponse(url: expectedURL, statusCode: 200, httpVersion: nil, headerFields: nil)!, nil)
        
        // When
        ollamaService.checkServerStatus()
        
        // Then
        XCTAssertEqual(mockURLSession.lastURL?.absoluteString, expectedURL.absoluteString)
        XCTAssertEqual(ollamaService.serverStatus, .connected)
    }
    
    func testOllamaServerStatusFailure() {
        // Given
        let expectedURL = URL(string: "http://localhost:11434/api/version")!
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotConnectToHost, userInfo: nil)
        
        mockURLSession.mockResponse = (nil, HTTPURLResponse(url: expectedURL, statusCode: 500, httpVersion: nil, headerFields: nil)!, error)
        
        // When
        ollamaService.checkServerStatus()
        
        // Then
        XCTAssertEqual(mockURLSession.lastURL?.absoluteString, expectedURL.absoluteString)
        
        if case .disconnected = ollamaService.serverStatus {
            // Success
        } else {
            XCTFail("Expected disconnected status, got \(ollamaService.serverStatus)")
        }
    }
    
    // MARK: - OpenAI Tests
    
    func testOpenAIModelListRequest() {
        // Given
        let expectedURL = URL(string: "https://api.openai.com/v1/models")!
        let jsonResponse = """
        {
            "data": [
                {
                    "id": "gpt-4-turbo",
                    "object": "model",
                    "created": 1677649963,
                    "owned_by": "openai"
                },
                {
                    "id": "gpt-3.5-turbo",
                    "object": "model",
                    "created": 1677610602,
                    "owned_by": "openai"
                }
            ]
        }
        """.data(using: .utf8)!
        
        mockURLSession.mockResponse = (jsonResponse, HTTPURLResponse(url: expectedURL, statusCode: 200, httpVersion: nil, headerFields: nil)!, nil)
        
        // When
        let expectation = expectation(description: "Fetch models from OpenAI")
        var receivedModels: [AIModel] = []
        
        openAIService.fetchAvailableModels()
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    XCTFail("Error: \(error)")
                }
            }, receiveValue: { models in
                receivedModels = models
                expectation.fulfill()
            })
            .store(in: &openAIService.cancellables)
        
        // Then
        waitForExpectations(timeout: 1)
        XCTAssertEqual(mockURLSession.lastURL?.absoluteString, expectedURL.absoluteString)
        XCTAssertEqual(receivedModels.count, 2)
        XCTAssertEqual(receivedModels[0].name, "gpt-4-turbo")
        XCTAssertEqual(receivedModels[1].name, "gpt-3.5-turbo")
    }
    
    func testOpenAIApiKeyValidation() {
        // Given
        let expectedURL = URL(string: "https://api.openai.com/v1/models")!
        let jsonResponse = """
        {
            "data": [
                {
                    "id": "gpt-4",
                    "object": "model",
                    "created": 1677649963,
                    "owned_by": "openai"
                }
            ]
        }
        """.data(using: .utf8)!
        
        mockURLSession.mockResponse = (jsonResponse, HTTPURLResponse(url: expectedURL, statusCode: 200, httpVersion: nil, headerFields: nil)!, nil)
        
        // When
        let expectation = expectation(description: "Validate OpenAI API key")
        var isValid = false
        
        openAIService.validateAPIKey("test_key")
            .sink(receiveCompletion: { completion in
                if case .failure = completion {
                    isValid = false
                    expectation.fulfill()
                }
            }, receiveValue: { valid in
                isValid = valid
                expectation.fulfill()
            })
            .store(in: &openAIService.cancellables)
        
        // Then
        waitForExpectations(timeout: 1)
        XCTAssertEqual(mockURLSession.lastURL?.absoluteString, expectedURL.absoluteString)
        XCTAssertTrue(isValid)
        
        // Verify headers
        XCTAssertEqual(mockURLSession.lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer test_key")
    }
    
    // MARK: - OpenRouter Tests
    
    func testOpenRouterModelListRequest() {
        // Given
        let expectedURL = URL(string: "https://openrouter.ai/api/v1/models")!
        let jsonResponse = """
        {
            "data": [
                {
                    "id": "anthropic/claude-2.1",
                    "name": "Claude 2.1",
                    "created": 1699629465,
                    "owned_by": "anthropic"
                },
                {
                    "id": "google/palm-2",
                    "name": "PaLM 2",
                    "created": 1689359465,
                    "owned_by": "google"
                }
            ]
        }
        """.data(using: .utf8)!
        
        mockURLSession.mockResponse = (jsonResponse, HTTPURLResponse(url: expectedURL, statusCode: 200, httpVersion: nil, headerFields: nil)!, nil)
        
        // When
        let expectation = expectation(description: "Fetch models from OpenRouter")
        var receivedModels: [AIModel] = []
        
        openRouterService.fetchAvailableModels()
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    XCTFail("Error: \(error)")
                }
            }, receiveValue: { models in
                receivedModels = models
                expectation.fulfill()
            })
            .store(in: &openRouterService.cancellables)
        
        // Then
        waitForExpectations(timeout: 1)
        XCTAssertEqual(mockURLSession.lastURL?.absoluteString, expectedURL.absoluteString)
        XCTAssertEqual(receivedModels.count, 2)
        XCTAssertEqual(receivedModels[0].name, "Claude 2.1")
        XCTAssertEqual(receivedModels[0].id, "anthropic/claude-2.1")
        XCTAssertEqual(receivedModels[1].name, "PaLM 2")
        XCTAssertEqual(receivedModels[1].id, "google/palm-2")
    }
}

// MARK: - Mock URLSession

class MockURLSession: URLSession {
    var mockResponse: (Data?, URLResponse, Error?)
    var lastURL: URL?
    var lastRequest: URLRequest?
    
    init(mockResponse: (Data?, URLResponse, Error?) = (nil, URLResponse(), nil)) {
        self.mockResponse = mockResponse
        super.init()
    }
    
    override func dataTask(with request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask {
        lastURL = request.url
        lastRequest = request
        
        return MockURLSessionDataTask {
            completionHandler(self.mockResponse.0, self.mockResponse.1, self.mockResponse.2)
        }
    }
}

class MockURLSessionDataTask: URLSessionDataTask {
    private let completionHandler: () -> Void
    
    init(completionHandler: @escaping () -> Void) {
        self.completionHandler = completionHandler
        super.init()
    }
    
    override func resume() {
        completionHandler()
    }
}