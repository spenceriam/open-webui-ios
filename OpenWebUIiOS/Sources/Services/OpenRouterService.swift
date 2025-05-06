import Foundation
import Combine

class OpenRouterService {
    private let baseURL: URL
    private let streamingService: StreamingService
    private let session: URLSession
    private let keychainService: KeychainService
    
    init(baseURLString: String = "https://openrouter.ai/api/v1",
         streamingService: StreamingService = StreamingService(),
         session: URLSession = .shared,
         keychainService: KeychainService = KeychainService()) {
        if let url = URL(string: baseURLString) {
            self.baseURL = url
        } else {
            self.baseURL = URL(string: "https://openrouter.ai/api/v1")!
        }
        self.streamingService = streamingService
        self.session = session
        self.keychainService = keychainService
    }
    
    /// Converts array of Messages to OpenRouter API format
    private func formatMessages(_ messages: [Message]) -> [[String: String]] {
        return messages.map { message in
            var role = message.role.rawValue
            // OpenRouter uses the same format as OpenAI: "system", "user", "assistant"
            
            return [
                "role": role,
                "content": message.content
            ]
        }
    }
    
    /// Retrieves the OpenRouter API key from the keychain
    private func getAPIKey() -> AnyPublisher<String, Error> {
        return Future<String, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(APIError.serviceNotAvailable))
                return
            }
            
            do {
                if let apiKey = try self.keychainService.getValue(for: "openrouter_api_key") {
                    promise(.success(apiKey))
                } else {
                    promise(.failure(APIError.authenticationRequired))
                }
            } catch {
                promise(.failure(APIError.authenticationRequired))
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// Generates a chat response using the OpenRouter API (non-streaming)
    func generateChatResponse(modelId: String, messages: [Message]) -> AnyPublisher<String, Error> {
        return getAPIKey()
            .flatMap { [weak self] apiKey -> AnyPublisher<String, Error> in
                guard let self = self else {
                    return Fail(error: APIError.serviceNotAvailable).eraseToAnyPublisher()
                }
                
                // URL for the chat completions endpoint
                let url = self.baseURL.appendingPathComponent("chat/completions")
                
                // Prepare request body
                let requestBody: [String: Any] = [
                    "model": modelId,
                    "messages": self.formatMessages(messages),
                    "stream": false
                ]
                
                // Create request
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                request.addValue("OpenWebUI/iOS", forHTTPHeaderField: "HTTP-Referer")
                
                do {
                    request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
                } catch {
                    return Fail(error: error).eraseToAnyPublisher()
                }
                
                // Make the request
                return self.session.dataTaskPublisher(for: request)
                    .map(\.data)
                    .decode(type: OpenRouterChatResponse.self, decoder: JSONDecoder())
                    .map { response in
                        if let choice = response.choices.first {
                            return choice.message.content
                        }
                        return ""
                    }
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    /// Generates a chat response using OpenRouter API with streaming
    func generateStreamingChatResponse(modelId: String, messages: [Message]) -> AnyPublisher<String, Error> {
        return getAPIKey()
            .flatMap { [weak self] apiKey -> AnyPublisher<String, Error> in
                guard let self = self else {
                    return Fail(error: APIError.serviceNotAvailable).eraseToAnyPublisher()
                }
                
                // URL for the chat completions endpoint
                let url = self.baseURL.appendingPathComponent("chat/completions")
                
                // Prepare request body with streaming enabled
                let requestBody: [String: Any] = [
                    "model": modelId,
                    "messages": self.formatMessages(messages),
                    "stream": true
                ]
                
                do {
                    let requestData = try JSONSerialization.data(withJSONObject: requestBody)
                    
                    // Using HTTP streaming for OpenRouter (same as OpenAI format)
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                    request.addValue("OpenWebUI/iOS", forHTTPHeaderField: "HTTP-Referer")
                    request.httpBody = requestData
                    
                    return self.streamHTTP(request: request)
                    
                } catch {
                    return Fail(error: error).eraseToAnyPublisher()
                }
            }
            .eraseToAnyPublisher()
    }
    
    /// Streams response using HTTP streaming (for OpenRouter)
    private func streamHTTP(request: URLRequest) -> AnyPublisher<String, Error> {
        let subject = PassthroughSubject<String, Error>()
        
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                subject.send(completion: .failure(error))
                return
            }
            
            guard let data = data else {
                subject.send(completion: .failure(APIError.noData))
                return
            }
            
            // Parse SSE format: data: {...}
            if let text = String(data: data, encoding: .utf8) {
                let lines = text.components(separatedBy: "\n")
                
                for line in lines {
                    if line.hasPrefix("data: ") {
                        let jsonString = line.dropFirst(6).trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        if jsonString == "[DONE]" {
                            // End of stream
                            subject.send(completion: .finished)
                            return
                        }
                        
                        do {
                            if let data = jsonString.data(using: .utf8),
                               let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                               let choices = json["choices"] as? [[String: Any]],
                               let choice = choices.first,
                               let delta = choice["delta"] as? [String: Any],
                               let content = delta["content"] as? String {
                                
                                subject.send(content)
                            }
                        } catch {
                            print("Error parsing SSE JSON: \(error)")
                        }
                    }
                }
            }
            
            // Complete when the response is fully received
            subject.send(completion: .finished)
        }
        
        task.resume()
        
        return subject.eraseToAnyPublisher()
    }
    
    /// Fetches available models from OpenRouter
    func fetchAvailableModels() -> AnyPublisher<[AIModel], Error> {
        return getAPIKey()
            .flatMap { [weak self] apiKey -> AnyPublisher<[AIModel], Error> in
                guard let self = self else {
                    return Fail(error: APIError.serviceNotAvailable).eraseToAnyPublisher()
                }
                
                let url = URL(string: "https://openrouter.ai/api/v1/models")!
                
                var request = URLRequest(url: url)
                request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                request.addValue("OpenWebUI/iOS", forHTTPHeaderField: "HTTP-Referer")
                
                return self.session.dataTaskPublisher(for: request)
                    .map(\.data)
                    .decode(type: OpenRouterModelsResponse.self, decoder: JSONDecoder())
                    .map { response in
                        response.data.map { model in
                            AIModel(
                                id: model.id,
                                name: model.name,
                                provider: .openRouter,
                                capabilities: [.textGeneration, .chat],
                                description: model.description,
                                tags: ["openrouter"],
                                metadata: [
                                    "context_length": "\(model.contextLength)",
                                    "pricing_prompt": "\(model.pricingPrompt)",
                                    "pricing_completion": "\(model.pricingCompletion)"
                                ]
                            )
                        }
                    }
                    .catch { error -> AnyPublisher<[AIModel], Error> in
                        // Fallback to placeholder models if fetching fails
                        print("Failed to fetch OpenRouter models: \(error)")
                        return Just([
                            AIModel(id: "anthropic/claude-3-opus", name: "Claude 3 Opus", provider: .openRouter),
                            AIModel(id: "google/gemini-pro", name: "Gemini Pro", provider: .openRouter),
                            AIModel(id: "meta-llama/llama-3-70b", name: "Llama 3 70B", provider: .openRouter)
                        ])
                        .setFailureType(to: Error.self)
                        .eraseToAnyPublisher()
                    }
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
}

// MARK: - Response Models

struct OpenRouterChatResponse: Codable {
    let id: String
    let model: String
    let choices: [Choice]
    
    struct Choice: Codable {
        let message: Message
        let index: Int
        let finishReason: String?
        
        enum CodingKeys: String, CodingKey {
            case message
            case index
            case finishReason = "finish_reason"
        }
    }
    
    struct Message: Codable {
        let role: String
        let content: String
    }
}

struct OpenRouterModelsResponse: Codable {
    let data: [OpenRouterModel]
    
    struct OpenRouterModel: Codable {
        let id: String
        let name: String
        let description: String
        let contextLength: Int
        let pricingPrompt: Double
        let pricingCompletion: Double
        
        enum CodingKeys: String, CodingKey {
            case id
            case name
            case description
            case contextLength = "context_length"
            case pricingPrompt = "pricing.prompt"
            case pricingCompletion = "pricing.completion"
        }
    }
}