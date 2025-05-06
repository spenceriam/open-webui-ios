import SwiftUI

struct ModelSelectionView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: ChatViewModel
    @State private var selectedProvider: AIModel.ModelProvider = .openAI
    @State private var selectedModelId: String = ""
    @State private var isLoading = false
    @State private var models: [AIModel] = []
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss
    
    // Track parameters for the selected model
    @State private var temperature: Double = 0.7
    @State private var topP: Double = 0.9
    @State private var maxTokens: Int = 2048
    @State private var showAdvancedParams = false
    
    private let modelService = ModelService()
    private var filteredModels: [AIModel] {
        if searchText.isEmpty {
            return models.filter { $0.provider == selectedProvider }
        } else {
            return models.filter { model in
                model.provider == selectedProvider &&
                (model.name.localizedCaseInsensitiveContains(searchText) ||
                 (model.description ?? "").localizedCaseInsensitiveContains(searchText) ||
                 (model.tags?.joined(separator: " ") ?? "").localizedCaseInsensitiveContains(searchText))
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Provider selector tabs
                providerTabs
                
                // Search field
                searchField
                
                // Model cards grid
                if isLoading {
                    loadingView
                } else if filteredModels.isEmpty {
                    emptyResultsView
                } else {
                    modelGrid
                }
            }
            .navigationTitle("Select Model")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use") {
                        applySelectedModel()
                    }
                    .disabled(selectedModelId.isEmpty)
                }
            }
            .sheet(isPresented: $showAdvancedParams) {
                parameterSheet
            }
            .onAppear {
                // Initialize to match the current conversation's provider
                if let provider = viewModel.currentConversation?.provider {
                    selectedProvider = AIModel.ModelProvider(rawValue: provider.rawValue) ?? .openAI
                    selectedModelId = viewModel.currentConversation?.modelId ?? ""
                }
                
                loadModels()
            }
        }
    }
    
    // Provider selection tabs
    private var providerTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AIModel.ModelProvider.allCases, id: \.self) { provider in
                    Button(action: {
                        selectedProvider = provider
                        selectedModelId = ""
                    }) {
                        HStack {
                            Image(systemName: providerIcon(for: provider))
                            Text(provider.displayName)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(selectedProvider == provider ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
                        .foregroundColor(selectedProvider == provider ? .accentColor : .primary)
                        .cornerRadius(20)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
    }
    
    // Search field
    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search models", text: $searchText)
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
        .padding(.bottom, 8)
    }
    
    // Loading indicator
    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
                .padding()
            Text("Loading models...")
                .foregroundColor(.secondary)
            Spacer()
        }
    }
    
    // No models found view
    private var emptyResultsView: some View {
        VStack {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
                .padding()
            
            if searchText.isEmpty {
                Text("No models available")
                    .font(.headline)
            } else {
                Text("No models match '\(searchText)'")
                    .font(.headline)
            }
            
            Button("Reload") {
                loadModels()
            }
            .padding(.top)
            
            Spacer()
        }
    }
    
    // Grid of model cards
    private var modelGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 240, maximum: 280), spacing: 16)], spacing: 16) {
                ForEach(filteredModels) { model in
                    ModelCard(
                        model: model,
                        isSelected: selectedModelId == model.id
                    )
                    .onTapGesture {
                        selectedModelId = model.id
                        
                        // Update parameters based on the selected model
                        if let selectedModel = filteredModels.first(where: { $0.id == selectedModelId }) {
                            temperature = selectedModel.defaultParameters.temperature
                            topP = selectedModel.defaultParameters.topP
                            maxTokens = selectedModel.defaultParameters.maxTokens ?? 2048
                        }
                    }
                }
            }
            .padding()
            
            // Parameter adjustment button
            if !selectedModelId.isEmpty {
                Button(action: {
                    showAdvancedParams = true
                }) {
                    HStack {
                        Image(systemName: "slider.horizontal.3")
                        Text("Adjust Parameters")
                    }
                    .padding()
                    .background(Color.accentColor.opacity(0.1))
                    .foregroundColor(.accentColor)
                    .cornerRadius(10)
                }
                .padding(.bottom)
            }
        }
    }
    
    // Parameter adjustment sheet
    private var parameterSheet: some View {
        NavigationStack {
            Form {
                Section(header: Text("Generation Parameters"), footer: Text("These parameters control how the model generates text. Higher temperature means more creative but potentially less coherent responses.")) {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Temperature: \(temperature, specifier: "%.2f")")
                            Spacer()
                            Text(temperatureDescription)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $temperature, in: 0...2, step: 0.05)
                    }
                    
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Top P: \(topP, specifier: "%.2f")")
                            Spacer()
                            Text("Sampling threshold")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $topP, in: 0...1, step: 0.05)
                    }
                    
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Max Tokens: \(maxTokens)")
                            Spacer()
                            Text("Response length")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: Binding(
                            get: { Double(maxTokens) },
                            set: { maxTokens = Int($0) }
                        ), in: 256...4096, step: 256)
                    }
                }
                
                if selectedProvider == .ollama {
                    Section(header: Text("Local Model Settings"), footer: Text("These settings only apply to locally run Ollama models.")) {
                        Toggle("Use GPU acceleration", isOn: .constant(true))
                        Toggle("Low VRAM Mode", isOn: .constant(false))
                        Toggle("Stream response", isOn: .constant(true))
                    }
                }
            }
            .navigationTitle("Model Parameters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showAdvancedParams = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    // Temperature description based on value
    private var temperatureDescription: String {
        if temperature < 0.3 {
            return "More predictable"
        } else if temperature < 0.7 {
            return "Balanced"
        } else if temperature < 1.2 {
            return "More creative"
        } else {
            return "Highly random"
        }
    }
    
    // Fetch available models from the service
    private func loadModels() {
        isLoading = true
        
        modelService.fetchAllAvailableModels()
            .receive(on: DispatchQueue.main)
            .sink { completion in
                isLoading = false
                
                if case .failure(let error) = completion {
                    print("Error fetching models: \(error)")
                }
            } receiveValue: { fetchedModels in
                self.models = fetchedModels
                
                // If we have a selected model ID but it's not in the fetched models,
                // clear the selection
                if !selectedModelId.isEmpty && !fetchedModels.contains(where: { $0.id == selectedModelId }) {
                    selectedModelId = ""
                }
                
                // If no model is selected but we have models for the selected provider,
                // select the first one
                if selectedModelId.isEmpty && !fetchedModels.filter({ $0.provider == selectedProvider }).isEmpty {
                    selectedModelId = fetchedModels.first(where: { $0.provider == selectedProvider })?.id ?? ""
                }
            }
            .store(in: &viewModel.cancellables)
    }
    
    // Apply the selected model to the current conversation
    private func applySelectedModel() {
        guard let selectedModel = models.first(where: { $0.id == selectedModelId }) else {
            return
        }
        
        // Create a new conversation if none exists
        if viewModel.currentConversation == nil {
            viewModel.createNewConversation(title: "New Conversation", model: selectedModel)
        } else {
            // Update the existing conversation with the new model
            var updatedConversation = viewModel.currentConversation!
            updatedConversation.modelId = selectedModel.id
            updatedConversation.provider = Conversation.Provider(rawValue: selectedModel.provider.rawValue) ?? .openAI
            
            // Save the updated conversation
            viewModel.currentConversation = updatedConversation
        }
        
        dismiss()
    }
    
    // Helper function to get provider icon
    private func providerIcon(for provider: AIModel.ModelProvider) -> String {
        switch provider {
        case .ollama:
            return "server.rack"
        case .openAI:
            return "brain"
        case .openRouter:
            return "network"
        }
    }
}

// Card view for displaying a model
struct ModelCard: View {
    let model: AIModel
    let isSelected: Bool
    
    var body: some View {
        VStack(alignment: .leading) {
            // Header with icon and provider
            HStack {
                Image(systemName: providerIcon)
                    .foregroundColor(providerColor)
                
                Spacer()
                
                Text(model.provider.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
                .frame(height: 12)
            
            // Model name
            Text(model.name)
                .font(.headline)
                .lineLimit(1)
            
            // Description
            if let description = model.description {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .padding(.top, 2)
            }
            
            Spacer()
                .frame(height: 8)
            
            // Tags
            if let tags = model.tags, !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                }
            }
            
            Spacer()
            
            // Capabilities
            HStack {
                ForEach(model.capabilities, id: \.self) { capability in
                    Image(systemName: capabilityIcon(capability))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Selected checkmark
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
        }
        .padding()
        .frame(height: 160)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
    }
    
    // Provider icon
    private var providerIcon: String {
        switch model.provider {
        case .ollama: return "server.rack"
        case .openAI: return "brain"
        case .openRouter: return "network"
        }
    }
    
    // Provider color
    private var providerColor: Color {
        switch model.provider {
        case .ollama: return .green
        case .openAI: return .blue
        case .openRouter: return .purple
        }
    }
    
    // Icon for capability
    private func capabilityIcon(_ capability: AIModel.Capability) -> String {
        switch capability {
        case .textGeneration: return "text.bubble"
        case .chat: return "bubble.left.and.bubble.right"
        case .imageGeneration: return "photo"
        case .embedding: return "point.3.connected.trianglepath.dotted"
        case .voiceGeneration: return "waveform"
        case .functionCalling: return "function"
        }
    }
}

// Preview
struct ModelSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        ModelSelectionView(viewModel: ChatViewModel())
            .environmentObject(AppState())
    }
}