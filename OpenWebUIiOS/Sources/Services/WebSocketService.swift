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
    private var lastURL: URL?
    private var heartbeatTimer: Timer?
    private var receivingMessage = false
    
    // Battery optimization
    private let powerMonitor = PowerMonitor.shared
    private var cancellables = Set<AnyCancellable>()
    
    override init() {
        super.init()
        
        // Create session with appropriate configuration
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30 // 30 second timeout
        config.waitsForConnectivity = true // Wait for connectivity rather than failing
        self.session = URLSession(configuration: config, delegate: nil, delegateQueue: .main)
        
        // Listen for background/foreground transitions
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.handleAppBackgrounding()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.handleAppForegrounding()
            }
            .store(in: &cancellables)
            
        // Listen for low power mode changes
        NotificationCenter.default.publisher(for: ProcessInfo.processInfo.lowPowerModeDidChangeNotification)
            .sink { [weak self] _ in
                self?.handleLowPowerModeChange()
            }
            .store(in: &cancellables)
    }
    
    func connect(to url: URL) -> AnyPublisher<WebSocketEvent, Error> {
        // Disconnect any existing connection first
        disconnect()
        
        // Store URL for potential reconnection
        lastURL = url
        
        // Configure QoS based on power state
        let qos: URLSessionWebSocketTask.MessageCompression.Mode
        switch powerMonitor.powerMode {
        case .performance:
            qos = .performanceOptimized
        default:
            qos = .dataOptimized
        }
        
        // Create web socket with appropriate configuration
        webSocket = session?.webSocketTask(with: url)
        webSocket?.maximumMessageSize = 1024 * 1024 * 5 // 5MB max message size
        webSocket?.compression = qos
        
        isConnected = true
        
        // Start listening for messages
        receiveMessage()
        
        // Start the connection
        webSocket?.resume()
        
        // Set up heartbeat timer
        setupHeartbeat()
        
        // Notify that we're connected
        messageSubject.send(.connected)
        
        print("WebSocket connected to \(url) with power mode: \(powerMonitor.powerMode.description)")
        
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
        
        // Cancel heartbeat timer
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        
        // Close with normal closure code
        webSocket.cancel(with: .normalClosure, reason: nil)
        self.webSocket = nil
        isConnected = false
        
        // Notify that we're disconnected
        messageSubject.send(.disconnected(reason: "Disconnected by user", code: 1000, error: nil))
    }
    
    private func receiveMessage() {
        guard let webSocket = webSocket, isConnected else { return }
        
        // Mark that we're receiving a message
        receivingMessage = true
        
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
                self.receivingMessage = false
                self.messageSubject.send(completion: .failure(error))
                self.isConnected = false
                self.webSocket = nil
            }
        }
    }
    
    // MARK: - Battery Optimization Methods
    
    /// Set up heartbeat timer for connection maintenance
    private func setupHeartbeat() {
        heartbeatTimer?.invalidate()
        
        // Determine appropriate heartbeat interval based on power state
        let interval: TimeInterval
        switch powerMonitor.powerMode {
        case .performance:
            interval = 30 // 30 seconds in performance mode
        case .balanced:
            interval = 45 // 45 seconds in balanced mode
        case .conservative:
            interval = 60 // 60 seconds in conservative mode
        case .lowPower:
            interval = 90 // 90 seconds in low power mode
        }
        
        // Create timer that adapts to power state
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.sendHeartbeat()
        }
    }
    
    /// Send a ping to keep the connection alive
    private func sendHeartbeat() {
        guard isConnected, let webSocket = webSocket else { return }
        
        // Only send heartbeat if we're not in background or if we need to maintain connection
        if !powerMonitor.isInBackground || receivingMessage {
            // Simple ping to keep the connection alive
            webSocket.sendPing { error in
                if let error = error {
                    print("WebSocket heartbeat failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Handle app entering background
    private func handleAppBackgrounding() {
        print("WebSocket handling app backgrounding")
        
        // If we're not actively receiving a message, disconnect to save battery
        if !receivingMessage {
            suspendConnection()
        } else {
            // If we're receiving a message, keep connection but adjust heartbeat interval
            setupHeartbeat() // This will adapt to power mode
        }
    }
    
    /// Handle app returning to foreground
    private func handleAppForegrounding() {
        print("WebSocket handling app foregrounding")
        
        // Reconnect if we were previously connected
        if let url = lastURL, !isConnected {
            // Reconnect without notifying subscribers
            reconnect()
        } else if isConnected {
            // If still connected, adjust heartbeat for foreground
            setupHeartbeat()
        }
    }
    
    /// Handle low power mode changes
    private func handleLowPowerModeChange() {
        print("WebSocket handling low power mode change: \(powerMonitor.isLowPowerMode)")
        
        // Adjust heartbeat interval
        if isConnected {
            setupHeartbeat()
        }
    }
    
    /// Suspend connection to save battery
    private func suspendConnection() {
        guard isConnected else { return }
        
        print("WebSocket suspending connection to save battery")
        
        // Cancel heartbeat
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        
        // Gracefully disconnect
        disconnect()
    }
    
    /// Reconnect to the last URL
    private func reconnect() {
        guard let url = lastURL, !isConnected else { return }
        
        print("WebSocket reconnecting to \(url)")
        
        // Create web socket with power-appropriate settings
        let qos: URLSessionWebSocketTask.MessageCompression.Mode
        switch powerMonitor.powerMode {
        case .performance:
            qos = .performanceOptimized
        default:
            qos = .dataOptimized
        }
        
        webSocket = session?.webSocketTask(with: url)
        webSocket?.maximumMessageSize = 1024 * 1024 * 5
        webSocket?.compression = qos
        
        isConnected = true
        
        // Start listening for messages
        receiveMessage()
        
        // Start the connection
        webSocket?.resume()
        
        // Set up heartbeat timer
        setupHeartbeat()
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
    private let powerMonitor = PowerMonitor.shared
    
    // Buffering for low-power mode
    private var textBuffer = ""
    private var bufferTimer: Timer?
    private let bufferThreshold = 20 // characters
    
    init(webSocketService: WebSocketServiceProtocol = WebSocketService()) {
        self.webSocketService = webSocketService
    }
    
    /// Connects to a streaming API endpoint and returns text chunks as they arrive
    func streamText(url: URL, requestData: Data) -> AnyPublisher<String, Error> {
        // Check if we should use streaming based on power state
        if !shouldUseStreaming() {
            return fallbackToNonStreaming(url: url, requestData: requestData)
        }
        
        // Configure buffer timer based on power mode
        setupBufferTimer()
        
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
                    if let chunk = self.parseTextChunk(from: text) {
                        // In low power or battery saving modes, buffer small chunks
                        if self.shouldBufferOutput() && chunk.count < self.bufferThreshold {
                            self.addToBuffer(chunk)
                            return Empty<String, Error>().eraseToAnyPublisher()
                        } else {
                            return Just(chunk)
                                .setFailureType(to: Error.self)
                                .eraseToAnyPublisher()
                        }
                    } else {
                        // If no text chunk, just continue
                        return Empty<String, Error>().eraseToAnyPublisher()
                    }
                    
                case .data(let data):
                    // Try to parse data as JSON
                    if let text = String(data: data, encoding: .utf8),
                       let chunk = self.parseTextChunk(from: text) {
                        // In low power or battery saving modes, buffer small chunks
                        if self.shouldBufferOutput() && chunk.count < self.bufferThreshold {
                            self.addToBuffer(chunk)
                            return Empty<String, Error>().eraseToAnyPublisher()
                        } else {
                            return Just(chunk)
                                .setFailureType(to: Error.self)
                                .eraseToAnyPublisher()
                        }
                    } else {
                        return Empty<String, Error>().eraseToAnyPublisher()
                    }
                    
                case .disconnected(let reason, let code, let error):
                    // Flush any remaining buffered text before completing
                    self.flushBuffer()
                    
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
    
    // MARK: - Power Efficiency Methods
    
    /// Determine if streaming should be used based on power state
    private func shouldUseStreaming() -> Bool {
        return powerMonitor.shouldUsePowerIntensiveFeature("streaming")
    }
    
    /// Determine if output should be buffered to reduce UI updates
    private func shouldBufferOutput() -> Bool {
        switch powerMonitor.powerMode {
        case .conservative, .lowPower:
            return true
        default:
            return false
        }
    }
    
    /// Setup buffer timer based on power mode
    private func setupBufferTimer() {
        bufferTimer?.invalidate()
        
        let interval: TimeInterval
        switch powerMonitor.powerMode {
        case .lowPower:
            interval = 1.0 // Update once per second in low power
        case .conservative:
            interval = 0.5 // Update twice per second in conservative
        default:
            interval = 0.2 // Update 5 times per second otherwise
        }
        
        bufferTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.flushBufferIfNeeded()
        }
    }
    
    /// Add text to buffer
    private func addToBuffer(_ text: String) {
        textBuffer += text
    }
    
    /// Flush buffer if it reaches threshold
    private func flushBufferIfNeeded() {
        if textBuffer.count >= bufferThreshold {
            flushBuffer()
        }
    }
    
    /// Force flush the buffer
    private func flushBuffer() {
        if !textBuffer.isEmpty {
            NotificationCenter.default.post(
                name: NSNotification.Name("StreamingTextChunk"),
                object: nil,
                userInfo: ["text": textBuffer]
            )
            textBuffer = ""
        }
    }
    
    /// Fallback to non-streaming API for battery saving
    private func fallbackToNonStreaming(url: URL, requestData: Data) -> AnyPublisher<String, Error> {
        // This would normally implement a non-streaming API call
        // For now, we'll just use the streaming API but with larger buffer
        print("Fallback to non-streaming mode")
        
        // Set a larger buffer threshold
        let originalThreshold = bufferThreshold
        defer { bufferThreshold = originalThreshold }
        
        // Use a much larger buffer to reduce updates
        bufferThreshold = 100
        
        return webSocketService.connect(to: url)
            .flatMap { [weak self] event -> AnyPublisher<String, Error> in
                guard let self = self else {
                    return Fail(error: WebSocketError.notConnected).eraseToAnyPublisher()
                }
                
                // Same processing as streaming but with larger buffering
                switch event {
                case .connected:
                    return self.webSocketService.send(message: requestData)
                        .map { _ -> String in "" }
                        .eraseToAnyPublisher()
                    
                case .message(let text), .data(let data) where data.isEmpty:
                    if let chunk = self.parseTextChunk(from: text) {
                        self.addToBuffer(chunk)
                        return Empty<String, Error>().eraseToAnyPublisher()
                    } else {
                        return Empty<String, Error>().eraseToAnyPublisher()
                    }
                    
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8),
                       let chunk = self.parseTextChunk(from: text) {
                        self.addToBuffer(chunk)
                        return Empty<String, Error>().eraseToAnyPublisher()
                    } else {
                        return Empty<String, Error>().eraseToAnyPublisher()
                    }
                    
                case .disconnected(let reason, let code, let error):
                    self.flushBuffer()
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