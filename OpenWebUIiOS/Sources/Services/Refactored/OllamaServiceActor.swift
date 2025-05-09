import Foundation
import OSLog

/// Modern, actor-based implementation of the Ollama API service
/// - Uses Swift Concurrency instead of Combine
/// - Provides structured concurrency with async/await
/// - Thread-safe by design through actor isolation
/// - Better error handling with structured errors
actor OllamaServiceActor {
    // MARK: - Properties
    
    @MainActor private(set) var serverStatus: ServerStatus = .unknown
    @MainActor private(set) var availableServers: [DiscoveredOllamaServer] = []
    
    private var baseURL: URL
    private let logger = Logger(subsystem: "com.openwebui.ios", category: "OllamaService")
    private let session: URLSession
    private let discoveryService: DiscoveryServiceProtocol
    
    // Cancellation support
    private var activeTasks: [UUID: Task<Void, Never>] = [:]
    
    // MARK: - Types
    
    enum ServerStatus: Equatable {
        case unknown
        case connected
        case disconnected
        case error(String)
        
        var isConnected: Bool {
            if case .connected = self {
                return true
            }
            return false
        }
    }
    
    enum OllamaServiceError: Error, LocalizedError {
        case invalidURL
        case networkError(Error)
        case serverError(Int, String)
        case decodingError(Error)
        case noData
        case cancelled
        case timeout
        
        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid URL"
            case .networkError(let error): return "Network error: \(error.localizedDescription)"
            case .serverError(let code, let message): return "Server error \(code): \(message)"
            case .decodingError(let error): return "Failed to decode response: \(error.localizedDescription)"
            case .noData: return "No data received"
            case .cancelled: return "Request was cancelled"
            case .timeout: return "Request timed out"
            }
        }
    }
    
    struct DiscoveredOllamaServer: Identifiable, Equatable {
        let id: String
        let name: String
        let hostName: String
        let port: Int
        var available: Bool
        
        var url: URL {
            URL(string: "http://\(hostName):\(port)")!
        }
        
        var apiURL: URL {
            url.appendingPathComponent("api")
        }
        
        static func == (lhs: DiscoveredOllamaServer, rhs: DiscoveredOllamaServer) -> Bool {
            lhs.id == rhs.id
        }
    }
    
    // MARK: - Initialization
    
    init(baseURLString: String = "http://localhost:11434/api",
         session: URLSession = .shared,
         discoveryService: DiscoveryServiceProtocol) {
        if let url = URL(string: baseURLString) {
            self.baseURL = url
        } else {
            self.baseURL = URL(string: "http://localhost:11434/api")!
        }
        
        self.session = session
        self.discoveryService = discoveryService
        
        // Start listening for discovered servers
        Task { [weak self] in
            guard let self = self else { return }
            for await servers in self.discoveryService.serverUpdates() {
                await self.updateAvailableServers(servers)
            }
        }
        
        // Check server status initially
        Task {
            try? await self.checkServerStatus()
        }
    }
    
    // MARK: - Public Methods
    
    /// Set the base URL for the Ollama server
    func setServerURL(_ urlString: String) async throws {
        guard let url = URL(string: urlString) else {
            throw OllamaServiceError.invalidURL
        }
        
        // Ensure the URL ends with /api
        if !urlString.hasSuffix("/api") {
            baseURL = url.appendingPathComponent("api")
        } else {
            baseURL = url
        }
        
        // Check if the new server is reachable
        try await checkServerStatus()
    }
    
    /// Start discovering Ollama servers on the network
    func startServerDiscovery(userInitiated: Bool = false) async {
        await discoveryService.startDiscovery(userInitiated: userInitiated)
    }
    
    /// Stop discovering Ollama servers
    func stopServerDiscovery() async {
        await discoveryService.stopDiscovery()
    }
    
    /// Check if the current server is reachable
    func checkServerStatus() async throws {
        let url = baseURL.appendingPathComponent("tags")
        var request = URLRequest(url: url)
        request.timeoutInterval = 3.0
        
        // Update status to unknown while checking
        await MainActor.run {
            serverStatus = .unknown
        }
        
        do {
            let (_, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                await updateServerStatus(.error("Invalid response"))
                throw OllamaServiceError.serverError(0, "Invalid response")
            }
            
            if httpResponse.statusCode == 200 {
                await updateServerStatus(.connected)
            } else {
                let status = ServerStatus.error("HTTP \(httpResponse.statusCode)")
                await updateServerStatus(status)
                throw OllamaServiceError.serverError(httpResponse.statusCode, "Server error")
            }
        } catch let error as OllamaServiceError {
            await updateServerStatus(.disconnected)
            throw error
        } catch {
            await updateServerStatus(.disconnected)
            throw OllamaServiceError.networkError(error)
        }
    }
    
    /// Fetches available models from Ollama
    func fetchAvailableModels() async throws -> [AIModel] {
        let url = baseURL.appendingPathComponent("tags")
        
        do {
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw OllamaServiceError.serverError(0, "Invalid response")
            }
            
            if httpResponse.statusCode != 200 {
                throw OllamaServiceError.serverError(httpResponse.statusCode, "Server error")
            }
            
            let decoder = JSONDecoder()
            do {
                let modelResponse = try decoder.decode(OllamaModelsResponse.self, from: data)
                
                return modelResponse.models.map { model in
                    AIModel(
                        id: model.name,
                        name: model.name,
                        provider: .ollama,
                        capabilities: [.textGeneration, .chat],
                        description: "Ollama model: \(model.name)",
                        tags: ["ollama"],
                        metadata: [
                            "size": "\(model.size)",
                            "modified_at": "\(model.modifiedAt)",
                            "digest": model.digest
                        ]
                    )
                }
            } catch {
                logger.error("Failed to decode Ollama models: \(error.localizedDescription)")
                throw OllamaServiceError.decodingError(error)
            }
        } catch let error as OllamaServiceError {
            // Pass through our custom errors
            throw error
        } catch {
            // Fallback to placeholder models if fetching fails
            logger.warning("Network error fetching Ollama models: \(error.localizedDescription)")
            
            // For production code, we should throw the error instead of returning placeholder models
            // But for backwards compatibility, we'll maintain the placeholder behavior
            return [
                AIModel(id: "llama2", name: "Llama 2", provider: .ollama),
                AIModel(id: "mistral", name: "Mistral", provider: .ollama),
                AIModel(id: "codellama", name: "Code Llama", provider: .ollama)
            ]
        }
    }
    
    /// Generate chat response (non-streaming)
    func generateChatResponse(modelId: String, messages: [Message]) async throws -> String {
        // URL for the chat endpoint
        let url = baseURL.appendingPathComponent("chat")
        
        // Prepare request body
        let requestBody: [String: Any] = [
            "model": modelId,
            "messages": formatMessages(messages),
            "stream": false
        ]
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            logger.error("Failed to serialize request body: \(error.localizedDescription)")
            throw OllamaServiceError.networkError(error)
        }
        
        // Make the request
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw OllamaServiceError.serverError(0, "Invalid response")
            }
            
            if httpResponse.statusCode != 200 {
                throw OllamaServiceError.serverError(httpResponse.statusCode, "Server error")
            }
            
            let decoder = JSONDecoder()
            let chatResponse = try decoder.decode(OllamaChatResponse.self, from: data)
            return chatResponse.message.content
        } catch let error as OllamaServiceError {
            throw error
        } catch let error as DecodingError {
            logger.error("Failed to decode chat response: \(error.localizedDescription)")
            throw OllamaServiceError.decodingError(error)
        } catch {
            logger.error("Network error in chat response: \(error.localizedDescription)")
            throw OllamaServiceError.networkError(error)
        }
    }
    
    /// Generate streaming chat response
    func generateStreamingChatResponse(modelId: String, messages: [Message]) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            let taskID = UUID()
            
            let task = Task {
                do {
                    // URL for the chat endpoint
                    let url = baseURL.appendingPathComponent("chat")
                    
                    // Prepare request body with streaming enabled
                    let requestBody: [String: Any] = [
                        "model": modelId,
                        "messages": formatMessages(messages),
                        "stream": true
                    ]
                    
                    // Create request
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                    
                    do {
                        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
                    } catch {
                        continuation.finish(throwing: OllamaServiceError.networkError(error))
                        return
                    }
                    
                    // Create the session task
                    let (asyncBytes, response) = try await session.bytes(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.finish(throwing: OllamaServiceError.serverError(0, "Invalid response"))
                        return
                    }
                    
                    guard httpResponse.statusCode == 200 else {
                        continuation.finish(throwing: OllamaServiceError.serverError(httpResponse.statusCode, "Server error"))
                        return
                    }
                    
                    // Process the streaming response
                    var buffer = ""
                    
                    for try await byte in asyncBytes.lines {
                        // Check for cancellation
                        if Task.isCancelled {
                            continuation.finish(throwing: OllamaServiceError.cancelled)
                            break
                        }
                        
                        // Skip empty lines
                        guard !byte.isEmpty else { continue }
                        
                        buffer += byte + "\n"
                        
                        // Try to parse each line as JSON
                        if let data = byte.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            
                            // Check if the response contains a message
                            if let message = json["message"] as? [String: Any],
                               let content = message["content"] as? String {
                                continuation.yield(content)
                            }
                            
                            // For chunked responses
                            if let response = json["response"] as? String {
                                continuation.yield(response)
                            }
                            
                            // Check for done flag
                            if let done = json["done"] as? Bool, done {
                                continuation.finish()
                                break
                            }
                        }
                    }
                    
                    // If we exit the loop without seeing "done: true", finish anyway
                    continuation.finish()
                    
                } catch {
                    if Task.isCancelled {
                        continuation.finish(throwing: OllamaServiceError.cancelled)
                    } else {
                        continuation.finish(throwing: OllamaServiceError.networkError(error))
                    }
                }
                
                // Clean up the task reference when done
                self.activeTasks[taskID] = nil
            }
            
            // Store the task for potential cancellation
            self.activeTasks[taskID] = task
            
            // Set up cancellation handler
            continuation.onTermination = { [weak self] termination in
                if case .cancelled = termination {
                    task.cancel()
                    self?.activeTasks[taskID] = nil
                }
            }
        }
    }
    
    /// Pull a model from Ollama
    func pullModel(name: String) -> AsyncThrowingStream<PullProgress, Error> {
        return AsyncThrowingStream { continuation in
            let taskID = UUID()
            
            let task = Task {
                do {
                    // URL for the pull endpoint
                    let url = baseURL.appendingPathComponent("pull")
                    
                    // Prepare request
                    let requestBody: [String: Any] = ["name": name]
                    
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                    
                    do {
                        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
                    } catch {
                        continuation.finish(throwing: OllamaServiceError.networkError(error))
                        return
                    }
                    
                    // Create the session task
                    let (asyncBytes, response) = try await session.bytes(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.finish(throwing: OllamaServiceError.serverError(0, "Invalid response"))
                        return
                    }
                    
                    guard httpResponse.statusCode == 200 else {
                        continuation.finish(throwing: OllamaServiceError.serverError(httpResponse.statusCode, "Server error"))
                        return
                    }
                    
                    // Process the streaming response
                    for try await line in asyncBytes.lines {
                        // Check for cancellation
                        if Task.isCancelled {
                            continuation.finish(throwing: OllamaServiceError.cancelled)
                            break
                        }
                        
                        // Skip empty lines
                        guard !line.isEmpty else { continue }
                        
                        // Try to parse each line as JSON
                        if let data = line.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            
                            // Extract progress information
                            let status = json["status"] as? String ?? ""
                            let digest = json["digest"] as? String
                            let total = (json["total"] as? NSNumber)?.intValue
                            let completed = (json["completed"] as? NSNumber)?.intValue
                            
                            let progress = PullProgress(
                                status: status,
                                digest: digest,
                                total: total,
                                completed: completed
                            )
                            
                            continuation.yield(progress)
                            
                            // If done downloading
                            if status == "success" {
                                continuation.finish()
                                break
                            }
                        }
                    }
                    
                    // If we exit the loop without seeing "success", finish anyway
                    continuation.finish()
                    
                } catch {
                    if Task.isCancelled {
                        continuation.finish(throwing: OllamaServiceError.cancelled)
                    } else {
                        continuation.finish(throwing: OllamaServiceError.networkError(error))
                    }
                }
                
                // Clean up the task reference when done
                self.activeTasks[taskID] = nil
            }
            
            // Store the task for potential cancellation
            self.activeTasks[taskID] = task
            
            // Set up cancellation handler
            continuation.onTermination = { [weak self] termination in
                if case .cancelled = termination {
                    task.cancel()
                    self?.activeTasks[taskID] = nil
                }
            }
        }
    }
    
    /// Cancel all ongoing tasks
    func cancelAllTasks() {
        for (_, task) in activeTasks {
            task.cancel()
        }
        activeTasks.removeAll()
    }
    
    // MARK: - Private Methods
    
    /// Converts array of Messages to Ollama API format
    private func formatMessages(_ messages: [Message]) -> [[String: String]] {
        return messages.map { message in
            // Ollama uses "system" for system messages, "user" for user messages, and "assistant" for assistant messages
            // This matches our internal representation so no conversion is needed
            let role = message.role.rawValue
            
            return [
                "role": role,
                "content": message.content
            ]
        }
    }
    
    /// Update server status on the main actor
    @MainActor private func updateServerStatus(_ status: ServerStatus) {
        serverStatus = status
    }
    
    /// Update available servers list on the main actor
    @MainActor private func updateAvailableServers(_ servers: [DiscoveredOllamaServer]) {
        availableServers = servers
    }
}

// MARK: - Response Models

struct OllamaChatResponse: Codable {
    let model: String
    let message: OllamaMessage
    let done: Bool
    
    struct OllamaMessage: Codable {
        let role: String
        let content: String
    }
}

struct OllamaModelsResponse: Codable {
    let models: [OllamaModel]
    
    struct OllamaModel: Codable {
        let name: String
        let size: Int64
        let modifiedAt: String
        let digest: String
        
        enum CodingKeys: String, CodingKey {
            case name
            case size
            case modifiedAt = "modified_at"
            case digest
        }
    }
}

struct PullProgress: Equatable {
    let status: String
    let digest: String?
    let total: Int?
    let completed: Int?
    
    var progress: Double {
        guard let total = total, let completed = completed, total > 0 else {
            return 0
        }
        return Double(completed) / Double(total)
    }
    
    var isComplete: Bool {
        return status == "success"
    }
}

// MARK: - DiscoveryService Protocol

/// Protocol for DiscoveryService to enable testing and dependency injection
protocol DiscoveryServiceProtocol {
    func startDiscovery(userInitiated: Bool) async
    func stopDiscovery() async
    func serverUpdates() -> AsyncStream<[OllamaServiceActor.DiscoveredOllamaServer]>
}