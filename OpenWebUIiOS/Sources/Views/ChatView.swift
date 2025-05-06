import SwiftUI

struct ChatView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var viewModel: ChatViewModel
    @State private var messageText: String = ""
    @State private var isShowingModelSelector: Bool = false
    @State private var isShowingSettings: Bool = false
    @State private var isScrolled: Bool = false
    @FocusState private var messageInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Chat header
            chatHeader
            
            // Messages list
            messagesView
            
            // Input area
            inputView
        }
        .onAppear {
            if viewModel.currentConversation == nil && !viewModel.conversations.isEmpty {
                viewModel.currentConversation = viewModel.conversations.first
            }
        }
        .sheet(isPresented: $isShowingModelSelector) {
            ModelSelectionView(viewModel: viewModel)
        }
    }
    
    // Chat header with model info and actions
    private var chatHeader: some View {
        HStack {
            // Current model info
            Button(action: {
                isShowingModelSelector = true
            }) {
                HStack {
                    Image(systemName: modelIcon)
                        .font(.title3)
                    
                    VStack(alignment: .leading) {
                        Text(conversationTitle)
                            .font(.headline)
                        
                        HStack {
                            if let provider = viewModel.currentConversation?.provider {
                                Text(provider.displayName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            if let modelId = viewModel.currentConversation?.modelId {
                                Text("•")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text(modelId)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .foregroundColor(.primary)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.leading)
            
            Spacer()
            
            // Actions
            HStack(spacing: 16) {
                Button(action: {
                    isShowingModelSelector = true
                }) {
                    Image(systemName: "arrow.triangle.swap")
                        .font(.title3)
                }
                
                Button(action: {
                    isShowingSettings.toggle()
                }) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.title3)
                }
            }
            .padding(.trailing)
        }
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(.systemGray4)),
            alignment: .bottom
        )
    }
    
    // Messages scrolling view
    private var messagesView: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.currentConversation?.messages ?? [], id: \.id) { message in
                        MessageBubbleView(
                            message: message,
                            isLastMessage: isLastMessage(message)
                        )
                        .id(message.id)
                    }
                }
                .padding(.bottom)
            }
            .onChange(of: viewModel.currentConversation) { _ in
                // Scroll to bottom when conversation changes
                if let lastMessage = viewModel.currentConversation?.messages.last {
                    withAnimation {
                        scrollProxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: viewModel.isStreaming) { isStreaming in
                // Scroll to bottom when streaming status changes
                if isStreaming, let lastMessage = viewModel.currentConversation?.messages.last {
                    withAnimation {
                        scrollProxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
        .background(Color(.systemGroupedBackground))
    }
    
    // Input view for sending messages
    private var inputView: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(alignment: .bottom) {
                // Attachment button (placeholder)
                Button(action: {
                    // Attachment functionality would go here
                }) {
                    Image(systemName: "paperclip")
                        .font(.title3)
                        .foregroundColor(.accentColor)
                }
                .padding(.leading)
                
                // Text input field
                ZStack(alignment: .trailing) {
                    TextField("Ask anything...", text: $messageText, axis: .vertical)
                        .padding(10)
                        .background(Color(.systemGray6))
                        .cornerRadius(20)
                        .focused($messageInputFocused)
                        .submitLabel(.send)
                        .onSubmit {
                            sendMessage()
                        }
                    
                    // Clear button
                    if !messageText.isEmpty {
                        Button(action: {
                            messageText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .padding(.trailing, 8)
                    }
                }
                .padding(.vertical, 8)
                
                // Send button
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(messageText.isEmpty ? .secondary : .accentColor)
                }
                .disabled(messageText.isEmpty || viewModel.isStreaming)
                .padding(.trailing)
            }
            .padding(.bottom, 8)
            .background(Color(.systemBackground))
        }
    }
    
    // Helper functions
    private func sendMessage() {
        guard !messageText.isEmpty, !viewModel.isStreaming else { return }
        
        // If there's no current conversation, create a new one
        if viewModel.currentConversation == nil {
            let defaultModel = AIModel(
                id: "default",
                name: "Default Model",
                provider: appState.selectedProvider == .none ? .openAI : AIModel.ModelProvider(rawValue: appState.selectedProvider.rawValue) ?? .openAI
            )
            viewModel.createNewConversation(title: "New Conversation", model: defaultModel)
        }
        
        // Send the message
        let message = messageText
        messageText = ""
        viewModel.sendMessage(message)
        
        // Unfocus the text field
        messageInputFocused = false
    }
    
    private func isLastMessage(_ message: Message) -> Bool {
        guard let messages = viewModel.currentConversation?.messages,
              let lastMessage = messages.last else {
            return false
        }
        
        return message.id == lastMessage.id
    }
    
    private var conversationTitle: String {
        viewModel.currentConversation?.title ?? "New Conversation"
    }
    
    private var modelIcon: String {
        if let provider = viewModel.currentConversation?.provider {
            switch provider {
            case .ollama:
                return "server.rack"
            case .openAI:
                return "brain"
            case .openRouter:
                return "network"
            }
        }
        return "bubble.left.and.text.bubble.right"
    }
}

struct ChatView_Previews: PreviewProvider {
    static var previews: some View {
        ChatView()
            .environmentObject(AppState())
    }
}