import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingAPIKeyView = false
    @State private var showingNetworkSettings = false
    @State private var showingAboutView = false
    @State private var showingHelpView = false
    @State private var showingPrivacySettings = false
    @State private var showingImportExport = false
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Appearance")) {
                    // Theme Settings
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
                    
                    // Text Size
                    HStack {
                        Text("Text Size")
                        Spacer()
                        Picker("Text Size", selection: $appState.textSize) {
                            Text("Small").tag(AppState.TextSize.small)
                            Text("Medium").tag(AppState.TextSize.medium)
                            Text("Large").tag(AppState.TextSize.large)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .frame(width: 180)
                    }
                    
                    // Chat Background
                    NavigationLink(destination: ChatBackgroundPicker()) {
                        HStack {
                            Text("Chat Background")
                            Spacer()
                            Circle()
                                .fill(appState.chatBackgroundColor)
                                .frame(width: 20, height: 20)
                        }
                    }
                }
                
                Section(header: Text("Providers")) {
                    // Ollama Settings
                    NavigationLink(destination: 
                        OllamaSettingsView()
                            .environmentObject(appState)
                    ) {
                        Label("Ollama Configuration", systemImage: "server.rack")
                    }
                    
                    // OpenAI Settings
                    NavigationLink(destination: Text("OpenAI Settings")) {
                        Label("OpenAI Configuration", systemImage: "brain")
                    }
                    
                    // OpenRouter Settings
                    NavigationLink(destination: Text("OpenRouter Settings")) {
                        Label("OpenRouter Configuration", systemImage: "network")
                    }
                    
                    // API Keys Management (more comprehensive view)
                    Button(action: {
                        showingAPIKeyView = true
                    }) {
                        Label("Manage API Keys", systemImage: "key.fill")
                    }
                }
                
                Section(header: Text("Conversations")) {
                    // Conversation History
                    NavigationLink(destination: Text("History Settings")) {
                        Label("Conversation History", systemImage: "clock.arrow.circlepath")
                    }
                    
                    // Import/Export
                    Button(action: {
                        showingImportExport = true
                    }) {
                        Label("Import/Export Conversations", systemImage: "square.and.arrow.up.on.square")
                    }
                    
                    // Defaults
                    NavigationLink(destination: Text("Default Model Settings")) {
                        Label("Default Model", systemImage: "gearshape")
                    }
                }
                
                Section(header: Text("Privacy & Security")) {
                    Button(action: {
                        showingPrivacySettings = true
                    }) {
                        Label("Privacy Settings", systemImage: "hand.raised.fill")
                    }
                    
                    // Data Storage Options
                    NavigationLink(destination: Text("Data Storage Settings")) {
                        Label("Data Storage", systemImage: "externaldrive.fill")
                    }
                    
                    // Network Security
                    Button(action: {
                        showingNetworkSettings = true
                    }) {
                        Label("Network Settings", systemImage: "network")
                    }
                }
                
                Section(header: Text("About")) {
                    Button(action: {
                        showingAboutView = true
                    }) {
                        Label("About Open WebUI", systemImage: "info.circle")
                    }
                    
                    Button(action: {
                        showingHelpView = true
                    }) {
                        Label("Help & Support", systemImage: "questionmark.circle")
                    }
                    
                    Link(destination: URL(string: "https://github.com/open-webui/open-webui")!) {
                        Label("GitHub Repository", systemImage: "link")
                    }
                    
                    // Version Info
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("0.1.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Settings")
        }
        .sheet(isPresented: $showingAPIKeyView) {
            APIKeyManagementView()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showingNetworkSettings) {
            NetworkSettingsView()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showingAboutView) {
            AboutView()
        }
        .sheet(isPresented: $showingHelpView) {
            HelpSupportView()
        }
        .sheet(isPresented: $showingPrivacySettings) {
            PrivacySettingsView()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showingImportExport) {
            ImportExportView()
                .environmentObject(appState)
        }
    }
}

struct ChatBackgroundPicker: View {
    @EnvironmentObject var appState: AppState
    
    let colors: [Color] = [
        .gray.opacity(0.2),
        .blue.opacity(0.1),
        .green.opacity(0.1),
        .purple.opacity(0.1),
        .pink.opacity(0.1),
        .orange.opacity(0.1),
        .yellow.opacity(0.1),
        .mint.opacity(0.1),
        .indigo.opacity(0.1),
        .teal.opacity(0.1)
    ]
    
    var body: some View {
        VStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 20) {
                    ForEach(0..<colors.count, id: \.self) { index in
                        ColorCircle(
                            color: colors[index],
                            isSelected: appState.chatBackgroundColor == colors[index]
                        )
                        .onTapGesture {
                            appState.chatBackgroundColor = colors[index]
                        }
                    }
                }
                .padding()
            }
            
            // Preview
            VStack {
                Text("Preview")
                    .font(.headline)
                    .padding(.top)
                
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(appState.chatBackgroundColor)
                    
                    VStack(spacing: 12) {
                        HStack {
                            Spacer()
                            Text("Hello, how can I help you today?")
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(16)
                                .padding(.trailing, 8)
                        }
                        
                        HStack {
                            Text("I need help with Swift programming.")
                                .padding()
                                .background(Color.accentColor.opacity(0.2))
                                .cornerRadius(16)
                                .padding(.leading, 8)
                            Spacer()
                        }
                    }
                    .padding()
                }
                .frame(height: 150)
                .padding()
            }
        }
        .navigationTitle("Chat Background")
    }
}

struct ColorCircle: View {
    let color: Color
    let isSelected: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: 60, height: 60)
                .shadow(radius: isSelected ? 3 : 0)
            
            if isSelected {
                Circle()
                    .stroke(Color.accentColor, lineWidth: 3)
                    .frame(width: 60, height: 60)
                
                Image(systemName: "checkmark")
                    .foregroundColor(.primary)
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(AppState())
    }
}