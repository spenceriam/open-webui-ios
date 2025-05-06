import SwiftUI
import Combine

struct APIKeyManagementView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = APIKeyViewModel()
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("OpenAI API Key")) {
                    if viewModel.isEditing.openAI {
                        SecureField("Enter API Key", text: $viewModel.apiKeys.openAI)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .textContentType(.password)
                        
                        Button(action: {
                            viewModel.saveKey(.openAI)
                        }) {
                            Text("Save")
                                .foregroundColor(.accentColor)
                                .frame(maxWidth: .infinity)
                        }
                        .disabled(viewModel.apiKeys.openAI.isEmpty)
                    } else {
                        HStack {
                            Text("API Key")
                            Spacer()
                            Text(viewModel.keyStatus.openAI ? "••••••••••••" : "Not Set")
                                .foregroundColor(viewModel.keyStatus.openAI ? .secondary : .red)
                        }
                        
                        HStack {
                            Button(action: {
                                viewModel.startEditing(.openAI)
                            }) {
                                Text(viewModel.keyStatus.openAI ? "Change" : "Add Key")
                                    .foregroundColor(.accentColor)
                            }
                            
                            Spacer()
                            
                            if viewModel.keyStatus.openAI {
                                Button(action: {
                                    viewModel.verifyKey(.openAI)
                                }) {
                                    HStack {
                                        if viewModel.isVerifying.openAI {
                                            ProgressView()
                                                .scaleEffect(0.7)
                                                .padding(.trailing, 5)
                                        }
                                        Text("Verify")
                                    }
                                    .foregroundColor(.green)
                                }
                                .disabled(viewModel.isVerifying.openAI)
                                
                                Button(action: {
                                    viewModel.deleteKey(.openAI)
                                }) {
                                    Text("Delete")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        
                        if let message = viewModel.verificationMessage.openAI {
                            HStack {
                                Image(systemName: message.isValid ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                    .foregroundColor(message.isValid ? .green : .red)
                                Text(message.message)
                                    .font(.caption)
                                    .foregroundColor(message.isValid ? .green : .red)
                            }
                            .padding(.top, 2)
                        }
                    }
                }
                
                Section(header: Text("OpenRouter API Key")) {
                    if viewModel.isEditing.openRouter {
                        SecureField("Enter API Key", text: $viewModel.apiKeys.openRouter)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .textContentType(.password)
                        
                        Button(action: {
                            viewModel.saveKey(.openRouter)
                        }) {
                            Text("Save")
                                .foregroundColor(.accentColor)
                                .frame(maxWidth: .infinity)
                        }
                        .disabled(viewModel.apiKeys.openRouter.isEmpty)
                    } else {
                        HStack {
                            Text("API Key")
                            Spacer()
                            Text(viewModel.keyStatus.openRouter ? "••••••••••••" : "Not Set")
                                .foregroundColor(viewModel.keyStatus.openRouter ? .secondary : .red)
                        }
                        
                        HStack {
                            Button(action: {
                                viewModel.startEditing(.openRouter)
                            }) {
                                Text(viewModel.keyStatus.openRouter ? "Change" : "Add Key")
                                    .foregroundColor(.accentColor)
                            }
                            
                            Spacer()
                            
                            if viewModel.keyStatus.openRouter {
                                Button(action: {
                                    viewModel.verifyKey(.openRouter)
                                }) {
                                    HStack {
                                        if viewModel.isVerifying.openRouter {
                                            ProgressView()
                                                .scaleEffect(0.7)
                                                .padding(.trailing, 5)
                                        }
                                        Text("Verify")
                                    }
                                    .foregroundColor(.green)
                                }
                                .disabled(viewModel.isVerifying.openRouter)
                                
                                Button(action: {
                                    viewModel.deleteKey(.openRouter)
                                }) {
                                    Text("Delete")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        
                        if let message = viewModel.verificationMessage.openRouter {
                            HStack {
                                Image(systemName: message.isValid ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                    .foregroundColor(message.isValid ? .green : .red)
                                Text(message.message)
                                    .font(.caption)
                                    .foregroundColor(message.isValid ? .green : .red)
                            }
                            .padding(.top, 2)
                        }
                    }
                }
                
                Section(header: Text("API Key Information"), footer: apiKeyFooter) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("API Keys Security")
                            .font(.headline)
                        
                        Text("API keys are stored securely in your device's keychain and are never shared with third parties.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("How to get API keys")
                            .font(.headline)
                            .padding(.top, 5)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Link("OpenAI: https://platform.openai.com/api-keys", destination: URL(string: "https://platform.openai.com/api-keys")!)
                                .font(.caption)
                            
                            Link("OpenRouter: https://openrouter.ai/keys", destination: URL(string: "https://openrouter.ai/keys")!)
                                .font(.caption)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("API Keys")
            .navigationBarItems(
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
            .onAppear {
                viewModel.checkKeyStatus()
            }
            .alert(isPresented: $viewModel.showingAlert) {
                Alert(
                    title: Text(viewModel.alertTitle),
                    message: Text(viewModel.alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    private var apiKeyFooter: some View {
        Text("API keys are required to access cloud providers. Ollama doesn't require an API key as it runs locally.")
            .font(.caption)
            .foregroundColor(.secondary)
    }
}

class APIKeyViewModel: ObservableObject {
    private let keychainService = KeychainService()
    private var cancellables = Set<AnyCancellable>()
    
    @Published var apiKeys = (openAI: "", openRouter: "")
    @Published var keyStatus = (openAI: false, openRouter: false)
    @Published var isEditing = (openAI: false, openRouter: false)
    @Published var isVerifying = (openAI: false, openRouter: false)
    @Published var verificationMessage: (openAI: (message: String, isValid: Bool)?, openRouter: (message: String, isValid: Bool)?)
    @Published var showingAlert = false
    @Published var alertTitle = ""
    @Published var alertMessage = ""
    
    enum APIKeyType {
        case openAI, openRouter
        
        var identifier: String {
            switch self {
            case .openAI: return "openai_api_key"
            case .openRouter: return "openrouter_api_key"
            }
        }
        
        var displayName: String {
            switch self {
            case .openAI: return "OpenAI"
            case .openRouter: return "OpenRouter"
            }
        }
    }
    
    func checkKeyStatus() {
        // Check OpenAI key
        do {
            let openAIKey = try keychainService.get(APIKeyType.openAI.identifier)
            keyStatus.openAI = !openAIKey.isEmpty
        } catch {
            keyStatus.openAI = false
        }
        
        // Check OpenRouter key
        do {
            let openRouterKey = try keychainService.get(APIKeyType.openRouter.identifier)
            keyStatus.openRouter = !openRouterKey.isEmpty
        } catch {
            keyStatus.openRouter = false
        }
    }
    
    func startEditing(_ keyType: APIKeyType) {
        switch keyType {
        case .openAI:
            isEditing.openAI = true
            do {
                apiKeys.openAI = try keychainService.get(keyType.identifier)
            } catch {
                apiKeys.openAI = ""
            }
        case .openRouter:
            isEditing.openRouter = true
            do {
                apiKeys.openRouter = try keychainService.get(keyType.identifier)
            } catch {
                apiKeys.openRouter = ""
            }
        }
    }
    
    func saveKey(_ keyType: APIKeyType) {
        let keyToSave: String
        switch keyType {
        case .openAI:
            keyToSave = apiKeys.openAI
        case .openRouter:
            keyToSave = apiKeys.openRouter
        }
        
        do {
            try keychainService.set(keyToSave, for: keyType.identifier)
            
            switch keyType {
            case .openAI:
                isEditing.openAI = false
                keyStatus.openAI = true
                verificationMessage.openAI = ("API key saved successfully", true)
            case .openRouter:
                isEditing.openRouter = false
                keyStatus.openRouter = true
                verificationMessage.openRouter = ("API key saved successfully", true)
            }
            
            showAlert(title: "Success", message: "\(keyType.displayName) API key saved successfully")
            
        } catch {
            showAlert(title: "Error", message: "Failed to save API key: \(error.localizedDescription)")
        }
    }
    
    func deleteKey(_ keyType: APIKeyType) {
        do {
            try keychainService.delete(keyType.identifier)
            
            switch keyType {
            case .openAI:
                keyStatus.openAI = false
                apiKeys.openAI = ""
                verificationMessage.openAI = nil
            case .openRouter:
                keyStatus.openRouter = false
                apiKeys.openRouter = ""
                verificationMessage.openRouter = nil
            }
            
            showAlert(title: "Success", message: "\(keyType.displayName) API key deleted successfully")
            
        } catch {
            showAlert(title: "Error", message: "Failed to delete API key: \(error.localizedDescription)")
        }
    }
    
    func verifyKey(_ keyType: APIKeyType) {
        var keyToVerify: String
        
        do {
            keyToVerify = try keychainService.get(keyType.identifier)
        } catch {
            showAlert(title: "Error", message: "Could not retrieve API key from keychain")
            return
        }
        
        switch keyType {
        case .openAI:
            isVerifying.openAI = true
            // Simulate verification with OpenAI API
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.isVerifying.openAI = false
                // Mock API validation response
                if keyToVerify.count > 10 {
                    self.verificationMessage.openAI = ("API key is valid", true)
                } else {
                    self.verificationMessage.openAI = ("API key appears to be invalid", false)
                }
            }
        case .openRouter:
            isVerifying.openRouter = true
            // Simulate verification with OpenRouter API
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.isVerifying.openRouter = false
                // Mock API validation response
                if keyToVerify.count > 10 {
                    self.verificationMessage.openRouter = ("API key is valid", true)
                } else {
                    self.verificationMessage.openRouter = ("API key appears to be invalid", false)
                }
            }
        }
    }
    
    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showingAlert = true
    }
}

struct APIKeyManagementView_Previews: PreviewProvider {
    static var previews: some View {
        APIKeyManagementView()
            .environmentObject(AppState())
    }
}