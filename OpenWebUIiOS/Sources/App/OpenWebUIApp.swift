import SwiftUI

@main
struct OpenWebUIApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            DeviceAwareView()
                .environmentObject(appState)
                .preferredColorScheme(appState.colorScheme)
        }
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

/// Main application state object
class AppState: ObservableObject {
    @Published var colorScheme: ColorScheme? = nil
    @Published var isAuthenticated: Bool = false
    @Published var selectedProvider: AIProvider = .none
    @Published var deviceOrientation: UIDeviceOrientation = UIDevice.current.orientation
    
    /// Available AI providers
    enum AIProvider: String, CaseIterable, Identifiable {
        case none = "None"
        case ollama = "Ollama"
        case openAI = "OpenAI"
        case openRouter = "OpenRouter"
        
        var id: String { self.rawValue }
    }
    
    // Toggle between light and dark mode
    func toggleColorScheme() {
        switch colorScheme {
        case .light:
            colorScheme = .dark
        case .dark:
            colorScheme = .light
        case .none:
            colorScheme = .dark
        @unknown default:
            colorScheme = .dark
        }
    }
    
    // Set the color scheme explicitly
    func setColorScheme(_ scheme: ColorScheme?) {
        colorScheme = scheme
    }
}