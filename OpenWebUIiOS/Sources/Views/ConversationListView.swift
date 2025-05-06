import SwiftUI
import Combine

struct ConversationListView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = ConversationListViewModel()
    @State private var searchText = ""
    @State private var isShowingNewFolderDialog = false
    @State private var newFolderName = ""
    @State private var showingSortMenu = false
    @State private var editMode: EditMode = .inactive
    
    var body: some View {
        VStack(spacing: 0) {
            // Search and control bar
            HStack {
                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search conversations", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                }
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                
                // Sort button
                Button(action: {
                    showingSortMenu = true
                }) {
                    Image(systemName: "arrow.up.arrow.down")
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 4)
                
                // Edit button
                Button(action: {
                    withAnimation {
                        editMode = editMode == .active ? .inactive : .active
                    }
                }) {
                    Text(editMode == .active ? "Done" : "Edit")
                }
                .padding(.horizontal, 4)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            // Main content - folders and conversations
            List {
                // Pinned conversations section
                if !viewModel.pinnedConversations.isEmpty {
                    Section(header: Text("Pinned")) {
                        ForEach(filteredPinnedConversations) { conversation in
                            ConversationRow(
                                conversation: conversation,
                                isSelected: viewModel.selectedConversationId == conversation.id,
                                editMode: editMode
                            )
                            .onTapGesture {
                                viewModel.selectConversation(conversation)
                            }
                            .swipeActions {
                                swipeActionsForConversation(conversation)
                            }
                        }
                    }
                }
                
                // Folders section
                ForEach(viewModel.folders) { folder in
                    Section(header: folderHeader(folder)) {
                        ForEach(filteredConversationsInFolder(folder)) { conversation in
                            ConversationRow(
                                conversation: conversation,
                                isSelected: viewModel.selectedConversationId == conversation.id,
                                editMode: editMode
                            )
                            .onTapGesture {
                                viewModel.selectConversation(conversation)
                            }
                            .swipeActions {
                                swipeActionsForConversation(conversation)
                            }
                        }
                        .onDelete { indexSet in
                            deleteConversations(at: indexSet, in: folder)
                        }
                    }
                }
                
                // Uncategorized conversations
                Section(header: Text("Conversations")) {
                    ForEach(filteredUncategorizedConversations) { conversation in
                        ConversationRow(
                            conversation: conversation,
                            isSelected: viewModel.selectedConversationId == conversation.id,
                            editMode: editMode
                        )
                        .onTapGesture {
                            viewModel.selectConversation(conversation)
                        }
                        .swipeActions {
                            swipeActionsForConversation(conversation)
                        }
                    }
                    .onDelete { indexSet in
                        deleteConversations(at: indexSet, in: nil)
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .environment(\.editMode, $editMode)
            
            // Bottom toolbar
            HStack {
                // New folder button
                Button(action: {
                    isShowingNewFolderDialog = true
                }) {
                    Label("New Folder", systemImage: "folder.badge.plus")
                }
                
                Spacer()
                
                // New conversation button
                Button(action: {
                    viewModel.createNewConversation()
                }) {
                    Label("New Chat", systemImage: "square.and.pencil")
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundColor(Color(.systemGray4)),
                alignment: .top
            )
        }
        .onAppear {
            viewModel.loadConversations()
        }
        .confirmationDialog("Sort Conversations", isPresented: $showingSortMenu) {
            Button("Date (Newest First)") {
                viewModel.sortOrder = .dateDescending
            }
            
            Button("Date (Oldest First)") {
                viewModel.sortOrder = .dateAscending
            }
            
            Button("Name (A-Z)") {
                viewModel.sortOrder = .nameAscending
            }
            
            Button("Name (Z-A)") {
                viewModel.sortOrder = .nameDescending
            }
            
            Button("Cancel", role: .cancel) { }
        }
        .alert("New Folder", isPresented: $isShowingNewFolderDialog) {
            TextField("Folder Name", text: $newFolderName)
            
            Button("Cancel", role: .cancel) {
                newFolderName = ""
            }
            
            Button("Create") {
                if !newFolderName.isEmpty {
                    viewModel.createFolder(name: newFolderName)
                    newFolderName = ""
                }
            }
        } message: {
            Text("Enter a name for the new folder")
        }
    }
    
    // Helper function for folder header
    private func folderHeader(_ folder: Folder) -> some View {
        HStack {
            Text(folder.name)
            Spacer()
            
            if editMode == .active {
                Button(action: {
                    viewModel.deleteFolder(folder.id)
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            } else {
                Text("\(viewModel.conversationsInFolder(folder.id).count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color(.systemGray5))
                    .cornerRadius(8)
            }
        }
    }
    
    // Helper for swipe actions
    private func swipeActionsForConversation(_ conversation: Conversation) -> some View {
        Group {
            Button {
                viewModel.togglePinStatus(conversation)
            } label: {
                Label(conversation.isPinned ? "Unpin" : "Pin", systemImage: conversation.isPinned ? "pin.slash" : "pin")
            }
            .tint(.orange)
            
            Button {
                viewModel.showMoveToFolderDialog(for: conversation)
            } label: {
                Label("Move", systemImage: "folder")
            }
            .tint(.blue)
            
            Button(role: .destructive) {
                viewModel.deleteConversation(conversation.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    // Helper for deleting conversations from list
    private func deleteConversations(at offsets: IndexSet, in folder: Folder?) {
        let conversationsToDelete: [Conversation]
        
        if let folder = folder {
            conversationsToDelete = offsets.map { viewModel.conversationsInFolder(folder.id)[$0] }
        } else {
            conversationsToDelete = offsets.map { filteredUncategorizedConversations[$0] }
        }
        
        for conversation in conversationsToDelete {
            viewModel.deleteConversation(conversation.id)
        }
    }
    
    // Filtered conversations based on search
    private var filteredPinnedConversations: [Conversation] {
        if searchText.isEmpty {
            return viewModel.pinnedConversations
        } else {
            return viewModel.pinnedConversations.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    private func filteredConversationsInFolder(_ folder: Folder) -> [Conversation] {
        let conversations = viewModel.conversationsInFolder(folder.id)
        if searchText.isEmpty {
            return conversations
        } else {
            return conversations.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    private var filteredUncategorizedConversations: [Conversation] {
        if searchText.isEmpty {
            return viewModel.uncategorizedConversations
        } else {
            return viewModel.uncategorizedConversations.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
    }
}

// Conversation row view
struct ConversationRow: View {
    let conversation: Conversation
    let isSelected: Bool
    let editMode: EditMode
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    if conversation.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                    
                    Text(conversation.title)
                        .font(.headline)
                        .lineLimit(1)
                }
                
                HStack {
                    // Provider icon
                    Image(systemName: providerIcon(for: conversation.provider))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    // Date
                    Text(formattedDate(conversation.updatedAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Message count if available
                    if conversation.messages.count > 0 {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(conversation.messages.count) messages")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Tags if available
            if !conversation.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(conversation.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                }
                .frame(maxWidth: 100)
            }
        }
        .padding(.vertical, 4)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .contentShape(Rectangle())
    }
    
    private func providerIcon(for provider: Conversation.Provider) -> String {
        switch provider {
        case .ollama:
            return "server.rack"
        case .openAI:
            return "brain"
        case .openRouter:
            return "network"
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// View Model for Conversation List
class ConversationListViewModel: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var folders: [Folder] = []
    @Published var selectedConversationId: UUID?
    @Published var sortOrder: SortOrder = .dateDescending
    @Published var showMoveToFolderSheet = false
    @Published var conversationToMove: Conversation?
    
    private let storageService = StorageService()
    private var cancellables = Set<AnyCancellable>()
    
    enum SortOrder {
        case dateAscending
        case dateDescending
        case nameAscending
        case nameDescending
    }
    
    init() {
        // Load initial data
        loadConversations()
        loadFolders()
    }
    
    func loadConversations() {
        storageService.fetchConversations()
            .receive(on: DispatchQueue.main)
            .sink { _ in
                // Handle completion
            } receiveValue: { [weak self] fetchedConversations in
                self?.conversations = fetchedConversations
                self?.sortConversations()
            }
            .store(in: &cancellables)
    }
    
    func loadFolders() {
        // In a real implementation, this would call the storage service
        // For now, we'll use dummy folders
        folders = [
            Folder(id: UUID(), name: "Work", createdAt: Date()),
            Folder(id: UUID(), name: "Personal", createdAt: Date()),
            Folder(id: UUID(), name: "Research", createdAt: Date())
        ]
    }
    
    func selectConversation(_ conversation: Conversation) {
        selectedConversationId = conversation.id
    }
    
    func deleteConversation(_ id: UUID) {
        conversations.removeAll { $0.id == id }
        
        if selectedConversationId == id {
            selectedConversationId = nil
        }
        
        // In a real implementation, this would call the storage service
        // storageService.deleteConversation(id)...
    }
    
    func createNewConversation() {
        let newConversation = Conversation(
            title: "New Conversation",
            modelId: "default",
            provider: .openAI
        )
        
        conversations.append(newConversation)
        sortConversations()
        selectedConversationId = newConversation.id
        
        // In a real implementation, this would save to storage
        // storageService.saveConversation(newConversation)...
    }
    
    func togglePinStatus(_ conversation: Conversation) {
        if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
            conversations[index].isPinned.toggle()
            sortConversations()
            
            // In a real implementation, this would save to storage
            // storageService.saveConversation(conversations[index])...
        }
    }
    
    func createFolder(name: String) {
        let newFolder = Folder(id: UUID(), name: name, createdAt: Date())
        folders.append(newFolder)
        
        // In a real implementation, this would save to storage
        // storageService.saveFolder(newFolder)...
    }
    
    func deleteFolder(_ id: UUID) {
        // In a real app, you would handle reassigning conversations
        folders.removeAll { $0.id == id }
        
        // Remove folder assignment for any conversations in this folder
        for index in conversations.indices {
            if conversations[index].folderId == id {
                conversations[index].folderId = nil
            }
        }
        
        // In a real implementation, this would call the storage service
        // storageService.deleteFolder(id)...
    }
    
    func showMoveToFolderDialog(for conversation: Conversation) {
        conversationToMove = conversation
        showMoveToFolderSheet = true
        
        // In a real implementation, this would show a UI to select the folder
        // For now, we'll simulate moving to the first folder
        if let folder = folders.first {
            moveConversation(conversation, to: folder.id)
        }
    }
    
    func moveConversation(_ conversation: Conversation, to folderId: UUID?) {
        if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
            conversations[index].folderId = folderId
            
            // In a real implementation, this would save to storage
            // storageService.saveConversation(conversations[index])...
        }
    }
    
    // Helper to get all pinned conversations
    var pinnedConversations: [Conversation] {
        return conversations.filter { $0.isPinned }.sorted(by: sortComparator)
    }
    
    // Helper to get all conversations in a folder
    func conversationsInFolder(_ folderId: UUID) -> [Conversation] {
        return conversations
            .filter { $0.folderId == folderId && !$0.isPinned }
            .sorted(by: sortComparator)
    }
    
    // Helper to get all uncategorized conversations (not in a folder and not pinned)
    var uncategorizedConversations: [Conversation] {
        return conversations
            .filter { $0.folderId == nil && !$0.isPinned }
            .sorted(by: sortComparator)
    }
    
    // Sort conversations based on the current sort order
    private func sortConversations() {
        conversations.sort(by: sortComparator)
    }
    
    // Comparator for sorting based on current sort order
    private var sortComparator: (Conversation, Conversation) -> Bool {
        switch sortOrder {
        case .dateAscending:
            return { $0.updatedAt < $1.updatedAt }
        case .dateDescending:
            return { $0.updatedAt > $1.updatedAt }
        case .nameAscending:
            return { $0.title < $1.title }
        case .nameDescending:
            return { $0.title > $1.title }
        }
    }
}

// Folder model
struct Folder: Identifiable, Codable {
    var id: UUID
    var name: String
    var createdAt: Date
}

// Extend Conversation model with new properties
extension Conversation {
    var isPinned: Bool {
        get { return metadata["pinned"] == "true" }
        set { metadata["pinned"] = newValue ? "true" : "false" }
    }
    
    var folderId: UUID? {
        get {
            if let folderIdString = metadata["folderId"],
               let folderId = UUID(uuidString: folderIdString) {
                return folderId
            }
            return nil
        }
        set {
            metadata["folderId"] = newValue?.uuidString
        }
    }
    
    var tags: [String] {
        get {
            if let tagsString = metadata["tags"] {
                return tagsString.components(separatedBy: ",")
            }
            return []
        }
        set {
            metadata["tags"] = newValue.joined(separator: ",")
        }
    }
}

struct ConversationListView_Previews: PreviewProvider {
    static var previews: some View {
        ConversationListView()
            .environmentObject(AppState())
    }
}