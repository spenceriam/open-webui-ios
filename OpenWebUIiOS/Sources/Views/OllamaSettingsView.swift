import SwiftUI
import Combine

struct OllamaSettingsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = OllamaSettingsViewModel()
    @State private var isShowingDiscoveryView = false
    @State private var showDeleteModelAlert = false
    @State private var modelToDelete: AIModel?
    @State private var showImportModelSheet = false
    
    var body: some View {
        List {
            // Server Configuration
            Section(header: Text("Server Configuration")) {
                HStack {
                    Text("Status")
                    Spacer()
                    switch viewModel.serverStatus {
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
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Server URL")
                        .font(.headline)
                    
                    HStack {
                        TextField("Server URL", text: $viewModel.serverURL)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        Button(action: {
                            isShowingDiscoveryView = true
                        }) {
                            Image(systemName: "network")
                                .foregroundColor(.accentColor)
                        }
                    }
                    
                    HStack(spacing: 12) {
                        Button(action: {
                            viewModel.checkServerStatus()
                        }) {
                            Text("Test Connection")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        
                        Button(action: {
                            viewModel.saveServerConfig()
                        }) {
                            Text("Save")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    
                    if viewModel.isSaving {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Saving configuration...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 8)
                
                // Advanced Settings
                DisclosureGroup("Advanced Settings") {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Use WebSocket for Streaming", isOn: $viewModel.useWebSocketForStreaming)
                            .font(.subheadline)
                        
                        Text("Enable WebSocket for faster streaming responses")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Divider()
                        
                        Toggle("Automatic Server Discovery", isOn: $viewModel.autoDiscoverServers)
                            .font(.subheadline)
                            .onChange(of: viewModel.autoDiscoverServers) { newValue in
                                if newValue {
                                    viewModel.startServerDiscovery()
                                } else {
                                    viewModel.stopServerDiscovery()
                                }
                            }
                        
                        Text("Automatically find Ollama servers on your local network")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Divider()
                        
                        Toggle("Connection Keep-Alive", isOn: $viewModel.keepConnectionAlive)
                            .font(.subheadline)
                        
                        Text("Keep connection to the server alive in background")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }
            }
            
            // Installed Models
            Section(header: Text("Installed Models")) {
                if viewModel.isLoadingModels {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Loading models...")
                            .foregroundColor(.secondary)
                    }
                } else if viewModel.models.isEmpty {
                    HStack {
                        Image(systemName: "exclamationmark.circle")
                            .foregroundColor(.orange)
                        Text("No models found on the server")
                            .foregroundColor(.secondary)
                    }
                } else {
                    ForEach(viewModel.models) { model in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(model.name)
                                    .font(.headline)
                                
                                if let size = model.metadata["size"], !size.isEmpty {
                                    Text("Size: \(formattedSize(size))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                modelToDelete = model
                                showDeleteModelAlert = true
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Button(action: {
                    viewModel.refreshModels()
                }) {
                    Label("Refresh Models", systemImage: "arrow.clockwise")
                }
                
                // Model Management
                HStack {
                    Button(action: {
                        showImportModelSheet = true
                    }) {
                        Label("Pull Model", systemImage: "arrow.down.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.top, 4)
            }
            
            // Discovered Servers
            if !viewModel.discoveredServers.isEmpty {
                Section(header: Text("Discovered Servers")) {
                    ForEach(viewModel.discoveredServers, id: \.id) { server in
                        Button(action: {
                            viewModel.connectToDiscoveredServer(server)
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(server.name)
                                        .font(.headline)
                                    
                                    Text(server.url.absoluteString)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "arrow.right.circle")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            
            // Tips Section
            Section(header: Text("Tips")) {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Running Ollama")
                            .font(.headline)
                        
                        Text("Make sure Ollama is running on your computer before connecting.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Link(destination: URL(string: "https://ollama.ai/download")!) {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(.green)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Download Ollama")
                                .font(.headline)
                            
                            Text("Install Ollama on your computer to run models locally")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Link(destination: URL(string: "https://github.com/ollama/ollama/blob/main/docs/api.md")!) {
                    HStack {
                        Image(systemName: "doc.text.fill")
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Ollama API Documentation")
                                .font(.headline)
                            
                            Text("Learn more about the Ollama API")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("Ollama Configuration")
        .onAppear {
            viewModel.initialize()
        }
        .sheet(isPresented: $isShowingDiscoveryView) {
            ServerDiscoveryView(serverUrl: $viewModel.serverURL)
        }
        .sheet(isPresented: $showImportModelSheet) {
            ModelPullView(onModelPulled: {
                viewModel.refreshModels()
            })
        }
        .alert(isPresented: $showDeleteModelAlert) {
            Alert(
                title: Text("Delete Model"),
                message: Text("Are you sure you want to delete \(modelToDelete?.name ?? "this model")? This cannot be undone."),
                primaryButton: .destructive(Text("Delete")) {
                    if let model = modelToDelete {
                        viewModel.deleteModel(model)
                    }
                },
                secondaryButton: .cancel()
            )
        }
        .alert(item: $viewModel.errorAlert) { error in
            Alert(
                title: Text("Error"),
                message: Text(error.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func formattedSize(_ sizeString: String) -> String {
        if let size = Int64(sizeString) {
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useGB, .useMB]
            formatter.countStyle = .file
            return formatter.string(fromByteCount: size)
        }
        return sizeString
    }
}

class OllamaSettingsViewModel: ObservableObject {
    @Published var serverURL: String = "http://localhost:11434"
    @Published var serverStatus: OllamaService.ServerStatus = .unknown
    @Published var models: [AIModel] = []
    @Published var isLoadingModels: Bool = false
    @Published var discoveredServers: [DiscoveryService.OllamaServer] = []
    @Published var isSaving: Bool = false
    @Published var useWebSocketForStreaming: Bool = true
    @Published var autoDiscoverServers: Bool = false
    @Published var keepConnectionAlive: Bool = false
    @Published var errorAlert: ErrorMessage?
    
    private let ollamaService = OllamaService()
    private let discoveryService = DiscoveryService()
    private var cancellables = Set<AnyCancellable>()
    
    struct ErrorMessage: Identifiable {
        let id = UUID()
        let message: String
    }
    
    func initialize() {
        // Load user defaults
        serverURL = UserDefaults.standard.string(forKey: "ollama_server_url") ?? "http://localhost:11434"
        useWebSocketForStreaming = UserDefaults.standard.bool(forKey: "ollama_use_websocket")
        autoDiscoverServers = UserDefaults.standard.bool(forKey: "ollama_auto_discover")
        keepConnectionAlive = UserDefaults.standard.bool(forKey: "ollama_keep_alive")
        
        // Set the server URL on the Ollama service
        ollamaService.setServerURL(serverURL)
        
        // Subscribe to status updates
        ollamaService.$serverStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.serverStatus = status
            }
            .store(in: &cancellables)
        
        // Subscribe to discovered servers
        discoveryService.$discoveredServers
            .receive(on: DispatchQueue.main)
            .sink { [weak self] servers in
                self?.discoveredServers = servers
            }
            .store(in: &cancellables)
        
        // Check server status
        checkServerStatus()
        
        // Start server discovery if enabled
        if autoDiscoverServers {
            startServerDiscovery()
        }
        
        // Load models
        refreshModels()
    }
    
    func checkServerStatus() {
        ollamaService.checkServerStatus()
    }
    
    func refreshModels() {
        isLoadingModels = true
        
        ollamaService.fetchAvailableModels()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoadingModels = false
                
                if case .failure(let error) = completion {
                    self?.errorAlert = ErrorMessage(message: "Failed to load models: \(error.localizedDescription)")
                }
            } receiveValue: { [weak self] fetchedModels in
                self?.models = fetchedModels
            }
            .store(in: &cancellables)
    }
    
    func saveServerConfig() {
        isSaving = true
        
        // Update the Ollama service with the new URL
        ollamaService.setServerURL(serverURL)
        
        // Save to user defaults
        UserDefaults.standard.set(serverURL, forKey: "ollama_server_url")
        UserDefaults.standard.set(useWebSocketForStreaming, forKey: "ollama_use_websocket")
        UserDefaults.standard.set(autoDiscoverServers, forKey: "ollama_auto_discover")
        UserDefaults.standard.set(keepConnectionAlive, forKey: "ollama_keep_alive")
        
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.isSaving = false
            self?.checkServerStatus()
            self?.refreshModels()
        }
    }
    
    func startServerDiscovery() {
        discoveryService.startDiscovery()
    }
    
    func stopServerDiscovery() {
        discoveryService.stopDiscovery()
    }
    
    func connectToDiscoveredServer(_ server: DiscoveryService.OllamaServer) {
        serverURL = server.apiURL.absoluteString
        saveServerConfig()
    }
    
    func deleteModel(_ model: AIModel) {
        // In a real implementation, we would call the Ollama API to delete the model
        // For now, we'll simulate with a delay and update the local state
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.models.removeAll { $0.id == model.id }
        }
    }
}

struct ModelPullView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var modelName: String = ""
    @State private var isPulling: Bool = false
    @State private var progress: Float = 0.0
    @State private var statusMessage: String = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    var onModelPulled: () -> Void
    
    private let popularModels = [
        "llama2", "mistral", "gemma", "codellama", "phi", "llava"
    ]
    
    var body: some View {
        NavigationView {
            VStack {
                // Input for model name
                VStack(alignment: .leading, spacing: 8) {
                    Text("Enter Model Name")
                        .font(.headline)
                    
                    TextField("Model name (e.g., llama2)", text: $modelName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    Text("Examples: llama2, mistral, codellama:7b-code, orca-mini")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                
                // Popular models
                VStack(alignment: .leading, spacing: 8) {
                    Text("Popular Models")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(popularModels, id: \.self) { model in
                                Button(action: {
                                    modelName = model
                                }) {
                                    Text(model)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color.secondary.opacity(0.2))
                                        .cornerRadius(8)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Pull button
                Button(action: {
                    pullModel()
                }) {
                    Text(isPulling ? "Pulling..." : "Pull Model")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isPulling ? Color.gray : Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(isPulling || modelName.isEmpty)
                .padding()
                
                // Progress indicator
                if isPulling {
                    VStack(spacing: 12) {
                        ProgressView(value: progress)
                            .progressViewStyle(LinearProgressViewStyle())
                        
                        Text(statusMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
                
                Spacer()
            }
            .navigationTitle("Pull Ollama Model")
            .navigationBarItems(
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("Error"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    private func pullModel() {
        guard !modelName.isEmpty else { return }
        
        isPulling = true
        progress = 0.0
        statusMessage = "Initializing download..."
        
        // This would normally call the Ollama API, but for this example we'll simulate the progress
        simulatePullProgress()
    }
    
    private func simulatePullProgress() {
        var progressCounter: Float = 0.0
        let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
        
        let progressSubscription = timer.sink { _ in
            progressCounter += Float.random(in: 0.05...0.15)
            progress = min(progressCounter, 1.0)
            
            if progress < 0.3 {
                statusMessage = "Downloading model manifest..."
            } else if progress < 0.6 {
                statusMessage = "Downloading model weights..."
            } else if progress < 0.9 {
                statusMessage = "Processing model files..."
            } else {
                statusMessage = "Finalizing installation..."
            }
            
            if progress >= 1.0 {
                isPulling = false
                statusMessage = "Model downloaded successfully!"
                timer.upstream.connect().cancel()
                
                // Wait a moment before closing
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    onModelPulled()
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
        
        // In a real implementation, we would handle cancellation properly
        _ = progressSubscription
    }
}

struct OllamaSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        OllamaSettingsView()
            .environmentObject(AppState())
    }
}