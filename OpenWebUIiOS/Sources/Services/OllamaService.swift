import Foundation
import Combine
import Network

class OllamaService: ObservableObject {
    @Published var baseURL: URL
    @Published var serverStatus: ServerStatus = .unknown
    @Published var availableServers: [DiscoveryService.OllamaServer] = []
    
    private let streamingService: StreamingService
    private let session: URLSession
    private let discoveryService: DiscoveryService
    private var cancellables = Set<AnyCancellable>()
    
    enum ServerStatus {
        case unknown
        case connected
        case disconnected
        case error(String)
    }
    
    init(baseURLString: String = "http://localhost:11434/api", 
         streamingService: StreamingService = StreamingService(),
         session: URLSession = .shared,
         discoveryService: DiscoveryService = DiscoveryService()) {
        if let url = URL(string: baseURLString) {
            self.baseURL = url
        } else {
            self.baseURL = URL(string: "http://localhost:11434/api")!
        }
        self.streamingService = streamingService
        self.session = session
        self.discoveryService = discoveryService
        
        // Subscribe to discovered servers from the discovery service
        discoveryService.$discoveredServers
            .sink { [weak self] servers in
                self?.availableServers = servers
            }
            .store(in: &cancellables)
        
        // Check the server status on initialization
        checkServerStatus()
    }
    
    /// Change the server URL
    func setServerURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        
        // Ensure the URL ends with /api
        if !urlString.hasSuffix("/api") {
            baseURL = url.appendingPathComponent("api")
        } else {
            baseURL = url
        }
        
        // Check if the new server is reachable
        checkServerStatus()
    }
    
    /// Start discovering Ollama servers on the network
    func startServerDiscovery() {
        discoveryService.startDiscovery()
    }
    
    /// Stop discovering Ollama servers
    func stopServerDiscovery() {
        discoveryService.stopDiscovery()
    }
    
    /// Check if the current server is reachable
    func checkServerStatus() {
        let url = baseURL.appendingPathComponent("tags")
        var request = URLRequest(url: url)
        request.timeoutInterval = 3.0
        
        // Update status to unknown while checking
        serverStatus = .unknown
        
        session.dataTaskPublisher(for: request)
            .map { data, response -> ServerStatus in
                guard let httpResponse = response as? HTTPURLResponse else {
                    return .error("Invalid response")
                }
                
                if httpResponse.statusCode == 200 {
                    return .connected
                } else {
                    return .error("HTTP \(httpResponse.statusCode)")
                }
            }
            .replaceError(with: .disconnected)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.serverStatus = status
            }
            .store(in: &cancellables)
    }
    
    /// Converts array of Messages to Ollama API format
    private func formatMessages(_ messages: [Message]) -> [[String: String]] {
        return messages.map { message in
            var role = message.role.rawValue
            // Ollama uses "system" for system messages, "user" for user messages, and "assistant" for assistant messages
            // This matches our internal representation so no conversion is needed
            
            return [
                "role": role,
                "content": message.content
            ]
        }
    }
    
    /// Generates a chat response using the Ollama API (non-streaming)
    func generateChatResponse(modelId: String, messages: [Message]) -> AnyPublisher<String, Error> {
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
            return Fail(error: error).eraseToAnyPublisher()
        }
        
        // Make the request
        return session.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: OllamaChatResponse.self, decoder: JSONDecoder())
            .map { $0.message.content }
            .eraseToAnyPublisher()
    }
    
    /// Generates a chat response using Ollama API with streaming
    func generateStreamingChatResponse(modelId: String, messages: [Message]) -> AnyPublisher<String, Error> {
        // URL for the chat endpoint
        let url = baseURL.appendingPathComponent("chat")
        
        // Prepare request body with streaming enabled
        let requestBody: [String: Any] = [
            "model": modelId,
            "messages": formatMessages(messages),
            "stream": true
        ]
        
        do {
            let requestData = try JSONSerialization.data(withJSONObject: requestBody)
            
            // In real implementation, we would use HTTP streaming
            return streamHTTP(url: url, requestData: requestData)
            
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
    }
    
    /// Streams response using HTTP streaming (for Ollama)
    private func streamHTTP(url: URL, requestData: Data) -> AnyPublisher<String, Error> {
        let subject = PassthroughSubject<String, Error>()
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = requestData
        
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                subject.send(completion: .failure(error))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse, 
               !(200...299).contains(httpResponse.statusCode) {
                subject.send(completion: .failure(NSError(domain: "Ollama",
                                                          code: httpResponse.statusCode,
                                                          userInfo: [NSLocalizedDescriptionKey: "Server returned status code \(httpResponse.statusCode)"])))
                return
            }
            
            guard let data = data else {
                subject.send(completion: .failure(NSError(domain: "Ollama",
                                                          code: -1,
                                                          userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            // For line-delimited JSON
            if let text = String(data: data, encoding: .utf8) {
                let lines = text.components(separatedBy: "\n")
                
                for line in lines {
                    if !line.isEmpty {
                        do {
                            if let jsonData = line.data(using: .utf8),
                               let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                                
                                // Check if the response contains a message
                                if let message = json["message"] as? [String: Any],
                                   let content = message["content"] as? String {
                                    subject.send(content)
                                }
                                
                                // For chunked responses
                                if let response = json["response"] as? String {
                                    subject.send(response)
                                }
                                
                                // Check for done flag
                                if let done = json["done"] as? Bool, done {
                                    subject.send(completion: .finished)
                                    return
                                }
                            }
                        } catch {
                            print("Error parsing JSON: \(error), line: \(line)")
                        }
                    }
                }
                
                // If we didn't find a "done: true" marker, complete anyway after parsing all lines
                subject.send(completion: .finished)
            } else {
                subject.send(completion: .failure(NSError(domain: "Ollama",
                                                         code: -1,
                                                         userInfo: [NSLocalizedDescriptionKey: "Could not decode data as UTF-8"])))
            }
        }
        
        task.resume()
        
        return subject.eraseToAnyPublisher()
    }
    
    /// Fetches available models from Ollama
    func fetchAvailableModels() -> AnyPublisher<[AIModel], Error> {
        let url = baseURL.appendingPathComponent("tags")
        
        return session.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: OllamaModelsResponse.self, decoder: JSONDecoder())
            .map { response in
                response.models.map { model in
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
            }
            .catch { error -> AnyPublisher<[AIModel], Error> in
                // Fallback to placeholder models if fetching fails
                print("Failed to fetch Ollama models: \(error)")
                return Just([
                    AIModel(id: "llama2", name: "Llama 2", provider: .ollama),
                    AIModel(id: "mistral", name: "Mistral", provider: .ollama),
                    AIModel(id: "codellama", name: "Code Llama", provider: .ollama)
                ])
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    /// Pull a model from Ollama
    func pullModel(name: String) -> AnyPublisher<PullProgress, Error> {
        let url = baseURL.appendingPathComponent("pull")
        let requestBody: [String: Any] = ["name": name]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
        
        let subject = PassthroughSubject<PullProgress, Error>()
        
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                subject.send(completion: .failure(error))
                return
            }
            
            guard let data = data else {
                subject.send(completion: .failure(NSError(domain: "Ollama",
                                                         code: -1,
                                                         userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            // For line-delimited JSON progress updates
            if let text = String(data: data, encoding: .utf8) {
                let lines = text.components(separatedBy: "\n")
                
                for line in lines {
                    if !line.isEmpty {
                        do {
                            if let jsonData = line.data(using: .utf8),
                               let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                                
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
                                
                                subject.send(progress)
                                
                                // If done downloading
                                if status == "success" {
                                    subject.send(completion: .finished)
                                    return
                                }
                            }
                        } catch {
                            print("Error parsing JSON: \(error)")
                        }
                    }
                }
                
                subject.send(completion: .finished)
            } else {
                subject.send(completion: .failure(NSError(domain: "Ollama",
                                                         code: -1,
                                                         userInfo: [NSLocalizedDescriptionKey: "Could not decode data as UTF-8"])))
            }
        }
        
        task.resume()
        
        return subject.eraseToAnyPublisher()
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

// MARK: - Pull Progress

struct PullProgress {
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