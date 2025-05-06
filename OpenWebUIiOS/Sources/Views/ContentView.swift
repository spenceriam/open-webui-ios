import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var chatViewModel = ChatViewModel()
    
    var body: some View {
        NavigationSplitView {
            // Sidebar content
            SidebarView(chatViewModel: chatViewModel)
                .navigationTitle("Open WebUI")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            appState.toggleColorScheme()
                        }) {
                            Image(systemName: appState.colorScheme == .dark ? "sun.max" : "moon")
                        }
                    }
                }
        } detail: {
            // Main content
            if appState.isAuthenticated {
                ChatView()
                    .environmentObject(chatViewModel)
            } else {
                WelcomeView()
            }
        }
    }
}

struct SidebarView: View {
    @ObservedObject var chatViewModel: ChatViewModel
    @EnvironmentObject var appState: AppState
    @State private var selectedSection: SidebarSection = .conversations
    
    enum SidebarSection: String, CaseIterable, Identifiable {
        case conversations = "Conversations"
        case providers = "Providers"
        case settings = "Settings"
        
        var id: String { self.rawValue }
        
        var icon: String {
            switch self {
            case .conversations: return "bubble.left.and.bubble.right"
            case .providers: return "network"
            case .settings: return "gear"
            }
        }
    }
    
    var body: some View {
        VStack {
            // Section tabs
            HStack {
                ForEach(SidebarSection.allCases) { section in
                    Button(action: {
                        selectedSection = section
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: section.icon)
                                .font(.system(size: 20))
                            
                            Text(section.rawValue)
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selectedSection == section ? Color.accentColor.opacity(0.1) : Color.clear)
                        .foregroundColor(selectedSection == section ? .primary : .secondary)
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            // Content based on selected section
            switch selectedSection {
            case .conversations:
                VStack {
                    NavigationLink(destination: ConversationListView()) {
                        Label("Manage All Conversations", systemImage: "folder")
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    
                    MessageListView(viewModel: chatViewModel)
                }
            case .providers:
                providerSection
            case .settings:
                settingsSection
            }
        }
    }
    
    // Provider section
    private var providerSection: some View {
        List {
            ForEach(AppState.AIProvider.allCases) { provider in
                NavigationLink(
                    destination: ProviderDetailView(provider: provider),
                    label: {
                        Label(
                            provider.rawValue,
                            systemImage: providerIcon(for: provider)
                        )
                    }
                )
            }
        }
        .listStyle(InsetGroupedListStyle())
    }
    
    // Settings section
    private var settingsSection: some View {
        List {
            Section(header: Text("Appearance")) {
                HStack {
                    Text("Theme")
                    Spacer()
                    Button(action: {
                        appState.toggleColorScheme()
                    }) {
                        HStack {
                            Text(appState.colorScheme == .dark ? "Dark" : "Light")
                                .foregroundColor(.secondary)
                            Image(systemName: appState.colorScheme == .dark ? "moon.fill" : "sun.max.fill")
                                .foregroundColor(appState.colorScheme == .dark ? .purple : .orange)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                NavigationLink(destination: SettingsView()) {
                    Label("All Settings", systemImage: "gear")
                }
            }
            
            Section(header: Text("API Keys")) {
                NavigationLink(destination: APIKeyManagementView()) {
                    Label("Manage API Keys", systemImage: "key.fill")
                }
            }
            
            Section(header: Text("Conversations")) {
                NavigationLink(destination: ConversationListView()) {
                    Label("Manage Conversations", systemImage: "folder")
                }
                
                NavigationLink(destination: ImportExportView()) {
                    Label("Import/Export", systemImage: "square.and.arrow.up.on.square")
                }
            }
            
            Section(header: Text("About")) {
                NavigationLink(destination: AboutView()) {
                    Label("About", systemImage: "info.circle")
                }
                
                NavigationLink(destination: HelpSupportView()) {
                    Label("Help & Support", systemImage: "questionmark.circle")
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
    }
    
    private func providerIcon(for provider: AppState.AIProvider) -> String {
        switch provider {
        case .ollama:
            return "server.rack"
        case .openAI:
            return "brain"
        case .openRouter:
            return "network"
        case .none:
            return "questionmark.circle"
        }
    }
}

struct WelcomeView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "bubble.left.and.text.bubble.right")
                .font(.system(size: 80))
                .foregroundColor(.accentColor)
            
            Text("Welcome to Open WebUI")
                .font(.largeTitle)
                .bold()
            
            Text("Choose a provider to get started")
                .font(.title3)
                .foregroundColor(.secondary)
            
            HStack(spacing: 20) {
                ProviderButton(
                    title: "Ollama",
                    subtitle: "Local LLM",
                    icon: "server.rack",
                    action: { 
                        appState.selectedProvider = .ollama
                        appState.isAuthenticated = true
                    }
                )
                
                ProviderButton(
                    title: "OpenAI",
                    subtitle: "Cloud API",
                    icon: "brain",
                    action: { 
                        appState.selectedProvider = .openAI
                        appState.isAuthenticated = true
                    }
                )
                
                ProviderButton(
                    title: "OpenRouter",
                    subtitle: "Multiple Models",
                    icon: "network",
                    action: { 
                        appState.selectedProvider = .openRouter
                        appState.isAuthenticated = true
                    }
                )
            }
            .padding(.top)
        }
        .padding()
    }
}

struct ProviderButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack {
                Image(systemName: icon)
                    .font(.system(size: 30))
                    .padding()
                    .background(Color.accentColor.opacity(0.1))
                    .clipShape(Circle())
                
                Text(title)
                    .font(.headline)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: 120, height: 150)
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ProviderDetailView: View {
    let provider: AppState.AIProvider
    @EnvironmentObject var appState: AppState
    @StateObject private var ollamaService = OllamaService()
    @State private var serverUrl = "http://localhost:11434"
    @State private var apiKey = ""
    @State private var isShowingServerDiscovery = false
    @State private var isValidatingKey = false
    @State private var validationMessage: (String, Bool)? = nil
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: providerIcon)
                    .font(.system(size: 60))
                    .foregroundColor(providerColor)
                    .padding()
                    .background(providerColor.opacity(0.1))
                    .clipShape(Circle())
                
                Text("Configure \(provider.rawValue)")
                    .font(.largeTitle)
                    .bold()
                
                Text("Set up your connection to \(provider.rawValue)")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Spacer()
                    .frame(height: 30)
                
                // Configuration form
                providerConfigForm
                
                // Status indicator (for Ollama)
                if provider == .ollama {
                    ollamaStatusView
                        .padding(.top)
                }
                
                Spacer()
            }
            .padding()
            .onAppear {
                if provider == .ollama {
                    ollamaService.checkServerStatus()
                }
            }
            .sheet(isPresented: $isShowingServerDiscovery) {
                ServerDiscoveryView(serverUrl: $serverUrl)
            }
        }
    }
    
    private var providerConfigForm: some View {
        Group {
            switch provider {
            case .ollama:
                VStack(alignment: .leading, spacing: 16) {
                    Text("Ollama Server")
                        .font(.headline)
                    
                    HStack {
                        TextField("Server URL", text: $serverUrl)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        Button(action: {
                            isShowingServerDiscovery = true
                        }) {
                            Image(systemName: "network")
                                .foregroundColor(.accentColor)
                        }
                    }
                    
                    HStack(spacing: 16) {
                        Button(action: {
                            ollamaService.checkServerStatus()
                        }) {
                            Text("Test Connection")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        
                        Button(action: {
                            saveOllamaConfig()
                        }) {
                            Text("Connect")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    Text("Available Models")
                        .font(.headline)
                    
                    Button(action: {
                        ollamaService.fetchAvailableModels()
                            .receive(on: DispatchQueue.main)
                            .sink { completion in
                                // Handle completion
                            } receiveValue: { models in
                                // Show models
                            }
                            .store(in: &ollamaService.cancellables)
                    }) {
                        Text("Refresh Models")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
            case .openAI, .openRouter:
                VStack(alignment: .leading, spacing: 16) {
                    Text("API Key")
                        .font(.headline)
                    
                    SecureField("Enter API Key", text: $apiKey)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    if let message = validationMessage {
                        Text(message.0)
                            .font(.caption)
                            .foregroundColor(message.1 ? .green : .red)
                    }
                    
                    HStack(spacing: 16) {
                        Button(action: {
                            validateApiKey()
                        }) {
                            HStack {
                                if isValidatingKey {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                } else {
                                    Text("Validate Key")
                                }
                            }
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(apiKey.isEmpty || isValidatingKey)
                        
                        Button(action: {
                            saveApiKey()
                        }) {
                            Text("Save API Key")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(apiKey.isEmpty)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
            case .none:
                Text("Select a provider to configure")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var ollamaStatusView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Server Status:")
                    .font(.headline)
                
                switch ollamaService.serverStatus {
                case .unknown:
                    HStack {
                        Text("Checking")
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                    .foregroundColor(.secondary)
                case .connected:
                    HStack {
                        Text("Connected")
                        Image(systemName: "checkmark.circle.fill")
                    }
                    .foregroundColor(.green)
                case .disconnected:
                    HStack {
                        Text("Disconnected")
                        Image(systemName: "exclamationmark.circle.fill")
                    }
                    .foregroundColor(.red)
                case .error(let message):
                    HStack {
                        Text("Error: \(message)")
                        Image(systemName: "exclamationmark.triangle.fill")
                    }
                    .foregroundColor(.orange)
                }
                
                Spacer()
                
                Button(action: {
                    ollamaService.checkServerStatus()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
            }
            
            if case .disconnected = ollamaService.serverStatus {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tips to fix connection issues:")
                        .font(.caption)
                        .fontWeight(.semibold)
                    
                    Text("• Make sure Ollama is running on your computer")
                        .font(.caption)
                    
                    Text("• Check if the server URL is correct")
                        .font(.caption)
                    
                    Text("• Verify your network connection")
                        .font(.caption)
                    
                    Text("• Check firewall settings")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var providerIcon: String {
        switch provider {
        case .ollama: return "server.rack"
        case .openAI: return "brain"
        case .openRouter: return "network"
        case .none: return "questionmark.circle"
        }
    }
    
    private var providerColor: Color {
        switch provider {
        case .ollama: return .green
        case .openAI: return .blue
        case .openRouter: return .purple
        case .none: return .gray
        }
    }
    
    // MARK: - Actions
    
    private func saveOllamaConfig() {
        ollamaService.setServerURL(serverUrl)
        
        // Update app state to use Ollama provider
        appState.selectedProvider = .ollama
        appState.isAuthenticated = true
        
        // Show a success message
        validationMessage = ("Successfully connected to Ollama server", true)
    }
    
    private func validateApiKey() {
        isValidatingKey = true
        validationMessage = nil
        
        // Simulate API key validation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isValidatingKey = false
            
            if apiKey.count < 10 {
                validationMessage = ("API key is too short or invalid", false)
            } else {
                validationMessage = ("API key is valid", true)
            }
        }
    }
    
    private func saveApiKey() {
        // Save API key to secure storage
        let keychainService = KeychainService()
        
        do {
            let keyIdentifier = provider == .openAI ? "openai_api_key" : "openrouter_api_key"
            try keychainService.set(apiKey, for: keyIdentifier)
            
            // Update app state
            appState.selectedProvider = provider
            appState.isAuthenticated = true
            
            // Show success message
            validationMessage = ("API key saved successfully", true)
        } catch {
            validationMessage = ("Failed to save API key: \(error.localizedDescription)", false)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}