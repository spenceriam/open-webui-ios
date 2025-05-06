import SwiftUI

struct OnboardingFlowView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentStep = 0
    @State private var selectedProvider: AppState.AIProvider = .none
    @State private var serverUrl = "http://localhost:11434"
    @State private var apiKey = ""
    @State private var isShowingServerDiscovery = false
    @State private var isVerifyingKey = false
    @State private var verificationMessage: (String, Bool)? = nil
    
    var body: some View {
        VStack {
            // Progress indicators
            HStack(spacing: 8) {
                ForEach(0..<3) { step in
                    Circle()
                        .fill(step == currentStep ? Color.accentColor : Color.gray.opacity(0.3))
                        .frame(width: 10, height: 10)
                }
            }
            .padding(.top, 20)
            
            // Skip button
            HStack {
                Spacer()
                Button("Skip") {
                    completeOnboarding()
                }
                .padding()
            }
            
            // Content for current step
            VStack(spacing: 30) {
                switch currentStep {
                case 0:
                    providerSelectionView
                case 1:
                    configurationView
                case 2:
                    permissionsView
                default:
                    EmptyView()
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Navigation buttons
            HStack {
                if currentStep > 0 {
                    Button("Back") {
                        withAnimation {
                            currentStep -= 1
                        }
                    }
                    .padding()
                    .buttonStyle(.bordered)
                }
                
                Spacer()
                
                Button(currentStep == 2 ? "Finish" : "Next") {
                    withAnimation {
                        if currentStep < 2 {
                            currentStep += 1
                        } else {
                            completeOnboarding()
                        }
                    }
                }
                .padding()
                .buttonStyle(.borderedProminent)
                .disabled(currentStep == 0 && selectedProvider == .none)
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .sheet(isPresented: $isShowingServerDiscovery) {
            ServerDiscoveryView(serverUrl: $serverUrl)
        }
    }
    
    // MARK: - Step 1: Provider Selection
    
    private var providerSelectionView: some View {
        VStack(spacing: 30) {
            Image(systemName: "bubble.left.and.text.bubble.right.fill")
                .font(.system(size: 70))
                .foregroundColor(.accentColor)
            
            Text("Welcome to Open WebUI")
                .font(.largeTitle)
                .bold()
            
            Text("Choose a provider to get started")
                .font(.title3)
                .foregroundColor(.secondary)
            
            VStack(spacing: 20) {
                ForEach(AppState.AIProvider.allCases.filter { $0 != .none }, id: \.self) { provider in
                    Button(action: {
                        selectedProvider = provider
                    }) {
                        HStack {
                            Image(systemName: providerIcon(for: provider))
                                .font(.title2)
                                .frame(width: 40, height: 40)
                                .background(providerColor(for: provider).opacity(0.1))
                                .clipShape(Circle())
                            
                            VStack(alignment: .leading) {
                                Text(provider.rawValue)
                                    .font(.headline)
                                
                                Text(providerDescription(for: provider))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if selectedProvider == provider {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedProvider == provider ? 
                                      Color.accentColor.opacity(0.1) : 
                                      Color.secondary.opacity(0.05))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedProvider == provider ? 
                                        Color.accentColor : Color.clear,
                                        lineWidth: 2)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
    
    // MARK: - Step 2: Configuration
    
    private var configurationView: some View {
        VStack(spacing: 20) {
            Image(systemName: providerIcon(for: selectedProvider))
                .font(.system(size: 60))
                .foregroundColor(providerColor(for: selectedProvider))
                .padding()
                .background(providerColor(for: selectedProvider).opacity(0.1))
                .clipShape(Circle())
            
            Text("Configure \(selectedProvider.rawValue)")
                .font(.title)
                .bold()
            
            Text("Set up your connection to \(selectedProvider.rawValue)")
                .font(.headline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            // Configuration form
            Group {
                switch selectedProvider {
                case .ollama:
                    ollamaConfigView
                case .openAI, .openRouter:
                    apiKeyConfigView
                default:
                    Text("Please select a provider first")
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(16)
        }
    }
    
    private var ollamaConfigView: some View {
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
            
            Text("The URL where your Ollama server is running.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("Example: http://192.168.1.10:11434")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("""
            Not running Ollama yet? Download it from:
            https://ollama.com
            """)
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.top, 10)
        }
    }
    
    private var apiKeyConfigView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("API Key")
                .font(.headline)
            
            SecureField("Enter API Key", text: $apiKey)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .disableAutocorrection(true)
            
            if let message = verificationMessage {
                HStack {
                    Image(systemName: message.1 ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .foregroundColor(message.1 ? .green : .red)
                    Text(message.0)
                        .font(.caption)
                        .foregroundColor(message.1 ? .green : .red)
                }
            }
            
            Button(action: {
                validateApiKey()
            }) {
                HStack {
                    if isVerifyingKey {
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
            .disabled(apiKey.isEmpty || isVerifyingKey)
            
            Divider()
                .padding(.vertical, 8)
            
            Text("How to get your API key:")
                .font(.caption)
                .fontWeight(.semibold)
            
            if selectedProvider == .openAI {
                Link("Get an OpenAI API key", destination: URL(string: "https://platform.openai.com/api-keys")!)
                    .font(.caption)
            } else if selectedProvider == .openRouter {
                Link("Get an OpenRouter API key", destination: URL(string: "https://openrouter.ai/keys")!)
                    .font(.caption)
            }
            
            Text("Your API key is stored securely in the device keychain.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 8)
        }
    }
    
    // MARK: - Step 3: Permissions
    
    private var permissionsView: some View {
        VStack(spacing: 30) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("Review Permissions")
                .font(.title)
                .bold()
            
            Text("Open WebUI needs the following permissions to function properly")
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            VStack(spacing: 20) {
                permissionCard(
                    icon: "network",
                    title: "Network Access",
                    description: "Required to connect to AI providers and local Ollama servers"
                )
                
                if selectedProvider == .ollama {
                    permissionCard(
                        icon: "wifi",
                        title: "Local Network",
                        description: "Required to discover Ollama servers on your local network"
                    )
                }
                
                permissionCard(
                    icon: "lock.shield",
                    title: "Keychain Access",
                    description: "Required to securely store your API keys"
                )
            }
            
            Text("You'll be prompted for these permissions when you first use the related features.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top)
        }
    }
    
    private func permissionCard(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Helper Methods
    
    private func providerIcon(for provider: AppState.AIProvider) -> String {
        switch provider {
        case .ollama: return "server.rack"
        case .openAI: return "brain"
        case .openRouter: return "network"
        case .none: return "questionmark.circle"
        }
    }
    
    private func providerColor(for provider: AppState.AIProvider) -> Color {
        switch provider {
        case .ollama: return .green
        case .openAI: return .blue
        case .openRouter: return .purple
        case .none: return .gray
        }
    }
    
    private func providerDescription(for provider: AppState.AIProvider) -> String {
        switch provider {
        case .ollama: return "Local LLM running on your network"
        case .openAI: return "Cloud-based AI services from OpenAI"
        case .openRouter: return "Access to multiple AI models"
        case .none: return ""
        }
    }
    
    private func validateApiKey() {
        isVerifyingKey = true
        verificationMessage = nil
        
        // Simulate API key validation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isVerifyingKey = false
            
            if apiKey.count < 10 {
                verificationMessage = ("API key is too short or invalid", false)
            } else {
                verificationMessage = ("API key is valid", true)
                
                // Save the API key
                saveApiKey()
            }
        }
    }
    
    private func saveApiKey() {
        let keychainService = KeychainService()
        
        do {
            let keyIdentifier = selectedProvider == .openAI ? "openai_api_key" : "openrouter_api_key"
            try keychainService.set(apiKey, for: keyIdentifier)
        } catch {
            verificationMessage = ("Failed to save API key: \(error.localizedDescription)", false)
        }
    }
    
    private func saveOllamaConfig() {
        let defaults = UserDefaults.standard
        defaults.set(serverUrl, forKey: "ollama_server_url")
    }
    
    private func completeOnboarding() {
        // Save configuration based on selected provider
        if selectedProvider == .ollama {
            saveOllamaConfig()
        }
        
        // Update app state
        appState.selectedProvider = selectedProvider
        appState.isAuthenticated = true
        
        // Mark onboarding as completed
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: "onboarding_completed")
        
        // Save preferences
        appState.savePreferences()
    }
}

struct OnboardingFlowView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingFlowView()
            .environmentObject(AppState())
    }
}