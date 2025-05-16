import Foundation
import UIKit
import Combine

/// Monitors the device's battery state and provides power-saving recommendations
final class PowerMonitor {
    static let shared = PowerMonitor()
    
    // Published properties for observing power state
    @Published private(set) var isInBackground = false
    @Published private(set) var isLowPowerMode = false
    @Published private(set) var batteryLevel: Float = 1.0
    @Published private(set) var batteryState: UIDevice.BatteryState = .full
    
    private var cancellables = Set<AnyCancellable>()
    private let device = UIDevice.current
    
    // Network conditions
    @Published private(set) var networkType: NetworkType = .wifi
    
    enum NetworkType: String {
        case none
        case cellular
        case wifi
        case ethernet
    }
    
    private init() {
        // Enable battery monitoring
        device.isBatteryMonitoringEnabled = true
        
        // Set initial values
        isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        batteryLevel = device.batteryLevel
        batteryState = device.batteryState
        
        // Set up notifications for app state changes
        NotificationCenter.default
            .publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.isInBackground = true
                self?.publishPowerStatus("App entered background")
            }
            .store(in: &cancellables)
        
        NotificationCenter.default
            .publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.isInBackground = false
                self?.publishPowerStatus("App entered foreground")
            }
            .store(in: &cancellables)
        
        // Set up notifications for battery changes
        NotificationCenter.default
            .publisher(for: UIDevice.batteryLevelDidChangeNotification)
            .sink { [weak self] _ in
                guard let self = self else { return }
                let newLevel = device.batteryLevel
                if abs(self.batteryLevel - newLevel) > 0.05 { // Only log significant changes
                    self.batteryLevel = newLevel
                    self.publishPowerStatus("Battery level changed")
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default
            .publisher(for: UIDevice.batteryStateDidChangeNotification)
            .sink { [weak self] _ in
                self?.batteryState = device.batteryState
                self?.publishPowerStatus("Battery state changed")
            }
            .store(in: &cancellables)
        
        // Set up notifications for low power mode changes
        NotificationCenter.default
            .publisher(for: ProcessInfo.processInfo.lowPowerModeDidChangeNotification)
            .sink { [weak self] _ in
                self?.isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
                self?.publishPowerStatus("Low power mode changed")
            }
            .store(in: &cancellables)
        
        // Publish initial status
        publishPowerStatus("Initial state")
    }
    
    private func publishPowerStatus(_ trigger: String) {
        print("Power status [\(trigger)] - State: \(batteryStateString), Low Power: \(isLowPowerMode), Background: \(isInBackground)")
    }

    /// Get a descriptive string of the battery state
    private var batteryStateString: String {
        switch batteryState {
        case .charging:
            return "Charging"
        case .full:
            return "Full"
        case .unplugged:
            return "Unplugged"
        case .unknown:
            return "Unknown"
        @unknown default:
            return "Unknown"
        }
    }
    
    // MARK: - Power Management Recommendations
    
    /// Get the recommended polling interval based on current power conditions
    var suggestedPollingInterval: TimeInterval {
        if isInBackground {
            return 60.0 // Once per minute in background
        }
        
        if isLowPowerMode {
            return 30.0 // Every 30 seconds in low power mode
        }
        
        if batteryLevel <= 0.2 && batteryState == .unplugged {
            return 20.0 // Every 20 seconds when battery is low
        }
        
        return 5.0 // Every 5 seconds in normal operation
    }
    
    /// Should reduce animations and visual effects to save power
    var shouldReduceEffects: Bool {
        return isLowPowerMode || (batteryLevel <= 0.15 && batteryState == .unplugged)
    }
    
    /// Current power efficiency mode
    var powerMode: PowerEfficiencyMode {
        if isLowPowerMode {
            return .lowPower
        }
        
        if batteryLevel <= 0.2 && batteryState == .unplugged {
            return .conservative
        }
        
        if batteryState == .charging || batteryState == .full {
            return .performance
        }
        
        return .balanced
    }
    
    /// Power efficiency modes for the app
    enum PowerEfficiencyMode {
        case performance  // Maximum performance, no restrictions
        case balanced     // Balance between performance and efficiency
        case conservative // Conserve power, moderate restrictions
        case lowPower     // Save power aggressively, maximum restrictions
        
        var description: String {
            switch self {
            case .performance:
                return "Performance Mode"
            case .balanced:
                return "Balanced Mode"
            case .conservative:
                return "Power Saving Mode"
            case .lowPower:
                return "Low Power Mode"
            }
        }
    }
    
    /// Should the app fetch data in the background
    var shouldAllowBackgroundNetworking: Bool {
        // Only allow background networking if plugged in or not in low power mode
        return batteryState == .charging || batteryState == .full || !isLowPowerMode
    }
    
    /// Get the recommended image quality based on power state
    var recommendedImageQuality: CGFloat {
        switch powerMode {
        case .performance:
            return 0.9 // Highest quality
        case .balanced:
            return 0.7 // Good quality
        case .conservative:
            return 0.5 // Reduced quality
        case .lowPower:
            return 0.3 // Lowest quality
        }
    }
    
    /// Returns true if we should use power-intensive features
    func shouldUsePowerIntensiveFeature(_ feature: String) -> Bool {
        switch powerMode {
        case .performance:
            return true // Allow all features
        case .balanced:
            // Check feature by name
            switch feature {
            case "streaming":
                return true
            case "animations":
                return true
            case "background_refresh":
                return true
            default:
                return true
            }
        case .conservative:
            // Be more selective
            switch feature {
            case "streaming":
                return true
            case "animations":
                return false
            case "background_refresh":
                return false
            default:
                return false
            }
        case .lowPower:
            // Disable most power-intensive features
            switch feature {
            case "streaming":
                return false // Use regular API instead
            case "animations":
                return false
            case "background_refresh":
                return false
            default:
                return false
            }
        }
    }
    
    /// Get a QoS class appropriate for current power state
    var appropriateQoSClass: DispatchQoS.QoSClass {
        switch powerMode {
        case .performance:
            return .userInitiated
        case .balanced:
            return .default
        case .conservative, .lowPower:
            return .utility
        }
    }
    
    deinit {
        device.isBatteryMonitoringEnabled = false
    }
}