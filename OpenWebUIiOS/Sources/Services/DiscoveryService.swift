import Foundation
import Network
import Combine

/// A service for discovering Ollama servers on the local network using Bonjour/mDNS
class DiscoveryService: NSObject, ObservableObject {
    @Published var discoveredServers: [OllamaServer] = []
    @Published var isScanning: Bool = false
    @Published var error: Error?
    
    private var browser: NWBrowser?
    private var connectionsByID: [NWBrowser.Result.ID: NWConnection] = [:]
    
    /// Represents an Ollama server discovered on the network
    struct OllamaServer: Identifiable {
        var id: String { endpoint.debugDescription }
        let name: String
        let endpoint: NWEndpoint
        let hostName: String
        let port: Int
        var available: Bool = false
        var url: URL {
            URL(string: "http://\(hostName):\(port)")!
        }
        var apiURL: URL {
            url.appendingPathComponent("api")
        }
    }
    
    override init() {
        super.init()
    }
    
    /// Start scanning for Ollama servers on the network
    func startDiscovery() {
        // Clear any previous discoveries
        discoveredServers = []
        isScanning = true
        error = nil
        
        // Set up browser parameters for Bonjour
        let params = NWParameters()
        params.includePeerToPeer = true
        
        // Initially, search for any HTTP server (broader search)
        // Ollama doesn't advertise a specific service type, so we'll scan for HTTP and validate later
        let browserDescriptor = NWBrowser.Descriptor.bonjour(type: "_http._tcp", domain: nil)
        browser = NWBrowser(for: browserDescriptor, using: params)
        
        // Set up completion handler for browser status updates
        browser?.stateUpdateHandler = { [weak self] newState in
            guard let self = self else { return }
            
            switch newState {
            case .ready:
                print("Browser is ready")
            case .failed(let error):
                self.isScanning = false
                self.error = error
                print("Browser failed with error: \(error)")
            case .cancelled:
                self.isScanning = false
                print("Browser was cancelled")
            default:
                break
            }
        }
        
        // Handle discovered or removed services
        browser?.browseResultsChangedHandler = { [weak self] results, changes in
            guard let self = self else { return }
            
            // Process added services
            for change in changes {
                switch change {
                case .added(let result):
                    self.processDiscoveredService(result)
                case .removed(let result):
                    self.removeService(result)
                default:
                    break
                }
            }
        }
        
        // Start the browser
        browser?.start(queue: .main)
    }
    
    /// Process a discovered service to check if it's an Ollama server
    private func processDiscoveredService(_ result: NWBrowser.Result) {
        // Extract endpoint information
        guard case let .service(name: serviceName, type: _, domain: _, interface: _) = result.metadata else {
            return
        }
        
        // Extract hostname and port from the endpoint
        switch result.endpoint {
        case .hostPort(let host, let port):
            // Extract host string from Network framework
            let hostName: String
            switch host {
            case .name(let name, _):
                hostName = name
            case .ipv4(let ipv4):
                hostName = ipv4.debugDescription
            case .ipv6(let ipv6):
                hostName = ipv6.debugDescription
            default:
                return
            }
            
            // Create a potential server
            let server = OllamaServer(
                name: serviceName,
                endpoint: result.endpoint,
                hostName: hostName,
                port: Int(port.rawValue)
            )
            
            // Verify if this is actually an Ollama server
            validateOllamaServer(server) { [weak self] isOllama in
                guard let self = self else { return }
                
                if isOllama {
                    DispatchQueue.main.async {
                        // Add to discovered servers if not already present
                        if !self.discoveredServers.contains(where: { $0.id == server.id }) {
                            var validatedServer = server
                            validatedServer.available = true
                            self.discoveredServers.append(validatedServer)
                        }
                    }
                }
            }
        default:
            break
        }
    }
    
    /// Validate that the discovered service is actually an Ollama server
    private func validateOllamaServer(_ server: OllamaServer, completion: @escaping (Bool) -> Void) {
        // Create URL for Ollama API
        let url = server.apiURL.appendingPathComponent("tags")
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 2.0  // Short timeout for quick validation
        
        // Perform a quick request to check if this is an Ollama server
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200,
               let data = data {
                // Try to decode the response as JSON
                do {
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                    
                    // Check if the response has the expected structure of an Ollama server
                    if json?["models"] != nil {
                        completion(true)
                        return
                    }
                } catch {
                    // Not an Ollama server or couldn't parse response
                    completion(false)
                    return
                }
            }
            
            completion(false)
        }
        
        task.resume()
    }
    
    /// Remove a service from the list of discovered servers
    private func removeService(_ result: NWBrowser.Result) {
        DispatchQueue.main.async { [weak self] in
            self?.discoveredServers.removeAll { server in
                server.endpoint.debugDescription == result.endpoint.debugDescription
            }
        }
    }
    
    /// Stop the discovery process
    func stopDiscovery() {
        browser?.cancel()
        browser = nil
        isScanning = false
    }
    
    // Clean up before deinitialization
    deinit {
        stopDiscovery()
    }
}

// MARK: - OllamaServer Preview Data

extension DiscoveryService.OllamaServer {
    static var previewData: [DiscoveryService.OllamaServer] {
        [
            DiscoveryService.OllamaServer(
                name: "MacBook Pro",
                endpoint: NWEndpoint.hostPort(host: .name("macbook-pro.local", nil), port: 11434),
                hostName: "macbook-pro.local",
                port: 11434,
                available: true
            ),
            DiscoveryService.OllamaServer(
                name: "Mac Mini",
                endpoint: NWEndpoint.hostPort(host: .name("mac-mini.local", nil), port: 11434),
                hostName: "mac-mini.local",
                port: 11434,
                available: true
            ),
            DiscoveryService.OllamaServer(
                name: "Ollama Server",
                endpoint: NWEndpoint.hostPort(host: .name("ollama-server.local", nil), port: 11434),
                hostName: "ollama-server.local",
                port: 11434,
                available: false
            )
        ]
    }
}