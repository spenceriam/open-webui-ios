import Foundation
import Combine

protocol WebSocketServiceProtocol {
    func connect(to url: URL) -> AnyPublisher<WebSocketEvent, Error>
    func send(message: Data) -> AnyPublisher<Void, Error>
    func send(message: String) -> AnyPublisher<Void, Error>
    func disconnect()
}

enum WebSocketEvent {
    case connected
    case disconnected(reason: String?, code: Int?, error: Error?)
    case message(String)
    case data(Data)
    case ping
    case pong
}

class WebSocketService: NSObject, WebSocketServiceProtocol {
    private var webSocket: URLSessionWebSocketTask?
    private var session: URLSession?
    private var messageSubject = PassthroughSubject<WebSocketEvent, Error>()
    private var isConnected = false
    
    override init() {
        super.init()
        self.session = URLSession(configuration: .default, delegate: nil, delegateQueue: .main)
    }
    
    func connect(to url: URL) -> AnyPublisher<WebSocketEvent, Error> {
        // Disconnect any existing connection first
        disconnect()
        
        webSocket = session?.webSocketTask(with: url)
        isConnected = true
        
        // Start listening for messages
        receiveMessage()
        
        // Start the connection
        webSocket?.resume()
        
        // Notify that we're connected
        messageSubject.send(.connected)
        
        return messageSubject.eraseToAnyPublisher()
    }
    
    func send(message: Data) -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { [weak self] promise in
            guard let self = self, let webSocket = self.webSocket, self.isConnected else {
                promise(.failure(WebSocketError.notConnected))
                return
            }
            
            webSocket.send(.data(message)) { error in
                if let error = error {
                    promise(.failure(error))
                } else {
                    promise(.success(()))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    func send(message: String) -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { [weak self] promise in
            guard let self = self, let webSocket = self.webSocket, self.isConnected else {
                promise(.failure(WebSocketError.notConnected))
                return
            }
            
            webSocket.send(.string(message)) { error in
                if let error = error {
                    promise(.failure(error))
                } else {
                    promise(.success(()))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    func disconnect() {
        guard let webSocket = webSocket, isConnected else { return }
        
        // Close with normal closure code
        webSocket.cancel(with: .normalClosure, reason: nil)
        self.webSocket = nil
        isConnected = false
        
        // Notify that we're disconnected
        messageSubject.send(.disconnected(reason: "Disconnected by user", code: 1000, error: nil))
    }
    
    private func receiveMessage() {
        guard let webSocket = webSocket, isConnected else { return }
        
        webSocket.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.messageSubject.send(.message(text))
                case .data(let data):
                    self.messageSubject.send(.data(data))
                @unknown default:
                    break
                }
                
                // Continue receiving messages
                self.receiveMessage()
                
            case .failure(let error):
                self.messageSubject.send(completion: .failure(error))
                self.isConnected = false
                self.webSocket = nil
            }
        }
    }
}

enum WebSocketError: Error {
    case notConnected
    case invalidURL
    case messageEncodingFailed
    case messageDecodingFailed
    case connectionError(Error)
}

// MARK: - Streaming API Adapter
class StreamingService {
    private let webSocketService: WebSocketServiceProtocol
    
    init(webSocketService: WebSocketServiceProtocol = WebSocketService()) {
        self.webSocketService = webSocketService
    }
    
    /// Connects to a streaming API endpoint and returns text chunks as they arrive
    func streamText(url: URL, requestData: Data) -> AnyPublisher<String, Error> {
        return webSocketService.connect(to: url)
            .flatMap { [weak self] event -> AnyPublisher<String, Error> in
                guard let self = self else {
                    return Fail(error: WebSocketError.notConnected).eraseToAnyPublisher()
                }
                
                switch event {
                case .connected:
                    // Send the initial request once connected
                    return self.webSocketService.send(message: requestData)
                        .map { _ -> String in "" }
                        .eraseToAnyPublisher()
                    
                case .message(let text):
                    // Parse the response and extract the text chunk
                    do {
                        if let chunk = self.parseTextChunk(from: text) {
                            return Just(chunk)
                                .setFailureType(to: Error.self)
                                .eraseToAnyPublisher()
                        } else {
                            // If no text chunk, just continue
                            return Empty<String, Error>().eraseToAnyPublisher()
                        }
                    } catch {
                        return Fail(error: error).eraseToAnyPublisher()
                    }
                    
                case .data(let data):
                    // Try to parse data as JSON
                    do {
                        if let text = String(data: data, encoding: .utf8),
                           let chunk = self.parseTextChunk(from: text) {
                            return Just(chunk)
                                .setFailureType(to: Error.self)
                                .eraseToAnyPublisher()
                        } else {
                            return Empty<String, Error>().eraseToAnyPublisher()
                        }
                    } catch {
                        return Fail(error: error).eraseToAnyPublisher()
                    }
                    
                case .disconnected(let reason, let code, let error):
                    if let error = error {
                        return Fail(error: error).eraseToAnyPublisher()
                    } else {
                        return Empty<String, Error>(completeImmediately: true).eraseToAnyPublisher()
                    }
                    
                default:
                    return Empty<String, Error>().eraseToAnyPublisher()
                }
            }
            .eraseToAnyPublisher()
    }
    
    /// Parse a text chunk from a streaming API response
    /// The actual implementation will depend on the specific format of the API's streaming response
    private func parseTextChunk(from text: String) -> String? {
        // Different providers will have different formats for streaming responses
        // This is a basic implementation that assumes each line is a JSON object
        // with a "text" or "content" field
        
        guard !text.isEmpty else { return nil }
        
        // Handle SSE format (data: {...})
        if text.hasPrefix("data: ") {
            let jsonString = text.dropFirst(6).trimmingCharacters(in: .whitespacesAndNewlines)
            if jsonString == "[DONE]" {
                return nil // End of stream marker
            }
            
            do {
                if let data = jsonString.data(using: .utf8),
                   let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    
                    // Handle OpenAI format
                    if let choices = json["choices"] as? [[String: Any]],
                       let choice = choices.first,
                       let delta = choice["delta"] as? [String: Any],
                       let content = delta["content"] as? String {
                        return content
                    }
                    
                    // Handle Ollama format
                    if let response = json["response"] as? String {
                        return response
                    }
                    
                    // Handle generic format
                    if let content = json["content"] as? String {
                        return content
                    }
                    
                    if let text = json["text"] as? String {
                        return text
                    }
                }
            } catch {
                print("Error parsing JSON from stream: \(error)")
                return nil
            }
        }
        
        // If it's not JSON or doesn't match expected format, return the raw text
        // This is a fallback and might need adjustment based on the actual API response format
        return text
    }
}