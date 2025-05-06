import SwiftUI

struct ContentView_Landscape: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var chatViewModel = ChatViewModel()
    
    var body: some View {
        HStack(spacing: 0) {
            // Sidebar (always visible in landscape)
            SidebarView_Landscape(chatViewModel: chatViewModel)
                .frame(width: 280)
                .frame(maxHeight: .infinity)
            
            // Vertical divider
            Divider()
            
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

struct SidebarView_Landscape: View {
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
        VStack(spacing: 0) {
            // App title and theme toggle
            HStack {
                Text("Open WebUI")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: {
                    appState.toggleColorScheme()
                }) {
                    Image(systemName: appState.colorScheme == .dark ? "sun.max" : "moon")
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            
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
            
            Divider()
                .padding(.vertical, 8)
            
            // Content based on selected section
            switch selectedSection {
            case .conversations:
                VStack {
                    NavigationLink(destination: ConversationListView()) {
                        Label("Manage All Conversations", systemImage: "folder")
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(chatViewModel.conversations) { conversation in
                                ConversationRow(conversation: conversation, isCurrent: conversation.id == chatViewModel.currentConversation?.id)
                                    .onTapGesture {
                                        chatViewModel.currentConversation = conversation
                                    }
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                }
            case .providers:
                providerSection
            case .settings:
                settingsSection
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
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

struct ConversationRow: View {
    let conversation: Conversation
    let isCurrent: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(conversation.title)
                    .font(.headline)
                    .lineLimit(1)
                
                HStack {
                    Text(conversation.provider.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(formattedDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if conversation.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption)
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(isCurrent ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(8)
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: conversation.updatedAt)
    }
}

struct ContentView_Landscape_Previews: PreviewProvider {
    static var previews: some View {
        ContentView_Landscape()
            .environmentObject(AppState())
            .preferredColorScheme(.dark)
            .previewInterfaceOrientation(.landscapeLeft)
    }
}