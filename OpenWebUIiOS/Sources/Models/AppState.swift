import SwiftUI
import Combine

class AppState: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var colorScheme: ColorScheme = .dark
    @Published var selectedProvider: AIProvider = .none
    @Published var textSize: TextSize = .medium
    @Published var chatBackgroundColor: Color = Color.gray.opacity(0.1)
    @Published var isInitialized: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Load saved preferences
        loadPreferences()
    }
    
    enum AIProvider: String, CaseIterable, Identifiable {
        case none = "None"
        case ollama = "Ollama"
        case openAI = "OpenAI"
        case openRouter = "OpenRouter"
        
        var id: String { self.rawValue }
    }
    
    enum TextSize: String, CaseIterable {
        case small = "Small"
        case medium = "Medium"
        case large = "Large"
        
        var fontScale: CGFloat {
            switch self {
            case .small: return 0.9
            case .medium: return 1.0
            case .large: return 1.2
            }
        }
    }
    
    func toggleColorScheme() {
        colorScheme = colorScheme == .dark ? .light : .dark
        savePreferences()
    }
    
    private func loadPreferences() {
        let defaults = UserDefaults.standard
        
        // Color scheme
        if let savedScheme = defaults.string(forKey: "colorScheme") {
            colorScheme = savedScheme == "dark" ? .dark : .light
        } else {
            // Default to system setting
            colorScheme = UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .light
        }
        
        // Text size
        if let savedSize = defaults.string(forKey: "textSize") {
            if let size = TextSize(rawValue: savedSize) {
                textSize = size
            }
        }
        
        // Chat background color
        if let colorData = defaults.data(forKey: "chatBackgroundColor") {
            do {
                let decoder = JSONDecoder()
                let colorComponents = try decoder.decode([CGFloat].self, from: colorData)
                if colorComponents.count == 4 {
                    let uiColor = UIColor(
                        red: colorComponents[0],
                        green: colorComponents[1],
                        blue: colorComponents[2],
                        alpha: colorComponents[3]
                    )
                    chatBackgroundColor = Color(uiColor)
                }
            } catch {
                print("Failed to decode color: \(error)")
            }
        }
        
        // Selected provider
        if let savedProvider = defaults.string(forKey: "selectedProvider") {
            if let provider = AIProvider(rawValue: savedProvider) {
                selectedProvider = provider
            }
        }
        
        // Authentication state
        isAuthenticated = defaults.bool(forKey: "isAuthenticated")
        
        isInitialized = true
    }
    
    func savePreferences() {
        let defaults = UserDefaults.standard
        
        // Color scheme
        defaults.set(colorScheme == .dark ? "dark" : "light", forKey: "colorScheme")
        
        // Text size
        defaults.set(textSize.rawValue, forKey: "textSize")
        
        // Try to save chat background color
        do {
            var r: CGFloat = 0
            var g: CGFloat = 0
            var b: CGFloat = 0
            var a: CGFloat = 0
            
            UIColor(chatBackgroundColor).getRed(&r, green: &g, blue: &b, alpha: &a)
            let colorComponents = [r, g, b, a]
            
            let encoder = JSONEncoder()
            let colorData = try encoder.encode(colorComponents)
            defaults.set(colorData, forKey: "chatBackgroundColor")
        } catch {
            print("Failed to encode color: \(error)")
        }
        
        // Selected provider
        defaults.set(selectedProvider.rawValue, forKey: "selectedProvider")
        
        // Authentication state
        defaults.set(isAuthenticated, forKey: "isAuthenticated")
    }
    
    func setProvider(_ provider: AIProvider) {
        selectedProvider = provider
        isAuthenticated = true
        savePreferences()
    }
    
    func signOut() {
        isAuthenticated = false
        savePreferences()
    }
    
    func updateTextSize(_ size: TextSize) {
        textSize = size
        savePreferences()
    }
    
    func updateChatBackgroundColor(_ color: Color) {
        chatBackgroundColor = color
        savePreferences()
    }
}