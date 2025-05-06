import SwiftUI

@main
struct OpenWebUIApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .preferredColorScheme(appState.colorScheme)
        }
    }
}

/// Main application state object
class AppState: ObservableObject {
    @Published var colorScheme: ColorScheme? = nil
    @Published var isAuthenticated: Bool = false
    @Published var selectedProvider: AIProvider = .none
    
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