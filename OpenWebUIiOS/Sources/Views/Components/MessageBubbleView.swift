import SwiftUI

struct MessageBubbleView: View {
    let message: Message
    let isLastMessage: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                // Avatar
                Avatar(role: message.role)
                
                // Message content
                VStack(alignment: .leading, spacing: 4) {
                    // Role label
                    Text(roleLabel)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Message content with markdown support
                    MarkdownView(
                        text: message.content,
                        isStreaming: message.status == .streaming
                    )
                    
                    // Timestamp
                    HStack {
                        Spacer()
                        Text(formattedTimestamp)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(backgroundColor)
            .cornerRadius(12)
            
            // Status indicator for assistant messages
            if message.role == .assistant {
                statusIndicator
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
    
    private var roleLabel: String {
        switch message.role {
        case .user:
            return "You"
        case .assistant:
            return "Assistant"
        case .system:
            return "System"
        }
    }
    
    private var backgroundColor: Color {
        switch message.role {
        case .user:
            return Color(.systemBlue).opacity(0.1)
        case .assistant:
            return Color(.systemGray6)
        case .system:
            return Color(.systemGray).opacity(0.2)
        }
    }
    
    private var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: message.timestamp)
    }
    
    private var statusIndicator: some View {
        HStack {
            Spacer()
            
            switch message.status {
            case .sending:
                HStack(spacing: 4) {
                    Text("Thinking")
                    ProgressView()
                        .scaleEffect(0.6)
                }
                .font(.caption)
                .foregroundColor(.secondary)
                
            case .streaming:
                HStack(spacing: 4) {
                    Text("Generating")
                    
                    // Animated dots for streaming indication
                    HStack(spacing: 2) {
                        ForEach(0..<3) { i in
                            Circle()
                                .fill(Color.secondary)
                                .frame(width: 3, height: 3)
                                .opacity(0.5)
                                .animation(
                                    Animation
                                        .easeInOut(duration: 0.5)
                                        .repeatForever()
                                        .delay(0.2 * Double(i)),
                                    value: isLastMessage
                                )
                        }
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
                
            case .delivered:
                EmptyView()
                
            case .failed:
                Text("Failed to generate response")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
}

// Avatar view for message bubbles
struct Avatar: View {
    let role: Message.Role
    
    var body: some View {
        Group {
            switch role {
            case .user:
                Image(systemName: "person.circle.fill")
                    .font(.title)
                    .foregroundColor(.blue)
            case .assistant:
                Image(systemName: "brain.head.profile")
                    .font(.title)
                    .foregroundColor(.purple)
            case .system:
                Image(systemName: "gear.circle.fill")
                    .font(.title)
                    .foregroundColor(.gray)
            }
        }
        .frame(width: 36, height: 36)
    }
}

// CodeBlockView for displaying code with syntax highlighting
struct CodeBlockView: View {
    let code: String
    let language: String
    @Binding var isExpanded: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(language)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: {
                    // Copy code to clipboard
                    UIPasteboard.general.string = code
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(BorderlessButtonStyle())
                
                Button(action: {
                    withAnimation {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
            
            if isExpanded {
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(code)
                        .font(.system(.body, design: .monospaced))
                        .padding(8)
                }
                .background(Color(.systemGray5))
                .cornerRadius(8)
            }
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// Preview provider
struct MessageBubbleView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            MessageBubbleView(
                message: Message(
                    content: "Hello, how can I help you today?",
                    role: .assistant,
                    status: .delivered
                ),
                isLastMessage: false
            )
            
            MessageBubbleView(
                message: Message(
                    content: "Can you write a function to calculate factorial?",
                    role: .user
                ),
                isLastMessage: false
            )
            
            MessageBubbleView(
                message: Message(
                    content: "Here's a factorial function in Swift:\n\n```swift\nfunc factorial(_ n: Int) -> Int {\n    if n <= 1 {\n        return 1\n    }\n    return n * factorial(n - 1)\n}\n```\n\nYou can call it like this: `let result = factorial(5)`",
                    role: .assistant
                ),
                isLastMessage: true
            )
            
            MessageBubbleView(
                message: Message(
                    content: "",
                    role: .assistant,
                    status: .streaming
                ),
                isLastMessage: true
            )
        }
        .padding()
    }
}