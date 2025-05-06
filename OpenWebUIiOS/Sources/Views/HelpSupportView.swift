import SwiftUI

struct HelpSupportView: View {
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Help & Support")
                        .font(.largeTitle)
                        .bold()
                    
                    Text("Get the most out of Open WebUI")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom)
                
                // Getting Started section
                sectionHeader("Getting Started")
                
                helpCard(
                    title: "Connecting to Ollama",
                    description: "Learn how to connect to a local Ollama server and use local LLMs.",
                    icon: "server.rack",
                    actionText: "View Guide"
                ) {
                    // This would open a detailed guide view
                }
                
                helpCard(
                    title: "Using API Keys",
                    description: "Securely add and manage API keys for cloud services like OpenAI and OpenRouter.",
                    icon: "key",
                    actionText: "View Guide"
                ) {
                    // This would open a detailed guide view
                }
                
                helpCard(
                    title: "Managing Conversations",
                    description: "Learn how to organize, search, and export your conversations.",
                    icon: "folder",
                    actionText: "View Guide"
                ) {
                    // This would open a detailed guide view
                }
                
                // Troubleshooting section
                sectionHeader("Troubleshooting")
                
                helpCard(
                    title: "Connection Issues",
                    description: "Resolve common connection problems with Ollama and cloud providers.",
                    icon: "wifi.exclamationmark",
                    actionText: "View Solutions"
                ) {
                    // This would open a detailed guide view
                }
                
                helpCard(
                    title: "Performance Optimization",
                    description: "Tips for improving response times and app performance.",
                    icon: "speedometer",
                    actionText: "View Tips"
                ) {
                    // This would open a detailed guide view
                }
                
                // Resources section
                sectionHeader("Resources")
                
                helpCard(
                    title: "Ollama Documentation",
                    description: "Official Ollama documentation and guides.",
                    icon: "doc.text",
                    actionText: "Visit Website"
                ) {
                    openURL(URL(string: "https://ollama.com/docs")!)
                }
                
                helpCard(
                    title: "Open WebUI GitHub",
                    description: "Source code, issues, and documentation for Open WebUI.",
                    icon: "chevron.left.forwardslash.chevron.right",
                    actionText: "Visit GitHub"
                ) {
                    openURL(URL(string: "https://github.com/open-webui/open-webui")!)
                }
                
                helpCard(
                    title: "Contact Support",
                    description: "Get help from the Open WebUI community.",
                    icon: "person.2",
                    actionText: "Join Discord"
                ) {
                    openURL(URL(string: "https://discord.gg/5rJgQTnV4y")!)
                }
                
                // About the app section
                sectionHeader("About This App")
                
                Text("Open WebUI iOS is a native iOS application project aimed at recreating the Open WebUI experience for iOS devices. The goal is to provide a visually identical and functionally equivalent interface to the web-based Open WebUI, allowing users to interact with both local LLM models via Ollama and cloud-based AI services.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding(.bottom)
                
                Text("This app is open source and community-driven. Contributions, bug reports, and feature requests are welcome on GitHub.")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .navigationTitle("Help & Support")
    }
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.title2)
            .bold()
            .padding(.vertical, 8)
    }
    
    private func helpCard(title: String, description: String, icon: String, actionText: String, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.accentColor)
                    .frame(width: 24, height: 24)
                
                Text(title)
                    .font(.headline)
            }
            
            Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button(action: action) {
                HStack {
                    Text(actionText)
                    Image(systemName: "arrow.right")
                        .font(.caption)
                }
                .font(.subheadline)
                .foregroundColor(.accentColor)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct HelpSupportView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            HelpSupportView()
        }
    }
}