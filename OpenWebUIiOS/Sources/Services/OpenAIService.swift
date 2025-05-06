import Foundation
import Combine

class OpenAIService {
    private let baseURL: URL
    private let streamingService: StreamingService
    private let session: URLSession
    private let keychainService: KeychainService
    
    init(baseURLString: String = "https://api.openai.com/v1",
         streamingService: StreamingService = StreamingService(),
         session: URLSession = .shared,
         keychainService: KeychainService = KeychainService()) {
        if let url = URL(string: baseURLString) {
            self.baseURL = url
        } else {
            self.baseURL = URL(string: "https://api.openai.com/v1")!
        }
        self.streamingService = streamingService
        self.session = session
        self.keychainService = keychainService
    }
    
    /// Converts array of Messages to OpenAI API format
    private func formatMessages(_ messages: [Message]) -> [[String: String]] {
        return messages.map { message in
            var role = message.role.rawValue
            // OpenAI uses "system" for system messages, "user" for user messages, and "assistant" for assistant messages
            // This matches our internal representation so no conversion is needed
            
            return [
                "role": role,
                "content": message.content
            ]
        }
    }
    
    /// Retrieves the OpenAI API key from the keychain
    private func getAPIKey() -> AnyPublisher<String, Error> {
        return Future<String, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(APIError.serviceNotAvailable))
                return
            }
            
            do {
                if let apiKey = try self.keychainService.getValue(for: "openai_api_key") {
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
    
    /// Generates a chat response using the OpenAI API (non-streaming)
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
                
                do {
                    request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
                } catch {
                    return Fail(error: error).eraseToAnyPublisher()
                }
                
                // Make the request
                return self.session.dataTaskPublisher(for: request)
                    .map(\.data)
                    .decode(type: OpenAIChatResponse.self, decoder: JSONDecoder())
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
    
    /// Generates a chat response using OpenAI API with streaming
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
                    
                    // Using HTTP streaming for OpenAI (not WebSockets)
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                    request.httpBody = requestData
                    
                    return self.streamHTTP(request: request)
                    
                } catch {
                    return Fail(error: error).eraseToAnyPublisher()
                }
            }
            .eraseToAnyPublisher()
    }
    
    /// Streams response using HTTP streaming (for OpenAI)
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
    
    /// Fetches available models from OpenAI
    func fetchAvailableModels() -> AnyPublisher<[AIModel], Error> {
        return getAPIKey()
            .flatMap { [weak self] apiKey -> AnyPublisher<[AIModel], Error> in
                guard let self = self else {
                    return Fail(error: APIError.serviceNotAvailable).eraseToAnyPublisher()
                }
                
                let url = self.baseURL.appendingPathComponent("models")
                
                var request = URLRequest(url: url)
                request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                
                return self.session.dataTaskPublisher(for: request)
                    .map(\.data)
                    .decode(type: OpenAIModelsResponse.self, decoder: JSONDecoder())
                    .map { response in
                        response.data.filter { model in
                            // Filter to include only chat models
                            model.id.contains("gpt")
                        }.map { model in
                            AIModel(
                                id: model.id,
                                name: model.id, // Could be enhanced to format the name better
                                provider: .openAI,
                                capabilities: [.textGeneration, .chat],
                                description: model.id,
                                tags: ["openai"],
                                metadata: [
                                    "owner": model.ownedBy
                                ]
                            )
                        }
                    }
                    .catch { error -> AnyPublisher<[AIModel], Error> in
                        // Fallback to placeholder models if fetching fails
                        print("Failed to fetch OpenAI models: \(error)")
                        return Just([
                            AIModel(id: "gpt-4", name: "GPT-4", provider: .openAI),
                            AIModel(id: "gpt-3.5-turbo", name: "GPT-3.5 Turbo", provider: .openAI)
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

struct OpenAIChatResponse: Codable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [Choice]
    let usage: Usage
    
    struct Choice: Codable {
        let index: Int
        let message: Message
        let finishReason: String?
        
        enum CodingKeys: String, CodingKey {
            case index
            case message
            case finishReason = "finish_reason"
        }
    }
    
    struct Message: Codable {
        let role: String
        let content: String
    }
    
    struct Usage: Codable {
        let promptTokens: Int
        let completionTokens: Int
        let totalTokens: Int
        
        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
        }
    }
}

struct OpenAIModelsResponse: Codable {
    let data: [OpenAIModel]
    
    struct OpenAIModel: Codable {
        let id: String
        let object: String
        let created: Int
        let ownedBy: String
        
        enum CodingKeys: String, CodingKey {
            case id
            case object
            case created
            case ownedBy = "owned_by"
        }
    }
}

// MARK: - Error Types

enum APIError: Error {
    case authenticationRequired
    case serviceNotAvailable
    case noData
    case invalidResponse
    case rateLimited
    case serverError
}