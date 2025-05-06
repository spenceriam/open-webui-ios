import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingSidebar: Bool = false
    
    var body: some View {
        NavigationSplitView {
            // Sidebar content
            SidebarView(isVisible: $showingSidebar)
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
            } else {
                WelcomeView()
            }
        }
    }
}

struct SidebarView: View {
    @Binding var isVisible: Bool
    @State private var searchText = ""
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        List {
            Section(header: Text("Providers")) {
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
            
            Section(header: Text("Recent Chats")) {
                NavigationLink(
                    destination: Text("Chat History"),
                    label: {
                        Label("Chat History", systemImage: "bubble.left.and.bubble.right")
                    }
                )
            }
            
            Section(header: Text("Settings")) {
                NavigationLink(
                    destination: Text("Settings"),
                    label: {
                        Label("Settings", systemImage: "gear")
                    }
                )
            }
        }
        .searchable(text: $searchText, prompt: "Search conversations")
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
                    action: { appState.selectedProvider = .ollama }
                )
                
                ProviderButton(
                    title: "OpenAI",
                    subtitle: "Cloud API",
                    icon: "brain",
                    action: { appState.selectedProvider = .openAI }
                )
                
                ProviderButton(
                    title: "OpenRouter",
                    subtitle: "Multiple Models",
                    icon: "network",
                    action: { appState.selectedProvider = .openRouter }
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
    
    var body: some View {
        Text("Configure \(provider.rawValue)")
            .font(.largeTitle)
        // This will be expanded in future implementations
    }
}

struct ChatView: View {
    var body: some View {
        Text("Chat Interface Coming Soon")
            .font(.largeTitle)
        // This will be expanded in future implementations
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}