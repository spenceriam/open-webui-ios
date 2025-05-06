import SwiftUI

struct ServerDiscoveryView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var serverUrl: String
    @StateObject private var viewModel = ServerDiscoveryViewModel()
    
    var body: some View {
        NavigationView {
            VStack {
                // Status and control section
                VStack(spacing: 16) {
                    HStack {
                        if viewModel.isScanning {
                            ProgressView()
                                .scaleEffect(0.8)
                                .padding(.trailing, 4)
                        } else {
                            Image(systemName: "wifi")
                                .foregroundColor(.accentColor)
                        }
                        
                        Text(viewModel.isScanning ? "Scanning network..." : "Available Servers")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button(action: {
                            if viewModel.isScanning {
                                viewModel.stopDiscovery()
                            } else {
                                viewModel.startDiscovery()
                            }
                        }) {
                            Text(viewModel.isScanning ? "Stop" : "Scan")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.horizontal)
                    
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical)
                
                // Server list
                if viewModel.discoveredServers.isEmpty {
                    VStack(spacing: 20) {
                        if viewModel.isScanning {
                            ProgressView()
                                .scaleEffect(1.5)
                                .padding()
                            
                            Text("Looking for Ollama servers...")
                                .foregroundColor(.secondary)
                        } else {
                            Image(systemName: "server.rack")
                                .font(.system(size: 50))
                                .foregroundColor(.secondary)
                                .padding()
                            
                            Text("No servers found")
                                .font(.headline)
                            
                            Text("Make sure Ollama is running on your network")
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            Button(action: {
                                viewModel.startDiscovery()
                            }) {
                                Text("Scan Again")
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Color.accentColor)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                            .padding(.top)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(viewModel.discoveredServers, id: \.id) { server in
                            Button(action: {
                                selectServer(server)
                            }) {
                                ServerRowView(server: server)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                }
                
                // Manual entry
                VStack(spacing: 12) {
                    Text("Manual Connection")
                        .font(.headline)
                    
                    HStack {
                        TextField("Server URL", text: $serverUrl)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Text("Connect")
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                    
                    Text("Example: http://192.168.1.10:11434")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding()
            }
            .navigationTitle("Discover Servers")
            .navigationBarItems(
                trailing: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
            .onAppear {
                viewModel.startDiscovery()
            }
            .onDisappear {
                viewModel.stopDiscovery()
            }
        }
    }
    
    private func selectServer(_ server: DiscoveryService.OllamaServer) {
        serverUrl = server.apiURL.absoluteString
        presentationMode.wrappedValue.dismiss()
    }
}

struct ServerRowView: View {
    let server: DiscoveryService.OllamaServer
    
    var body: some View {
        HStack {
            Image(systemName: "server.rack")
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(server.name)
                    .font(.headline)
                
                HStack {
                    Text(server.hostName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(":")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(server.port)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if server.available {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.orange)
            }
        }
        .padding(.vertical, 8)
    }
}

class ServerDiscoveryViewModel: ObservableObject {
    @Published var discoveredServers: [DiscoveryService.OllamaServer] = []
    @Published var isScanning: Bool = false
    @Published var errorMessage: String?
    
    private let discoveryService = DiscoveryService()
    
    init() {
        // Subscribe to discovery service updates
        discoveryService.$discoveredServers
            .assign(to: &$discoveredServers)
        
        discoveryService.$isScanning
            .assign(to: &$isScanning)
        
        discoveryService.$error
            .map { error -> String? in
                if let error = error {
                    return "Error: \(error.localizedDescription)"
                }
                return nil
            }
            .assign(to: &$errorMessage)
    }
    
    func startDiscovery() {
        discoveryService.startDiscovery()
    }
    
    func stopDiscovery() {
        discoveryService.stopDiscovery()
    }
}

struct ServerDiscoveryView_Previews: PreviewProvider {
    static var previews: some View {
        ServerDiscoveryView(serverUrl: .constant("http://localhost:11434"))
    }
}