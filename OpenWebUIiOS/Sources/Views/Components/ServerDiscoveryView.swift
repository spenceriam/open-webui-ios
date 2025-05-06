import SwiftUI

struct ServerDiscoveryView: View {
    @StateObject private var discoveryService = DiscoveryService()
    @State private var customServerUrl = "http://localhost:11434"
    @State private var isValidating = false
    @State private var validationError: String?
    @State private var selectedServer: DiscoveryService.OllamaServer?
    @Binding var serverUrl: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                // Custom server section
                Section(header: Text("Custom Server")) {
                    HStack {
                        TextField("Ollama URL (e.g., http://localhost:11434)", text: $customServerUrl)
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        if isValidating {
                            ProgressView()
                                .padding(.leading, 4)
                        } else {
                            Button("Validate") {
                                validateCustomServer()
                            }
                            .disabled(customServerUrl.isEmpty)
                        }
                    }
                    
                    if let error = validationError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                // Discovered servers section
                Section(header: HStack {
                    Text("Discovered Servers")
                    Spacer()
                    if discoveryService.isScanning {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }) {
                    if discoveryService.discoveredServers.isEmpty {
                        if discoveryService.isScanning {
                            HStack {
                                Text("Searching for Ollama servers...")
                                    .foregroundColor(.secondary)
                                Spacer()
                                ProgressView()
                            }
                        } else {
                            Text("No Ollama servers found on the network")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        ForEach(discoveryService.discoveredServers) { server in
                            ServerRow(server: server, isSelected: selectedServer?.id == server.id)
                                .onTapGesture {
                                    selectedServer = server
                                    customServerUrl = server.url.absoluteString
                                }
                        }
                    }
                }
                
                // Recently connected
                Section(header: Text("Recently Connected")) {
                    ServerRow(
                        server: DiscoveryService.OllamaServer(
                            name: "Last Used Server",
                            endpoint: NWEndpoint.hostPort(host: .name("localhost", nil), port: 11434),
                            hostName: "localhost",
                            port: 11434,
                            available: true
                        ),
                        isSelected: selectedServer == nil && customServerUrl == "http://localhost:11434"
                    )
                    .onTapGesture {
                        selectedServer = nil
                        customServerUrl = "http://localhost:11434"
                    }
                }
                
                // Help section
                Section(header: Text("Help")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Installing Ollama")
                            .font(.headline)
                        
                        Text("Ollama is an open-source tool that lets you run LLMs locally on your computer. To use this app with Ollama:")
                            .font(.caption)
                        
                        Link("1. Install Ollama from ollama.ai", destination: URL(string: "https://ollama.ai")!)
                            .font(.caption)
                        
                        Text("2. Run the Ollama app on your computer")
                            .font(.caption)
                        
                        Text("3. Pull a model using 'ollama pull mistral' or another model name")
                            .font(.caption)
                        
                        Text("You can also connect to a remote Ollama server by entering its URL above.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }
            }
            .listStyle(.insetGrouped)
            .refreshable {
                discoveryService.startDiscovery()
            }
            .navigationTitle("Connect to Ollama")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Connect") {
                        serverUrl = customServerUrl
                        dismiss()
                    }
                    .disabled(customServerUrl.isEmpty)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        discoveryService.startDiscovery()
                    }) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
            }
            .onAppear {
                discoveryService.startDiscovery()
            }
            .onDisappear {
                discoveryService.stopDiscovery()
            }
        }
    }
    
    private func validateCustomServer() {
        guard var urlString = URL(string: customServerUrl) else {
            validationError = "Invalid URL format"
            return
        }
        
        // Ensure URL ends with /api for validation
        if !urlString.absoluteString.hasSuffix("/api") {
            urlString = urlString.appendingPathComponent("api")
        }
        
        isValidating = true
        validationError = nil
        
        // Create a simple request to validate
        var request = URLRequest(url: urlString.appendingPathComponent("tags"))
        request.timeoutInterval = 3.0
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isValidating = false
                
                if let error = error {
                    validationError = "Connection error: \(error.localizedDescription)"
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    validationError = "Invalid server response"
                    return
                }
                
                if httpResponse.statusCode != 200 {
                    validationError = "Server returned status code \(httpResponse.statusCode)"
                    return
                }
                
                guard let data = data else {
                    validationError = "No data received from server"
                    return
                }
                
                do {
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                    if json?["models"] == nil {
                        validationError = "Not an Ollama server"
                    } else {
                        validationError = nil
                    }
                } catch {
                    validationError = "Could not parse server response"
                }
            }
        }.resume()
    }
}

struct ServerRow: View {
    let server: DiscoveryService.OllamaServer
    let isSelected: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(server.name)
                    .font(.headline)
                
                Text(server.url.absoluteString)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Status indicator
            if server.available {
                Image(systemName: "circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
            } else {
                Image(systemName: "circle.fill")
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            // Selection indicator
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(.accentColor)
            }
        }
        .contentShape(Rectangle())
    }
}

struct ServerDiscoveryView_Previews: PreviewProvider {
    static var previews: some View {
        ServerDiscoveryView(serverUrl: .constant("http://localhost:11434"))
    }
}