import SwiftUI
import UserNotifications

@main
struct OpenWebUIApp: App {
    @StateObject private var appState = AppState()
    @State private var onboardingCompleted: Bool = false
    @Environment(\.scenePhase) private var scenePhase
    
    // Memory management
    private let memoryMonitor = MemoryMonitor.shared
    
    init() {
        // Register for notifications early
        setupNotifications()
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if !onboardingCompleted && !isOnboardingCompletedInUserDefaults() {
                    OnboardingFlowView()
                        .environmentObject(appState)
                        .onDisappear {
                            onboardingCompleted = true
                        }
                } else {
                    DeviceAwareView()
                        .environmentObject(appState)
                }
            }
            .preferredColorScheme(appState.colorScheme)
            .onAppear {
                onboardingCompleted = isOnboardingCompletedInUserDefaults()
            }
            .onChange(of: scenePhase) { newPhase in
                handleScenePhaseChange(newPhase)
            }
        }
    }
    
    private func setupNotifications() {
        // Request authorization for user notifications
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("Notification permissions granted")
            } else if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
        
        // Make sure the background task service has permissions too
        BackgroundTaskService.shared.requestNotificationPermission()
        
        print("App initialized with memory usage: \(memoryMonitor.formattedMemoryUsage())")
    }
    
    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            print("App became active - Memory usage: \(memoryMonitor.formattedMemoryUsage())")
            // Resume normal operations and check for interrupted messages
            NotificationCenter.default.post(
                name: UIApplication.willEnterForegroundNotification,
                object: nil
            )
            
        case .inactive:
            print("App became inactive - Memory usage: \(memoryMonitor.formattedMemoryUsage())")
            // Prepare for possible background
            
        case .background:
            print("App entered background - Memory usage: \(memoryMonitor.formattedMemoryUsage())")
            // Notify about background state for message handling
            NotificationCenter.default.post(
                name: UIApplication.didEnterBackgroundNotification,
                object: nil
            )
            
            // Optimize memory usage
            optimizeForBackground()
            
            // Schedule background tasks for message processing if needed
            BackgroundTaskService.shared.scheduleBackgroundProcessing()
            BackgroundTaskService.shared.scheduleBackgroundFetch()
            
        @unknown default:
            break
        }
    }
    
    private func optimizeForBackground() {
        // Clear memory caches
        ImageCache.shared.clearMemoryCache()
        
        // Post notification for view models to reduce memory
        NotificationCenter.default.post(
            name: NSNotification.Name("ReduceMemoryPressure"),
            object: nil
        )
    }
    
    private func isOnboardingCompletedInUserDefaults() -> Bool {
        return UserDefaults.standard.bool(forKey: "onboarding_completed")
    }
}

/// Unified device-aware view that handles both device type and orientation
struct DeviceAwareView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var orientation = UIDevice.current.orientation
    
    var body: some View {
        Group {
            if UIDevice.current.userInterfaceIdiom == .pad {
                // iPad layout is always using the persistent sidebar approach
                ContentView_iPad()
            } else {
                // For iPhone, select layout based on device characteristics
                if isCompactDevice || dynamicTypeSize >= .accessibility1 {
                    // For small screens (iPhone SE) or large accessibility sizes
                    ContentView_Compact()
                } else if orientation.isLandscape {
                    // For regular iPhones in landscape
                    ContentView_Landscape()
                } else {
                    // For regular iPhones in portrait
                    ContentView()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            orientation = UIDevice.current.orientation
        }
    }
    
    // Helper to detect smaller iPhone models (SE, mini, etc.)
    private var isCompactDevice: Bool {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        let minDimension = min(screenWidth, screenHeight)
        
        // Detect iPhone SE and other small screen devices
        return minDimension <= 375 && UIDevice.current.userInterfaceIdiom == .phone
    }
}

