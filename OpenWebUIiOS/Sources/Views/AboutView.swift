import SwiftUI

struct AboutView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.openURL) var openURL
    
    let appVersion = "0.1.0"
    let buildNumber = "1"
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    // App logo and title
                    VStack(spacing: 16) {
                        Image(systemName: "bubble.left.and.text.bubble.right")
                            .font(.system(size: a100))
                            .foregroundColor(.accentColor)
                        
                        Text("Open WebUI")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("for iOS")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        
                        Text("Version \(appVersion) (\(buildNumber))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    
                    // About text
                    VStack(alignment: .leading, spacing: 16) {
                        Text("About Open WebUI")
                            .font(.headline)
                        
                        Text("Open WebUI is a chat interface for interacting with multiple AI providers, including Ollama (for local models), OpenAI, and OpenRouter.")
                        
                        Text("This native iOS app brings the same functionality from the web version to your iOS device, allowing you to chat with AI models on the go.")
                    }
                    .padding(.horizontal)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Feature list
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Key Features")
                            .font(.headline)
                        
                        FeatureRow(icon: "server.rack", title: "Local LLM Support", description: "Connect to Ollama instances on your network to use local models")
                        
                        FeatureRow(icon: "network", title: "Multiple Providers", description: "Switch seamlessly between Ollama, OpenAI, and OpenRouter")
                        
                        FeatureRow(icon: "bubble.left.and.bubble.right", title: "Streaming Responses", description: "Real-time streaming responses with markdown support")
                        
                        FeatureRow(icon: "folder.fill", title: "Conversation Management", description: "Organize chats with folders and tags")
                        
                        FeatureRow(icon: "lock.fill", title: "Secure Storage", description: "API keys stored securely in the iOS keychain")
                    }
                    .padding(.horizontal)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Links
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Resources")
                            .font(.headline)
                        
                        Button(action: {
                            openURL(URL(string: "https://github.com/open-webui/open-webui")!)
                        }) {
                            HStack {
                                Image(systemName: "link")
                                Text("GitHub Repository")
                                Spacer()
                                Image(systemName: "arrow.up.right")
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: {
                            openURL(URL(string: "https://docs.openwebui.com")!)
                        }) {
                            HStack {
                                Image(systemName: "doc.text")
                                Text("Documentation")
                                Spacer()
                                Image(systemName: "arrow.up.right")
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: {
                            openURL(URL(string: "https://github.com/open-webui/open-webui/issues")!)
                        }) {
                            HStack {
                                Image(systemName: "exclamationmark.circle")
                                Text("Report an Issue")
                                Spacer()
                                Image(systemName: "arrow.up.right")
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Credits section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Credits")
                            .font(.headline)
                        
                        Text("This project is based on the Open WebUI project by open-webui, licensed under the Apache License 2.0.")
                            .font(.caption)
                        
                        Text("iOS app developed with ❤️ by the Open WebUI community.")
                            .font(.caption)
                    }
                    .padding(.horizontal)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Legal footer
                    Text("© 2025 Open WebUI. All rights reserved.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding()
                }
                .padding(.vertical)
            }
            .navigationTitle("About")
            .navigationBarItems(
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
    
    // Constant for sizing
    private var a100: CGFloat { 100 }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
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
        .padding(.vertical, 4)
    }
}

struct HelpSupportView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.openURL) var openURL
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Common Questions")) {
                    DisclosureGroup("How do I connect to Ollama?") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("1. Make sure Ollama is running on your computer")
                                .font(.subheadline)
                            
                            Text("2. Go to Settings → Ollama Configuration")
                                .font(.subheadline)
                            
                            Text("3. Enter your computer's IP address and port (default: 11434)")
                                .font(.subheadline)
                            
                            Text("4. Click 'Test Connection' to verify")
                                .font(.subheadline)
                            
                            Link("Download Ollama", destination: URL(string: "https://ollama.ai/download")!)
                                .font(.subheadline)
                                .padding(.top, 4)
                        }
                        .padding(.vertical, 8)
                    }
                    
                    DisclosureGroup("How do I use OpenAI or OpenRouter?") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("1. Obtain an API key from the provider's website")
                                .font(.subheadline)
                            
                            Text("2. Go to Settings → API Keys")
                                .font(.subheadline)
                            
                            Text("3. Enter your API key")
                                .font(.subheadline)
                            
                            Text("4. Start a new conversation and select the provider")
                                .font(.subheadline)
                            
                            HStack {
                                Link("OpenAI API Keys", destination: URL(string: "https://platform.openai.com/api-keys")!)
                                    .font(.subheadline)
                                
                                Spacer()
                                
                                Link("OpenRouter", destination: URL(string: "https://openrouter.ai/keys")!)
                                    .font(.subheadline)
                            }
                            .padding(.top, 4)
                        }
                        .padding(.vertical, 8)
                    }
                    
                    DisclosureGroup("How do I organize my conversations?") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("1. Go to the Conversation list")
                                .font(.subheadline)
                            
                            Text("2. Swipe left on a conversation for options")
                                .font(.subheadline)
                            
                            Text("3. Tap 'Move' to assign to a folder")
                                .font(.subheadline)
                            
                            Text("4. Create new folders from the bottom toolbar")
                                .font(.subheadline)
                            
                            Text("5. Long-press a conversation to add tags")
                                .font(.subheadline)
                        }
                        .padding(.vertical, 8)
                    }
                    
                    DisclosureGroup("How do I export my conversations?") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("1. Go to Settings → Import/Export")
                                .font(.subheadline)
                            
                            Text("2. Choose your preferred export format")
                                .font(.subheadline)
                            
                            Text("3. Select which conversations to export")
                                .font(.subheadline)
                            
                            Text("4. The exported file will be saved to your chosen location")
                                .font(.subheadline)
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                Section(header: Text("Troubleshooting")) {
                    DisclosureGroup("Can't connect to Ollama") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("1. Make sure Ollama is running on your computer")
                                .font(.subheadline)
                            
                            Text("2. Check that your device and computer are on the same network")
                                .font(.subheadline)
                            
                            Text("3. Verify the IP address and port are correct")
                                .font(.subheadline)
                            
                            Text("4. Check for firewalls blocking the connection")
                                .font(.subheadline)
                            
                            Text("5. Try the automatic discovery feature")
                                .font(.subheadline)
                        }
                        .padding(.vertical, 8)
                    }
                    
                    DisclosureGroup("API Key Not Working") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("1. Verify you've entered the correct API key")
                                .font(.subheadline)
                            
                            Text("2. Check that your account has sufficient credits")
                                .font(.subheadline)
                            
                            Text("3. Ensure your API key has the necessary permissions")
                                .font(.subheadline)
                            
                            Text("4. Try the 'Verify' button to test the API key")
                                .font(.subheadline)
                        }
                        .padding(.vertical, 8)
                    }
                    
                    DisclosureGroup("App Performance Issues") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("1. Close background apps to free up memory")
                                .font(.subheadline)
                            
                            Text("2. Restart the app")
                                .font(.subheadline)
                            
                            Text("3. Check for app updates")
                                .font(.subheadline)
                            
                            Text("4. If using Ollama, ensure your computer has sufficient resources")
                                .font(.subheadline)
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                Section(header: Text("Contact & Support")) {
                    Button(action: {
                        openURL(URL(string: "https://github.com/open-webui/open-webui/issues")!)
                    }) {
                        HStack {
                            Image(systemName: "exclamationmark.bubble")
                            Text("Report an Issue")
                        }
                    }
                    
                    Button(action: {
                        openURL(URL(string: "https://discord.gg/open-webui")!)
                    }) {
                        HStack {
                            Image(systemName: "bubble.left.and.bubble.right")
                            Text("Join Discord Community")
                        }
                    }
                    
                    Button(action: {
                        // This would normally open an email composer
                        UIPasteboard.general.string = "support@openwebui.com"
                        
                        // Show a toast or alert that email was copied
                    }) {
                        HStack {
                            Image(systemName: "envelope")
                            Text("Email Support")
                        }
                    }
                }
                
                Section(header: Text("Documentation")) {
                    Button(action: {
                        openURL(URL(string: "https://docs.openwebui.com")!)
                    }) {
                        HStack {
                            Image(systemName: "doc.text")
                            Text("User Guide")
                        }
                    }
                    
                    Button(action: {
                        openURL(URL(string: "https://github.com/ollama/ollama/blob/main/docs/api.md")!)
                    }) {
                        HStack {
                            Image(systemName: "server.rack")
                            Text("Ollama API Documentation")
                        }
                    }
                    
                    Button(action: {
                        openURL(URL(string: "https://platform.openai.com/docs/api-reference")!)
                    }) {
                        HStack {
                            Image(systemName: "brain")
                            Text("OpenAI API Documentation")
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Help & Support")
            .navigationBarItems(
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}

struct PrivacySettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var appState: AppState
    @State private var analyticsEnabled = false
    @State private var crashReportingEnabled = true
    @State private var localStorageEncrypted = true
    @State private var showOpenAIDisclaimer = true
    @State private var isPerformingAction = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Data Collection")) {
                    Toggle("Anonymous Analytics", isOn: $analyticsEnabled)
                        .onChange(of: analyticsEnabled) { _ in
                            // Would normally update user preferences
                        }
                    
                    Toggle("Crash Reporting", isOn: $crashReportingEnabled)
                        .onChange(of: crashReportingEnabled) { _ in
                            // Would normally update user preferences
                        }
                    
                    Toggle("Share Usage Statistics", isOn: .constant(false))
                        .disabled(true) // Always off in this version
                }
                .listRowBackground(Color(.systemGray6))
                
                Section(header: Text("Data Storage"), footer: Text("Enabling encryption adds an extra layer of security but may slightly reduce performance.")) {
                    Toggle("Encrypt Local Storage", isOn: $localStorageEncrypted)
                        .onChange(of: localStorageEncrypted) { newValue in
                            if newValue {
                                // Would enable encryption
                            } else {
                                // Would disable encryption
                            }
                        }
                    
                    Button(action: {
                        isPerformingAction = true
                        // Simulate action
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            isPerformingAction = false
                        }
                    }) {
                        if isPerformingAction {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                Spacer()
                            }
                        } else {
                            Text("Re-encrypt All Conversations")
                        }
                    }
                    .disabled(!localStorageEncrypted || isPerformingAction)
                }
                
                Section(header: Text("Third-Party Services")) {
                    Toggle("OpenAI Data Usage Disclaimer", isOn: $showOpenAIDisclaimer)
                        .onChange(of: showOpenAIDisclaimer) { _ in
                            // Would normally update user preferences
                        }
                    
                    Text("OpenAI may use your conversations for service improvement. Disable to hide this disclaimer.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section(header: Text("Data Management")) {
                    Button(action: {
                        // Would typically present confirmation dialog
                        isPerformingAction = true
                        
                        // Simulate action
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            isPerformingAction = false
                        }
                    }) {
                        if isPerformingAction {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                Spacer()
                            }
                        } else {
                            Text("Clear Conversation History")
                                .foregroundColor(.red)
                        }
                    }
                    .disabled(isPerformingAction)
                    
                    Button(action: {
                        // Would typically present confirmation dialog
                    }) {
                        Text("Delete All API Keys")
                            .foregroundColor(.red)
                    }
                    
                    Button(action: {
                        // Would typically present confirmation dialog
                    }) {
                        Text("Reset All Settings")
                            .foregroundColor(.red)
                    }
                }
                
                Section(header: Text("Privacy Policy")) {
                    Link(destination: URL(string: "https://openwebui.com/privacy")!) {
                        HStack {
                            Text("View Privacy Policy")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.accentColor)
                        }
                    }
                    
                    Link(destination: URL(string: "https://openwebui.com/terms")!) {
                        HStack {
                            Text("Terms of Service")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
            }
            .navigationTitle("Privacy & Security")
            .navigationBarItems(
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}

struct NetworkSettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var useProxyServer = false
    @State private var proxyAddress = ""
    @State private var proxyPort = ""
    @State private var proxyUsername = ""
    @State private var proxyPassword = ""
    @State private var useCertificatePinning = true
    @State private var useCustomDNS = false
    @State private var dnsServer = "1.1.1.1"
    @State private var timeoutDuration = 30.0
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Connection Security")) {
                    Toggle("Certificate Pinning", isOn: $useCertificatePinning)
                    
                    if useCertificatePinning {
                        Text("Certificate pinning helps prevent man-in-the-middle attacks by validating server certificates.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Toggle("Use HTTPS Only", isOn: .constant(true))
                        .disabled(true)
                    
                    HStack {
                        Text("Request Timeout")
                        Spacer()
                        Text("\(Int(timeoutDuration))s")
                    }
                    
                    Slider(value: $timeoutDuration, in: 10...120, step: 5) {
                        Text("Timeout")
                    }
                }
                
                Section(header: Text("Proxy Settings")) {
                    Toggle("Use Proxy Server", isOn: $useProxyServer)
                    
                    if useProxyServer {
                        TextField("Proxy Address", text: $proxyAddress)
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                        
                        TextField("Port", text: $proxyPort)
                            .keyboardType(.numberPad)
                        
                        TextField("Username (optional)", text: $proxyUsername)
                            .autocapitalization(.none)
                        
                        SecureField("Password (optional)", text: $proxyPassword)
                        
                        Button(action: {
                            // Would test proxy connection
                        }) {
                            Text("Test Connection")
                                .frame(maxWidth: .infinity)
                        }
                        .disabled(proxyAddress.isEmpty || proxyPort.isEmpty)
                    }
                }
                
                Section(header: Text("DNS Settings")) {
                    Toggle("Custom DNS Server", isOn: $useCustomDNS)
                    
                    if useCustomDNS {
                        TextField("DNS Server", text: $dnsServer)
                            .keyboardType(.decimalPad)
                        
                        Picker("DNS Provider", selection: $dnsServer) {
                            Text("Cloudflare (1.1.1.1)").tag("1.1.1.1")
                            Text("Google (8.8.8.8)").tag("8.8.8.8")
                            Text("Quad9 (9.9.9.9)").tag("9.9.9.9")
                            Text("OpenDNS (208.67.222.222)").tag("208.67.222.222")
                            Text("Custom").tag("custom")
                        }
                    }
                }
                
                Section(header: Text("Local Network")) {
                    Toggle("Local Network Discovery", isOn: .constant(true))
                    
                    HStack {
                        Text("Ollama Port")
                        Spacer()
                        Text("11434")
                            .foregroundColor(.secondary)
                    }
                    
                    Button(action: {
                        // Would scan network
                    }) {
                        Text("Scan Network for Ollama Servers")
                            .frame(maxWidth: .infinity)
                    }
                }
                
                Section(header: Text("Advanced"), footer: Text("These settings should only be changed if you know what you're doing.")) {
                    HStack {
                        Text("Connection Mode")
                        Spacer()
                        Text("Auto-detect")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("WebSocket Protocol")
                        Spacer()
                        Text("WSS/WS")
                            .foregroundColor(.secondary)
                    }
                    
                    Toggle("Enable Debug Logging", isOn: .constant(false))
                }
            }
            .navigationTitle("Network Settings")
            .navigationBarItems(
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}

struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
        AboutView()
    }
}

struct HelpSupportView_Previews: PreviewProvider {
    static var previews: some View {
        HelpSupportView()
    }
}

struct PrivacySettingsView_Previews: PreviewProvider {
    static var previews: some View {
        PrivacySettingsView()
            .environmentObject(AppState())
    }
}

struct NetworkSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NetworkSettingsView()
    }
}