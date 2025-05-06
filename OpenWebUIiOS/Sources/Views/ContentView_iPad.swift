import SwiftUI

struct ContentView_iPad: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var chatViewModel = ChatViewModel()
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
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
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Primary sidebar with section selection
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
                
                Divider()
                    .padding(.vertical, 8)
                
                // List for the selected section type
                switch selectedSection {
                case .conversations:
                    conversationsList
                case .providers:
                    providersList
                case .settings:
                    settingsList
                }
            }
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
        } content: {
            // Secondary sidebar content based on selected section
            switch selectedSection {
            case .conversations:
                if let selectedConversation = chatViewModel.currentConversation {
                    ConversationDetailView(conversation: selectedConversation)
                } else {
                    Text("Select a conversation or create a new one")
                        .foregroundColor(.secondary)
                }
            case .providers:
                if let provider = appState.selectedProvider, provider != .none {
                    ProviderDetailView(provider: provider)
                } else {
                    Text("Select a provider to configure")
                        .foregroundColor(.secondary)
                }
            case .settings:
                List {
                    NavigationLink("All Settings", destination: SettingsView())
                    NavigationLink("API Keys", destination: APIKeyManagementView())
                    NavigationLink("Import/Export", destination: ImportExportView())
                    NavigationLink("About", destination: AboutView())
                }
                .listStyle(InsetGroupedListStyle())
            }
        } detail: {
            // Main content area
            if appState.isAuthenticated {
                ChatView()
                    .environmentObject(chatViewModel)
            } else {
                WelcomeView()
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
    
    // MARK: - Sidebar Content Views
    
    private var conversationsList: some View {
        List {
            Section(header: Text("Recent")) {
                ForEach(chatViewModel.conversations.prefix(5)) { conversation in
                    ConversationRow(conversation: conversation, isCurrent: conversation.id == chatViewModel.currentConversation?.id)
                        .onTapGesture {
                            chatViewModel.currentConversation = conversation
                        }
                }
            }
            
            Section(header: Text("Manage")) {
                NavigationLink(destination: ConversationListView()) {
                    Label("All Conversations", systemImage: "folder")
                }
                
                Button(action: {
                    let defaultModel = AIModel(
                        id: "default",
                        name: "Default Model",
                        provider: AIModel.ModelProvider(rawValue: appState.selectedProvider.rawValue) ?? .openAI
                    )
                    chatViewModel.createNewConversation(title: "New Conversation", model: defaultModel)
                }) {
                    Label("New Conversation", systemImage: "plus")
                }
            }
        }
        .listStyle(SidebarListStyle())
    }
    
    private var providersList: some View {
        List {
            ForEach(AppState.AIProvider.allCases) { provider in
                NavigationLink(
                    destination: ProviderDetailView(provider: provider),
                    tag: provider,
                    selection: Binding(
                        get: { appState.selectedProvider },
                        set: { appState.selectedProvider = $0 ?? .none }
                    ),
                    label: {
                        Label(
                            provider.rawValue,
                            systemImage: providerIcon(for: provider)
                        )
                    }
                )
            }
        }
        .listStyle(SidebarListStyle())
    }
    
    private var settingsList: some View {
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
        .listStyle(SidebarListStyle())
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

struct ConversationDetailView: View {
    let conversation: Conversation
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Conversation info header
                VStack(alignment: .leading, spacing: 8) {
                    Text(conversation.title)
                        .font(.headline)
                    
                    HStack {
                        Image(systemName: providerIcon)
                            .foregroundColor(providerColor)
                        
                        Text(conversation.provider.displayName)
                            .foregroundColor(.secondary)
                        
                        if !conversation.modelId.isEmpty {
                            Text("•")
                                .foregroundColor(.secondary)
                            
                            Text(conversation.modelId)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .font(.caption)
                    
                    Text("Created: \(formattedDate(conversation.createdAt))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Updated: \(formattedDate(conversation.updatedAt))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                
                // Tags
                if let tags = conversation.tags, !tags.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tags")
                            .font(.headline)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.accentColor.opacity(0.1))
                                        .foregroundColor(.accentColor)
                                        .cornerRadius(12)
                                }
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                }
                
                // Message count summary
                VStack(alignment: .leading, spacing: 8) {
                    Text("Messages")
                        .font(.headline)
                    
                    HStack(spacing: 24) {
                        VStack {
                            Text("\(messageCount)")
                                .font(.title)
                                .bold()
                            Text("Total")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        VStack {
                            Text("\(userMessageCount)")
                                .font(.title)
                                .bold()
                                .foregroundColor(.blue)
                            Text("User")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        VStack {
                            Text("\(assistantMessageCount)")
                                .font(.title)
                                .bold()
                                .foregroundColor(.purple)
                            Text("Assistant")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                
                // Actions
                VStack(alignment: .leading, spacing: 12) {
                    Text("Actions")
                        .font(.headline)
                    
                    HStack(spacing: 12) {
                        Button(action: {
                            // Action to rename conversation
                        }) {
                            Label("Rename", systemImage: "pencil")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        
                        Button(action: {
                            // Action to export conversation
                        }) {
                            Label("Export", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    HStack(spacing: 12) {
                        Button(action: {
                            // Action to archive conversation
                        }) {
                            Label(conversation.isArchived ? "Unarchive" : "Archive", 
                                  systemImage: conversation.isArchived ? "tray.and.arrow.up" : "archivebox")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        
                        Button(action: {
                            // Action to delete conversation
                        }) {
                            Label("Delete", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.red)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            }
            .padding()
        }
        .navigationTitle("Conversation Details")
    }
    
    private var messageCount: Int {
        conversation.messages.count
    }
    
    private var userMessageCount: Int {
        conversation.messages.filter { $0.role == .user }.count
    }
    
    private var assistantMessageCount: Int {
        conversation.messages.filter { $0.role == .assistant }.count
    }
    
    private var providerIcon: String {
        switch conversation.provider {
        case .ollama: return "server.rack"
        case .openAI: return "brain"
        case .openRouter: return "network"
        }
    }
    
    private var providerColor: Color {
        switch conversation.provider {
        case .ollama: return .green
        case .openAI: return .blue
        case .openRouter: return .purple
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct ContentView_iPad_Previews: PreviewProvider {
    static var previews: some View {
        ContentView_iPad()
            .environmentObject(AppState())
            .previewDevice(PreviewDevice(rawValue: "iPad Pro (11-inch)"))
            .previewInterfaceOrientation(.landscapeLeft)
    }
}