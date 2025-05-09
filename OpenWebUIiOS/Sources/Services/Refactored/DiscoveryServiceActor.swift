import Foundation
import Network
import OSLog

/// Actor-based implementation of the DiscoveryService for finding Ollama servers on the network
/// - Uses AsyncStream instead of Combine
/// - Thread-safe through actor isolation
/// - Structured concurrency with better cancellation support
actor DiscoveryServiceActor: DiscoveryServiceProtocol {
    // MARK: - Properties
    
    @MainActor private(set) var isScanning: Bool = false
    @MainActor private(set) var error: Error?
    
    private var discoveredServers: [OllamaServiceActor.DiscoveredOllamaServer] = []
    private let logger = Logger(subsystem: "com.openwebui.ios", category: "DiscoveryService")
    private var browser: NWBrowser?
    private var scanTask: Task<Void, Never>?
    private var pollingTask: Task<Void, Never>?
    private var lastPollTime: Date?
    
    // Battery optimization
    private let powerMonitor: PowerMonitorProtocol
    
    // Adaptive polling settings
    private var userInitiatedScan = false
    private var isPaused = false
    
    // Stream continuation for sending server updates
    private var serverStreamContinuations: [UUID: AsyncStream<[OllamaServiceActor.DiscoveredOllamaServer]>.Continuation] = [:]
    
    // MARK: - Initialization
    
    init(powerMonitor: PowerMonitorProtocol = PowerMonitor.shared) {
        self.powerMonitor = powerMonitor
        
        // Set up app lifecycle observation
        Task { [weak self] in
            guard let self = self else { return }
            for await notification in NotificationCenter.default.notifications(named: UIApplication.didEnterBackgroundNotification) {
                await self.pauseDiscoveryIfPossible()
            }
        }
        
        Task { [weak self] in
            guard let self = self else { return }
            for await notification in NotificationCenter.default.notifications(named: UIApplication.willEnterForegroundNotification) {
                await self.resumeDiscoveryIfNeeded()
            }
        }
        
        Task { [weak self] in
            guard let self = self else { return }
            for await notification in NotificationCenter.default.notifications(named: ProcessInfo.processInfo.lowPowerModeDidChangeNotification) {
                await self.handleLowPowerModeChange()
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// Provides an AsyncStream of discovered servers
    func serverUpdates() -> AsyncStream<[OllamaServiceActor.DiscoveredOllamaServer]> {
        let id = UUID()
        
        return AsyncStream { continuation in
            // Store the continuation
            serverStreamContinuations[id] = continuation
            
            // Send initial value
            continuation.yield(discoveredServers)
            
            // Clean up when the stream is terminated
            continuation.onTermination = { @Sendable [weak self] _ in
                Task { [weak self] in
                    await self?.removeServerStreamContinuation(id: id)
                }
            }
        }
    }
    
    /// Start scanning for Ollama servers on the network
    func startDiscovery(userInitiated: Bool = false) async {
        // Set flag for user-initiated scan
        userInitiatedScan = userInitiated
        
        // Cancel any existing polling task
        pollingTask?.cancel()
        pollingTask = nil
        
        // Reset pause state
        isPaused = false
        
        // Start immediate scan
        await performDiscoveryScan()
        
        // Set up periodic polling
        await setupPollingTask()
    }
    
    /// Stop the discovery process completely
    func stopDiscovery() async {
        // Stop the browser
        browser?.cancel()
        browser = nil
        
        // Cancel scanning and polling tasks
        scanTask?.cancel()
        scanTask = nil
        
        pollingTask?.cancel()
        pollingTask = nil
        
        await MainActor.run {
            isScanning = false
        }
        isPaused = false
    }
    
    // MARK: - Private Methods
    
    /// Set up periodic polling task with adaptive interval
    private func setupPollingTask() async {
        // Cancel any existing polling task
        pollingTask?.cancel()
        
        pollingTask = Task { [weak self] in
            guard let self = self else { return }
            
            while !Task.isCancelled {
                // Sleep for the appropriate interval
                let interval = await self.powerMonitor.suggestedPollingInterval
                
                do {
                    try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                } catch {
                    // Task was cancelled
                    break
                }
                
                // Only perform scan if conditions are met
                if await !self.isPaused && self.shouldPerformPoll() {
                    await self.performDiscoveryScan(isPolling: true)
                }
            }
        }
    }
    
    /// Determine if polling should be performed based on conditions
    private func shouldPerformPoll() async -> Bool {
        // Don't poll if we're in background or in low power mode
        // unless this was a user-initiated scan
        if await powerMonitor.isInBackground && !userInitiatedScan {
            return false
        }
        
        // If in low power mode, limit polling frequency
        if await powerMonitor.isLowPowerMode && !userInitiatedScan {
            // If last poll was less than 2 minutes ago, skip
            if let lastPoll = lastPollTime,
               Date().timeIntervalSince(lastPoll) < 120 {
                return false
            }
        }
        
        return true
    }
    
    /// Perform the actual discovery scan
    private func performDiscoveryScan(isPolling: Bool = false) async {
        // Cancel any existing scan task
        scanTask?.cancel()
        
        scanTask = Task { [weak self] in
            guard let self = self else { return }
            
            // Clear previous discoveries if this isn't a polling update
            if !isPolling {
                self.discoveredServers = []
                await self.notifyServerUpdates()
            }
            
            // Mark last poll time
            self.lastPollTime = Date()
            
            // Update state
            await MainActor.run {
                self.isScanning = true
                self.error = nil
            }
            
            // Set up browser parameters for Bonjour
            let params = NWParameters()
            params.includePeerToPeer = true
            
            // Use more aggressive timeouts in low power mode
            if await self.powerMonitor.isLowPowerMode {
                params.prohibitExpensivePaths = true
                params.prohibitConstrained = true
            }
            
            // Create a task group for server validation
            let browserDescriptor = NWBrowser.Descriptor.bonjour(type: "_http._tcp", domain: nil)
            let browser = NWBrowser(for: browserDescriptor, using: params)
            self.browser = browser
            
            // Semaphore to wait for browser setup
            let semaphore = DispatchSemaphore(value: 0)
            
            // Track discovered endpoints to avoid duplicates
            var processedEndpoints = Set<String>()
            
            // Set up browser state handler
            browser.stateUpdateHandler = { newState in
                switch newState {
                case .ready:
                    self.logger.debug("Browser is ready")
                    semaphore.signal()
                case .failed(let error):
                    Task { @MainActor in
                        self.isScanning = false
                        self.error = error
                    }
                    self.logger.error("Browser failed: \(error.localizedDescription)")
                    semaphore.signal()
                case .cancelled:
                    Task { @MainActor in
                        self.isScanning = false
                    }
                    self.logger.debug("Browser was cancelled")
                    semaphore.signal()
                default:
                    break
                }
            }
            
            // Set up results handler with actor-safe approach
            browser.browseResultsChangedHandler = { results, changes in
                // Process each change
                for change in changes {
                    if Task.isCancelled { return }
                    
                    switch change {
                    case .added(let result):
                        // Skip if we're in low power mode and have enough servers
                        Task {
                            if await self.powerMonitor.isLowPowerMode &&
                                !self.userInitiatedScan &&
                                self.discoveredServers.count >= 3 {
                                // Skip validation if we already have several servers
                                return
                            }
                            
                            // Process in actor context
                            await self.processDiscoveredService(result, processedEndpoints: &processedEndpoints)
                        }
                        
                    case .removed(let result):
                        Task {
                            await self.removeService(result)
                        }
                        
                    default:
                        break
                    }
                }
            }
            
            // Start the browser
            browser.start(queue: .global(qos: .utility))
            
            // Wait for browser to be ready or fail
            _ = semaphore.wait(timeout: .now() + 5.0)
            
            // Set up a timeout if in low power mode
            if await self.powerMonitor.isLowPowerMode && !self.userInitiatedScan {
                do {
                    try await Task.sleep(nanoseconds: 15_000_000_000) // 15 seconds
                    if !Task.isCancelled {
                        await self.stopCurrentScan()
                    }
                } catch {
                    // Task was cancelled
                }
            }
        }
    }
    
    /// Process a discovered service to check if it's an Ollama server
    private func processDiscoveredService(_ result: NWBrowser.Result, processedEndpoints: inout Set<String>) async {
        // Skip if we already processed this endpoint
        let endpointKey = result.endpoint.debugDescription
        if processedEndpoints.contains(endpointKey) {
            return
        }
        
        processedEndpoints.insert(endpointKey)
        
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
            let server = OllamaServiceActor.DiscoveredOllamaServer(
                id: endpointKey,
                name: serviceName,
                hostName: hostName,
                port: Int(port.rawValue),
                available: false
            )
            
            // Verify if this is actually an Ollama server
            if await validateOllamaServer(server) {
                var validatedServer = server
                validatedServer.available = true
                
                // Add to discovered servers if not already present
                if !discoveredServers.contains(where: { $0.id == server.id }) {
                    discoveredServers.append(validatedServer)
                    await notifyServerUpdates()
                }
            }
        default:
            break
        }
    }
    
    /// Validate that the discovered service is actually an Ollama server
    private func validateOllamaServer(_ server: OllamaServiceActor.DiscoveredOllamaServer) async -> Bool {
        // Create URL for Ollama API
        let url = server.apiURL.appendingPathComponent("tags")
        
        var request = URLRequest(url: url)
        
        // Adjust timeout based on power state
        let timeout: TimeInterval
        let powerMode = await powerMonitor.powerMode
        
        switch powerMode {
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
        let isLowPowerMode = await powerMonitor.isLowPowerMode
        let batteryLevel = await powerMonitor.batteryLevel
        
        if isLowPowerMode || batteryLevel < 0.2 {
            request.cachePolicy = .returnCacheDataElseLoad
        } else {
            request.cachePolicy = .useProtocolCachePolicy
        }
        
        // Create a task with the appropriate priority
        let qos: TaskPriority = userInitiatedScan ? .userInitiated : .utility
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request, delegate: nil)
            
            // Skip validation processing if discovery was paused
            if isPaused && !userInitiatedScan {
                return false
            }
            
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                // Try to decode the response as JSON
                do {
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                    
                    // Check if the response has the expected structure of an Ollama server
                    if json?["models"] != nil {
                        return true
                    }
                } catch {
                    // Not an Ollama server or couldn't parse response
                    return false
                }
            }
            
            return false
        } catch {
            logger.debug("Failed to validate Ollama server at \(server.hostName): \(error.localizedDescription)")
            return false
        }
    }
    
    /// Remove a service from the list of discovered servers
    private func removeService(_ result: NWBrowser.Result) async {
        let endpointKey = result.endpoint.debugDescription
        
        discoveredServers.removeAll { server in
            server.id == endpointKey
        }
        
        await notifyServerUpdates()
    }
    
    /// Stop the current scan but keep polling timer active
    private func stopCurrentScan() async {
        browser?.cancel()
        browser = nil
        scanTask?.cancel()
        scanTask = nil
        
        await MainActor.run {
            isScanning = false
        }
    }
    
    /// Reduce polling frequency to save power
    private func reducePollingFrequency() async {
        // If not paused, restart polling with a longer interval
        if !isPaused && pollingTask != nil {
            await setupPollingTask()
            logger.debug("Reduced discovery polling frequency to save power")
        }
    }
    
    /// Pause discovery when app is in background
    private func pauseDiscoveryIfPossible() async {
        // If we're not actively scanning or this was user-initiated, we can pause
        if !userInitiatedScan {
            isPaused = true
            await stopCurrentScan()
            logger.debug("Paused discovery scanning to save battery")
        }
    }
    
    /// Resume discovery when app comes to foreground
    private func resumeDiscoveryIfNeeded() async {
        if isPaused {
            isPaused = false
            logger.debug("Resuming discovery scanning")
            
            // Only perform immediate scan if we have no servers or it's been a while
            if discoveredServers.isEmpty ||
                (lastPollTime == nil || Date().timeIntervalSince(lastPollTime!) > 60) {
                await performDiscoveryScan()
            }
        }
    }
    
    /// Handle low power mode changes
    private func handleLowPowerModeChange() async {
        // If entering low power mode, reduce polling frequency
        if await powerMonitor.isLowPowerMode {
            await reducePollingFrequency()
        } else {
            // If exiting low power mode, reset polling timer to normal frequency
            await setupPollingTask()
        }
        
        let powerMode = await powerMonitor.powerMode
        logger.debug("Adjusted discovery polling for power mode: \(powerMode.description)")
    }
    
    /// Notify all listeners of server updates
    private func notifyServerUpdates() async {
        for continuation in serverStreamContinuations.values {
            continuation.yield(discoveredServers)
        }
    }
    
    /// Remove a server stream continuation
    private func removeServerStreamContinuation(id: UUID) {
        serverStreamContinuations[id] = nil
    }
}

// MARK: - PowerMonitor Protocol

/// Protocol for PowerMonitor to enable testing and dependency injection
protocol PowerMonitorProtocol: AnyObject {
    var isLowPowerMode: Bool { get async }
    var isInBackground: Bool { get async }
    var batteryLevel: Double { get async }
    var suggestedPollingInterval: TimeInterval { get async }
    var powerMode: PowerMode { get async }
    var appropriateQoSClass: DispatchQoS.QoSClass { get async }
}

/// Power mode enum for adaptive power management
enum PowerMode: CustomStringConvertible {
    case performance
    case balanced
    case conservative
    case lowPower
    
    var description: String {
        switch self {
        case .performance: return "Performance"
        case .balanced: return "Balanced"
        case .conservative: return "Conservative"
        case .lowPower: return "Low Power"
        }
    }
}

// MARK: - Preview Data

extension OllamaServiceActor.DiscoveredOllamaServer {
    static var previewData: [OllamaServiceActor.DiscoveredOllamaServer] {
        [
            OllamaServiceActor.DiscoveredOllamaServer(
                id: "host:macbook-pro.local:11434",
                name: "MacBook Pro",
                hostName: "macbook-pro.local",
                port: 11434,
                available: true
            ),
            OllamaServiceActor.DiscoveredOllamaServer(
                id: "host:mac-mini.local:11434",
                name: "Mac Mini",
                hostName: "mac-mini.local",
                port: 11434,
                available: true
            ),
            OllamaServiceActor.DiscoveredOllamaServer(
                id: "host:ollama-server.local:11434",
                name: "Ollama Server",
                hostName: "ollama-server.local",
                port: 11434,
                available: false
            )
        ]
    }
}