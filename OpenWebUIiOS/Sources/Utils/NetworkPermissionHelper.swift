import Foundation
import Network

/// A helper class to manage network permissions and connection monitoring
class NetworkPermissionHelper: ObservableObject {
    @Published var localNetworkPermissionStatus: PermissionStatus = .unknown
    @Published var internetConnectionStatus: ConnectionStatus = .unknown
    
    private var pathMonitor: NWPathMonitor?
    private var localNetworkMonitor: NWPathMonitor?
    
    enum PermissionStatus {
        case unknown
        case granted
        case denied
    }
    
    enum ConnectionStatus {
        case unknown
        case connected
        case disconnected
    }
    
    init() {
        setupInternetMonitoring()
    }
    
    /// Start monitoring internet connection
    func setupInternetMonitoring() {
        pathMonitor = NWPathMonitor()
        let queue = DispatchQueue(label: "InternetMonitor")
        
        pathMonitor?.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                if path.status == .satisfied {
                    self?.internetConnectionStatus = .connected
                } else {
                    self?.internetConnectionStatus = .disconnected
                }
            }
        }
        
        pathMonitor?.start(queue: queue)
    }
    
    /// This function initiates a local network discovery which will trigger the system permission dialog
    /// if the permission hasn't been granted yet
    func requestLocalNetworkPermission() {
        localNetworkMonitor = NWPathMonitor(requiringInterfaceType: .wifi)
        let queue = DispatchQueue(label: "LocalNetworkPermissionMonitor")
        
        // This browser will trigger the local network permission dialog
        let browser = NWBrowser(for: .bonjour(type: "_http._tcp", domain: nil), using: NWParameters())
        
        browser.stateUpdateHandler = { [weak self] state in
            if state == .ready || state == .failed {
                // We don't need to keep the browser running after the permission dialog is shown
                browser.cancel()
                
                // Update permission status based on monitor results
                DispatchQueue.main.async {
                    if self?.localNetworkMonitor?.currentPath.status == .satisfied {
                        self?.localNetworkPermissionStatus = .granted
                    } else {
                        self?.localNetworkPermissionStatus = .denied
                    }
                }
            }
        }
        
        localNetworkMonitor?.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                if path.status == .satisfied {
                    self?.localNetworkPermissionStatus = .granted
                } else {
                    self?.localNetworkPermissionStatus = .denied
                }
            }
        }
        
        // Start the browser to trigger permission dialog
        browser.start(queue: queue)
        localNetworkMonitor?.start(queue: queue)
    }
    
    /// Check if we are connected to WiFi
    var isConnectedToWiFi: Bool {
        pathMonitor?.currentPath.usesInterfaceType(.wifi) ?? false
    }
    
    /// Determine if we should show network connection warnings
    var shouldShowNetworkWarning: Bool {
        internetConnectionStatus == .disconnected || 
        (localNetworkPermissionStatus == .denied && isConnectedToWiFi)
    }
    
    deinit {
        pathMonitor?.cancel()
        localNetworkMonitor?.cancel()
    }
}