import SwiftUI
import Combine

struct MessageOrganizationView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var conversation: Conversation
    @StateObject private var viewModel = MessageOrganizationViewModel()
    @State private var newTag = ""
    @State private var isShowingAddFolder = false
    
    var body: some View {
        NavigationView {
            Form {
                // Conversation details
                Section(header: Text("Details")) {
                    TextField("Conversation Title", text: $viewModel.title)
                    
                    Toggle("Pin Conversation", isOn: $viewModel.isPinned)
                }
                
                // Folder section
                Section(header: Text("Folder")) {
                    if viewModel.folders.isEmpty {
                        Text("No folders available")
                            .foregroundColor(.secondary)
                    } else {
                        Picker("Select Folder", selection: $viewModel.selectedFolderId) {
                            Text("None").tag(UUID?.none)
                            
                            ForEach(viewModel.folders) { folder in
                                Text(folder.name).tag(Optional(folder.id))
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                    
                    Button(action: {
                        isShowingAddFolder = true
                    }) {
                        Label("New Folder", systemImage: "folder.badge.plus")
                    }
                }
                
                // Tags section
                Section(header: Text("Tags")) {
                    // Current tags
                    if viewModel.tags.isEmpty {
                        Text("No tags added")
                            .foregroundColor(.secondary)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 8) {
                                ForEach(viewModel.tags, id: \.self) { tag in
                                    TagView(tag: tag) {
                                        viewModel.removeTag(tag)
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        .frame(height: 44)
                    }
                    
                    // Add new tag
                    HStack {
                        TextField("New Tag", text: $newTag)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Button(action: {
                            if !newTag.isEmpty {
                                viewModel.addTag(newTag)
                                newTag = ""
                            }
                        }) {
                            Text("Add")
                                .fontWeight(.semibold)
                        }
                        .disabled(newTag.isEmpty)
                    }
                    
                    // Suggested tags
                    if !viewModel.suggestedTags.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Suggested Tags")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 8) {
                                    ForEach(viewModel.suggestedTags, id: \.self) { tag in
                                        Button(action: {
                                            viewModel.addTag(tag)
                                        }) {
                                            Text(tag)
                                                .font(.caption)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 5)
                                                .background(Color.secondary.opacity(0.2))
                                                .cornerRadius(15)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Statistics section
                Section(header: Text("Statistics")) {
                    HStack {
                        Text("Created")
                        Spacer()
                        Text(formattedDate(viewModel.createdAt))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Last Updated")
                        Spacer()
                        Text(formattedDate(viewModel.updatedAt))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Message Count")
                        Spacer()
                        Text("\(viewModel.messageCount)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Model")
                        Spacer()
                        Text(viewModel.modelId)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Provider")
                        Spacer()
                        Text(viewModel.provider.rawValue)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Danger zone
                Section {
                    Button(action: {
                        viewModel.clearMessages()
                    }) {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                            Text("Clear Messages")
                                .foregroundColor(.red)
                        }
                    }
                    
                    Button(action: {
                        viewModel.deleteConversation()
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack {
                            Image(systemName: "trash.fill")
                                .foregroundColor(.red)
                            Text("Delete Conversation")
                                .foregroundColor(.red)
                        }
                    }
                }
                .listRowBackground(Color(.systemGray6))
            }
            .navigationTitle("Organize Conversation")
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Save") {
                    viewModel.saveChanges()
                    presentationMode.wrappedValue.dismiss()
                }
                .fontWeight(.semibold)
            )
            .onAppear {
                viewModel.initializeFromConversation(conversation)
            }
            .alert("New Folder", isPresented: $isShowingAddFolder) {
                TextField("Folder Name", text: $viewModel.newFolderName)
                Button("Cancel", role: .cancel) { }
                Button("Create") {
                    if !viewModel.newFolderName.isEmpty {
                        viewModel.createFolder()
                    }
                }
            } message: {
                Text("Enter a name for the new folder")
            }
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct TagView: View {
    let tag: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(tag)
                .font(.caption)
                .lineLimit(1)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.accentColor.opacity(0.2))
        .cornerRadius(15)
    }
}

class MessageOrganizationViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var isPinned: Bool = false
    @Published var selectedFolderId: UUID? = nil
    @Published var tags: [String] = []
    @Published var suggestedTags: [String] = []
    @Published var folders: [Folder] = []
    @Published var createdAt: Date = Date()
    @Published var updatedAt: Date = Date()
    @Published var messageCount: Int = 0
    @Published var modelId: String = ""
    @Published var provider: Conversation.Provider = .openAI
    @Published var newFolderName: String = ""
    
    private var conversationId: UUID?
    private var storageService = StorageService()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadFolders()
        suggestedTags = ["coding", "work", "personal", "research", "important"]
    }
    
    func initializeFromConversation(_ conversation: Conversation) {
        conversationId = conversation.id
        title = conversation.title
        isPinned = conversation.isPinned
        selectedFolderId = conversation.folderId
        tags = conversation.tags
        createdAt = conversation.createdAt
        updatedAt = conversation.updatedAt
        messageCount = conversation.messages.count
        modelId = conversation.modelId
        provider = conversation.provider
    }
    
    func loadFolders() {
        // In a real implementation, this would load folders from storage
        // For now, use dummy data
        folders = [
            Folder(id: UUID(), name: "Work", createdAt: Date()),
            Folder(id: UUID(), name: "Personal", createdAt: Date()),
            Folder(id: UUID(), name: "Research", createdAt: Date())
        ]
    }
    
    func addTag(_ tag: String) {
        if !tags.contains(tag) {
            tags.append(tag)
        }
    }
    
    func removeTag(_ tag: String) {
        if let index = tags.firstIndex(of: tag) {
            tags.remove(at: index)
        }
    }
    
    func createFolder() {
        let folder = Folder(id: UUID(), name: newFolderName, createdAt: Date())
        folders.append(folder)
        selectedFolderId = folder.id
        newFolderName = ""
        
        // In a real implementation, this would save to storage
        // storageService.saveFolder(folder)...
    }
    
    func saveChanges() {
        // In a real implementation, this would update the conversation in storage
        // For now, print the changes
        print("Saving changes for conversation \(conversationId?.uuidString ?? "unknown"):")
        print("Title: \(title)")
        print("Pinned: \(isPinned)")
        print("Folder: \(selectedFolderId?.uuidString ?? "none")")
        print("Tags: \(tags.joined(separator: ", "))")
    }
    
    func clearMessages() {
        // This would normally clear all messages except for system messages
        messageCount = 0
    }
    
    func deleteConversation() {
        // In a real implementation, this would delete the conversation from storage
        print("Deleting conversation \(conversationId?.uuidString ?? "unknown")")
    }
}

struct MessageOrganizationView_Previews: PreviewProvider {
    static var previews: some View {
        MessageOrganizationView(conversation: Conversation(
            title: "Sample Conversation",
            modelId: "gpt-4",
            provider: .openAI
        ))
    }
}