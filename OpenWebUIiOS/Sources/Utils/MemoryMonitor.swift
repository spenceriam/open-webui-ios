import Foundation
import UIKit
import Combine

/// Monitors app memory usage and system memory pressure
final class MemoryMonitor {
    static let shared = MemoryMonitor()
    
    // Published properties for observing memory state
    @Published private(set) var currentMemoryUsageMB: Double = 0
    @Published private(set) var memoryWarningReceived: Bool = false
    @Published private(set) var memoryWarningCount: Int = 0
    @Published private(set) var isMemoryUsageHigh: Bool = false
    
    // Memory thresholds
    private let highMemoryThresholdMB: Double = 150 // Consider above 150MB as high
    private let criticalMemoryThresholdMB: Double = 180 // Above 180MB is critical
    
    // Monitoring timer
    private var monitorTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Register for memory warning notifications
        NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)
            .sink { [weak self] _ in
                self?.handleMemoryWarning()
            }
            .store(in: &cancellables)
        
        // Start periodic monitoring
        startMonitoring()
    }
    
    /// Start periodic memory monitoring
    private func startMonitoring() {
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.updateMemoryUsage()
        }
        // Initial reading
        updateMemoryUsage()
    }
    
    /// Update current memory usage reading
    private func updateMemoryUsage() {
        let bytes = Double(memoryFootprint())
        let megabytes = bytes / 1024 / 1024
        
        currentMemoryUsageMB = megabytes
        isMemoryUsageHigh = megabytes > highMemoryThresholdMB
        
        // Take action if memory usage is critical
        if megabytes > criticalMemoryThresholdMB {
            reduceMemoryPressure()
        }
    }
    
    /// Handle memory warning from the system
    @objc private func handleMemoryWarning() {
        memoryWarningReceived = true
        memoryWarningCount += 1
        
        // Clear caches immediately
        ImageCache.shared.clearMemoryCache()
        URLCache.shared.removeAllCachedResponses()
        
        print("Memory warning received")
        // Perform additional memory reduction
        reduceMemoryPressure()
        
        // Reset warning flag after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            self?.memoryWarningReceived = false
        }
    }
    
    /// Take action to reduce memory pressure
    private func reduceMemoryPressure() {
        // Post notification for app components to reduce memory
        NotificationCenter.default.post(
            name: NSNotification.Name("ReduceMemoryPressure"),
            object: nil
        )
    }
    
    /// Get the app's current memory footprint in bytes
    private func memoryFootprint() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                          task_flavor_t(MACH_TASK_BASIC_INFO),
                          $0,
                          &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return info.resident_size
        } else {
            return 0
        }
    }
    
    /// Format current memory usage to readable string
    func formattedMemoryUsage() -> String {
        return String(format: "%.1f MB", currentMemoryUsageMB)
    }
    
    /// Stop memory monitoring
    func stopMonitoring() {
        monitorTimer?.invalidate()
        monitorTimer = nil
    }
    
    deinit {
        stopMonitoring()
    }
}

// Extension to add memory status context
extension MemoryMonitor {
    // Severity level of memory status
    enum MemorySeverity {
        case normal
        case elevated
        case high
        case critical
    }
    
    // Current memory severity
    var memorySeverity: MemorySeverity {
        switch currentMemoryUsageMB {
        case 0..<100:
            return .normal
        case 100..<highMemoryThresholdMB:
            return .elevated
        case highMemoryThresholdMB..<criticalMemoryThresholdMB:
            return .high
        default:
            return .critical
        }
    }
    
    // Get recommended action based on memory status
    var recommendedAction: String {
        switch memorySeverity {
        case .normal, .elevated:
            return "No action needed"
        case .high:
            return "Consider clearing unused resources"
        case .critical:
            return "Clear caches and reduce memory usage immediately"
        }
    }
}