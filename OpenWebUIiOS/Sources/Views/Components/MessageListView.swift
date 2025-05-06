import SwiftUI

struct MessageListView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: ChatViewModel
    @State private var isCreatingNew = false
    @State private var searchText = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with search and new chat button
            HStack {
                Text("Conversations")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    isCreatingNew = true
                }) {
                    Image(systemName: "square.and.pencil")
                }
            }
            .padding()
            
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search conversations", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
            
            List {
                Section(header: Text("Recent")) {
                    ForEach(filteredConversations) { conversation in
                        ConversationRow(
                            conversation: conversation,
                            isSelected: viewModel.currentConversation?.id == conversation.id
                        )
                        .onTapGesture {
                            viewModel.currentConversation = conversation
                        }
                        .contextMenu {
                            Button(action: {
                                // Rename action
                            }) {
                                Label("Rename", systemImage: "pencil")
                            }
                            
                            Button(role: .destructive, action: {
                                viewModel.deleteConversation(conversation.id)
                            }) {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                
                // No conversations view
                if viewModel.conversations.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        
                        Text("No conversations yet")
                            .font(.headline)
                        
                        Text("Start a new chat to begin")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Button(action: {
                            isCreatingNew = true
                        }) {
                            Text("New Conversation")
                                .fontWeight(.semibold)
                        }
                        .buttonStyle(.bordered)
                        .padding(.top)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.insetGrouped)
        }
        .sheet(isPresented: $isCreatingNew) {
            NewConversationView(viewModel: viewModel, isPresented: $isCreatingNew)
        }
    }
    
    // Filter conversations based on search text
    private var filteredConversations: [Conversation] {
        if searchText.isEmpty {
            return viewModel.conversations
        } else {
            return viewModel.conversations.filter { conversation in
                conversation.title.localizedCaseInsensitiveContains(searchText) ||
                conversation.messages.contains { message in
                    message.content.localizedCaseInsensitiveContains(searchText)
                }
            }
        }
    }
}

// Row view for a single conversation
struct ConversationRow: View {
    let conversation: Conversation
    let isSelected: Bool
    
    var body: some View {
        HStack {
            // Provider icon
            Image(systemName: providerIcon)
                .font(.headline)
                .frame(width: 32, height: 32)
                .background(providerColor.opacity(0.2))
                .foregroundColor(providerColor)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                // Title
                Text(conversation.title)
                    .fontWeight(isSelected ? .bold : .regular)
                    .lineLimit(1)
                
                // Preview of last message
                if let lastMessage = conversation.messages.last {
                    Text(lastMessage.content)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Timestamp and message count
            VStack(alignment: .trailing, spacing: 4) {
                Text(formattedDate)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text("\(conversation.messages.count) msg")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
    }
    
    // Format the date for display
    private var formattedDate: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(conversation.updatedAt) {
            formatter.dateFormat = "HH:mm"
        } else if calendar.isDate(conversation.updatedAt, equalTo: Date(), toGranularity: .weekOfYear) {
            formatter.dateFormat = "E"
        } else {
            formatter.dateFormat = "MM/dd"
        }
        
        return formatter.string(from: conversation.updatedAt)
    }
    
    // Icon for the provider
    private var providerIcon: String {
        switch conversation.provider {
        case .ollama:
            return "server.rack"
        case .openAI:
            return "brain"
        case .openRouter:
            return "network"
        }
    }
    
    // Color for the provider
    private var providerColor: Color {
        switch conversation.provider {
        case .ollama:
            return .green
        case .openAI:
            return .blue
        case .openRouter:
            return .purple
        }
    }
}

// View for creating a new conversation
struct NewConversationView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Binding var isPresented: Bool
    @State private var title = "New Conversation"
    @State private var selectedProvider: AIModel.ModelProvider = .openAI
    @State private var selectedModelId = ""
    @State private var availableModels: [AIModel] = []
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Conversation Details")) {
                    TextField("Title", text: $title)
                    
                    Picker("Provider", selection: $selectedProvider) {
                        ForEach(AIModel.ModelProvider.allCases, id: \.self) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                    .onChange(of: selectedProvider) { _ in
                        selectedModelId = ""
                        loadModels()
                    }
                }
                
                Section(header: Text("Model")) {
                    if isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else if availableModels.isEmpty {
                        Text("No models available")
                            .foregroundColor(.secondary)
                    } else {
                        Picker("Model", selection: $selectedModelId) {
                            ForEach(availableModels) { model in
                                Text(model.name).tag(model.id)
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Conversation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createConversation()
                    }
                    .disabled(title.isEmpty || selectedModelId.isEmpty || isLoading)
                }
            }
            .onAppear {
                loadModels()
            }
        }
    }
    
    private func loadModels() {
        isLoading = true
        
        // In a real implementation, this would use the modelService
        // For now, we'll use placeholder models
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            switch selectedProvider {
            case .ollama:
                availableModels = [
                    AIModel(id: "llama2", name: "Llama 2", provider: .ollama),
                    AIModel(id: "mistral", name: "Mistral", provider: .ollama),
                    AIModel(id: "codellama", name: "Code Llama", provider: .ollama)
                ]
            case .openAI:
                availableModels = [
                    AIModel(id: "gpt-4", name: "GPT-4", provider: .openAI),
                    AIModel(id: "gpt-3.5-turbo", name: "GPT-3.5 Turbo", provider: .openAI)
                ]
            case .openRouter:
                availableModels = [
                    AIModel(id: "anthropic/claude-3-opus", name: "Claude 3 Opus", provider: .openRouter),
                    AIModel(id: "google/gemini-pro", name: "Gemini Pro", provider: .openRouter),
                    AIModel(id: "meta-llama/llama-3-70b", name: "Llama 3 70B", provider: .openRouter)
                ]
            }
            
            // Select the first model by default
            if let firstModel = availableModels.first {
                selectedModelId = firstModel.id
            }
            
            isLoading = false
        }
    }
    
    private func createConversation() {
        guard let model = availableModels.first(where: { $0.id == selectedModelId }) else {
            return
        }
        
        viewModel.createNewConversation(title: title, model: model)
        isPresented = false
    }
}

struct MessageListView_Previews: PreviewProvider {
    static var previews: some View {
        MessageListView(viewModel: ChatViewModel())
            .environmentObject(AppState())
    }
}