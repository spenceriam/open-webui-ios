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
    private var pollingTimer: Timer?
    private var lastPollTime: Date?
    
    // Battery optimization
    private let powerMonitor = PowerMonitor.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Adaptive polling settings
    private var userInitiatedScan = false // Flag to indicate if scan was requested by user
    private var isPaused = false // Flag to indicate if discovery is paused
    
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
        
        // Set up observers for battery state
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.pauseDiscoveryIfPossible()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.resumeDiscoveryIfNeeded()
            }
            .store(in: &cancellables)
            
        NotificationCenter.default.publisher(for: ProcessInfo.processInfo.lowPowerModeDidChangeNotification)
            .sink { [weak self] _ in
                self?.handleLowPowerModeChange()
            }
            .store(in: &cancellables)
    }
    
    /// Start scanning for Ollama servers on the network
    func startDiscovery(userInitiated: Bool = false) {
        // Set flag for user-initiated scan
        userInitiatedScan = userInitiated
        
        // If polling timer exists, invalidate it
        pollingTimer?.invalidate()
        pollingTimer = nil
        
        // Reset pause state
        isPaused = false
        
        // Start immediate scan
        performDiscoveryScan()
        
        // Set up periodic polling based on power state
        setupPollingTimer()
    }
    
    /// Set up polling timer with adaptive interval based on power state
    private func setupPollingTimer() {
        pollingTimer?.invalidate()
        
        // Get appropriate polling interval
        let interval = powerMonitor.suggestedPollingInterval
        
        // Create new timer
        pollingTimer = Timer.scheduledTimer(
            withTimeInterval: interval,
            repeats: true
        ) { [weak self] _ in
            guard let self = self, !self.isPaused else { return }
            
            // Only perform scan if conditions are met
            if self.shouldPerformPoll() {
                self.performDiscoveryScan(isPolling: true)
            }
            
            // Dynamically adjust timer interval
            if let timer = self.pollingTimer,
               timer.timeInterval != self.powerMonitor.suggestedPollingInterval {
                self.setupPollingTimer() // Restart with updated interval
            }
        }
    }
    
    /// Determine if polling should be performed based on conditions
    private func shouldPerformPoll() -> Bool {
        // Don't poll if we're in background or in low power mode
        // unless this was a user-initiated scan
        if powerMonitor.isInBackground && !userInitiatedScan {
            return false
        }
        
        // If in low power mode, limit polling frequency
        if powerMonitor.isLowPowerMode && !userInitiatedScan {
            // If last poll was less than 2 minutes ago, skip
            if let lastPoll = lastPollTime, 
               Date().timeIntervalSince(lastPoll) < 120 {
                return false
            }
        }
        
        return true
    }
    
    /// Perform the actual discovery scan
    private func performDiscoveryScan(isPolling: Bool = false) {
        // Clear previous discoveries if this isn't a polling update
        if !isPolling {
            discoveredServers = []
        }
        
        // Mark last poll time
        lastPollTime = Date()
        
        // Update state
        isScanning = true
        error = nil
        
        // Set up browser parameters for Bonjour
        let params = NWParameters()
        params.includePeerToPeer = true
        
        // Use more aggressive timeouts in low power mode
        if powerMonitor.isLowPowerMode {
            params.prohibitExpensivePaths = true
            params.prohibitConstrained = true
        }
        
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
            
            // Process added services with adaptive validation
            for change in changes {
                switch change {
                case .added(let result):
                    // In low power mode, limit validation rate
                    if self.powerMonitor.isLowPowerMode && 
                       !self.userInitiatedScan && 
                       self.discoveredServers.count >= 3 {
                        // Skip validation if we already have several servers
                        continue
                    }
                    
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
        
        // Set a timeout to stop the browser in low power mode
        if powerMonitor.isLowPowerMode && !userInitiatedScan {
            DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
                // Only stop if this is still the active browser
                if let self = self, self.isScanning {
                    self.stopCurrentScan()
                }
            }
        }
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
        
        // Adjust timeout based on power state
        let timeout: TimeInterval
        switch powerMonitor.powerMode {
        case .performance:
            timeout = 5.0   // Longer timeout for better reliability
        case .balanced:
            timeout = 3.0   // Standard timeout
        case .conservative:
            timeout = 2.0   // Shorter timeout
        case .lowPower:
            timeout = 1.5   // Very short timeout
        }
        
        request.timeoutInterval = timeout
        
        // Cache policy depending on power status
        if powerMonitor.isLowPowerMode || powerMonitor.batteryLevel < 0.2 {
            request.cachePolicy = .returnCacheDataElseLoad
        } else {
            request.cachePolicy = .useProtocolCachePolicy
        }
        
        // Perform a quick request to check if this is an Ollama server
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else {
                completion(false)
                return
            }
            
            // Skip validation processing if discovery was paused
            if self.isPaused && !self.userInitiatedScan {
                completion(false)
                return
            }
            
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
        
        // Set task priority based on power state
        let qos: DispatchQoS.QoSClass
        if userInitiatedScan {
            qos = .userInitiated
        } else {
            qos = powerMonitor.appropriateQoSClass
        }
        
        task.priority = URLSessionTask.highPriority
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
    
    /// Stop the current scan but keep polling timer active
    func stopCurrentScan() {
        browser?.cancel()
        browser = nil
        isScanning = false
    }
    
    /// Stop the discovery process completely
    func stopDiscovery() {
        // Stop the browser
        browser?.cancel()
        browser = nil
        
        // Cancel polling timer
        pollingTimer?.invalidate()
        pollingTimer = nil
        
        isScanning = false
        isPaused = false
    }
    
    /// Reduce polling frequency to save power
    func reducePollingFrequency() {
        // Double current polling interval if not paused
        if !isPaused && pollingTimer != nil {
            setupPollingTimer()
            print("Reduced discovery polling frequency to save power")
        }
    }
    
    /// Pause discovery when app is in background
    func pauseDiscoveryIfPossible() {
        // If we're not actively scanning or this was user-initiated, we can pause
        if !userInitiatedScan {
            isPaused = true
            stopCurrentScan()
            print("Paused discovery scanning to save battery")
        }
    }
    
    /// Resume discovery when app comes to foreground
    func resumeDiscoveryIfNeeded() {
        if isPaused {
            isPaused = false
            print("Resuming discovery scanning")
            
            // Only perform immediate scan if we have no servers or it's been a while
            if discoveredServers.isEmpty || 
               (lastPollTime == nil || Date().timeIntervalSince(lastPollTime!) > 60) {
                performDiscoveryScan()
            }
        }
    }
    
    /// Handle low power mode changes
    func handleLowPowerModeChange() {
        // If entering low power mode, reduce polling frequency
        if powerMonitor.isLowPowerMode {
            reducePollingFrequency()
        } else {
            // If exiting low power mode, reset polling timer to normal frequency
            setupPollingTimer()
        }
        
        print("Adjusted discovery polling for power mode: \(powerMonitor.powerMode.description)")
    }
    
    // Clean up before deinitialization
    deinit {
        stopDiscovery()
        
        // Remove observers
        NotificationCenter.default.removeObserver(self)
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