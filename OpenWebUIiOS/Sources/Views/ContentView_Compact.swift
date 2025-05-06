import SwiftUI

struct ContentView_Compact: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var chatViewModel = ChatViewModel()
    @State private var selectedTab: Tab = .chat
    
    enum Tab {
        case chat
        case conversations
        case providers
        case settings
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            compactHeader
            
            // Main content
            if appState.isAuthenticated {
                tabContent
            } else {
                WelcomeView()
            }
            
            // Tab bar
            if appState.isAuthenticated {
                compactTabBar
            }
        }
    }
    
    // Compact header with title and actions
    private var compactHeader: some View {
        HStack {
            // Title based on selected tab
            Text(tabTitle)
                .font(.headline)
                .foregroundColor(.primary)
            
            Spacer()
            
            // Theme toggle button
            Button(action: {
                appState.toggleColorScheme()
            }) {
                Image(systemName: appState.colorScheme == .dark ? "sun.max" : "moon")
            }
            
            // Additional actions for chat tab
            if selectedTab == .chat && appState.isAuthenticated {
                Button(action: {
                    // Open model selector
                }) {
                    Image(systemName: "arrow.triangle.swap")
                        .font(.system(size: 16))
                }
                .padding(.leading, 16)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(.systemGray4)),
            alignment: .bottom
        )
    }
    
    // Main content area based on selected tab
    private var tabContent: some View {
        ZStack {
            switch selectedTab {
            case .chat:
                ChatView()
                    .environmentObject(chatViewModel)
            case .conversations:
                ConversationListView()
            case .providers:
                NavigationStack {
                    VStack {
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
                    .navigationTitle("Providers")
                }
            case .settings:
                NavigationStack {
                    SettingsView()
                }
            }
        }
    }
    
    // Compact tab bar for easy navigation
    private var compactTabBar: some View {
        HStack(spacing: 0) {
            ForEach([Tab.chat, Tab.conversations, Tab.providers, Tab.settings], id: \.self) { tab in
                Button(action: {
                    selectedTab = tab
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: iconFor(tab))
                            .font(.system(size: 20))
                        
                        Text(titleFor(tab))
                            .font(.caption2)
                    }
                    .foregroundColor(selectedTab == tab ? .accentColor : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(.systemGray4)),
            alignment: .top
        )
    }
    
    // Helper computed properties
    private var tabTitle: String {
        switch selectedTab {
        case .chat:
            return chatViewModel.currentConversation?.title ?? "New Chat"
        case .conversations:
            return "Conversations"
        case .providers:
            return "Providers"
        case .settings:
            return "Settings"
        }
    }
    
    private func iconFor(_ tab: Tab) -> String {
        switch tab {
        case .chat:
            return "bubble.left.and.bubble.right"
        case .conversations:
            return "folder"
        case .providers:
            return "network"
        case .settings:
            return "gear"
        }
    }
    
    private func titleFor(_ tab: Tab) -> String {
        switch tab {
        case .chat:
            return "Chat"
        case .conversations:
            return "History"
        case .providers:
            return "Providers"
        case .settings:
            return "Settings"
        }
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

struct CompactWelcomeView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.text.bubble.right")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)
            
            Text("Welcome to Open WebUI")
                .font(.title2)
                .bold()
            
            Text("Choose a provider to get started")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Provide compact layout for provider buttons
            VStack(spacing: 12) {
                ForEach(AppState.AIProvider.allCases, id: \.self) { provider in
                    if provider != .none {
                        Button(action: {
                            appState.selectedProvider = provider
                            appState.isAuthenticated = true
                        }) {
                            HStack {
                                Image(systemName: providerIcon(for: provider))
                                    .font(.system(size: 20))
                                    .foregroundColor(.accentColor)
                                    .frame(width: 32, height: 32)
                                    .background(Color.accentColor.opacity(0.1))
                                    .clipShape(Circle())
                                
                                Text(provider.rawValue)
                                    .font(.headline)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(10)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding()
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

struct ContentView_Compact_Previews: PreviewProvider {
    static var previews: some View {
        ContentView_Compact()
            .environmentObject(AppState())
            .previewDevice(PreviewDevice(rawValue: "iPhone SE (3rd generation)"))
    }
}