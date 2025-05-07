import SwiftUI

struct MessageRecoveryBanner: View {
    var resumeAction: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.yellow)
                
                Text("Interrupted response")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Button(action: resumeAction) {
                    Text("Resume")
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
            .padding(12)
            .background(Color.primary.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.yellow.opacity(0.5), lineWidth: 1)
            )
            .padding(.horizontal)
            .padding(.bottom, 8)
            
            Divider()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.easeInOut, value: true)
    }
}

struct MessageStatusIndicator: View {
    var status: Message.Status
    
    var body: some View {
        HStack(spacing: 4) {
            switch status {
            case .sending:
                ProgressView()
                    .scaleEffect(0.7)
                Text("Sending...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
            case .delivered:
                Image(systemName: "checkmark")
                    .font(.caption)
                    .foregroundColor(.green)
                
            case .failed:
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.red)
                Text("Failed")
                    .font(.caption)
                    .foregroundColor(.red)
                
            case .streaming:
                ProgressView()
                    .scaleEffect(0.7)
                Text("Generating...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
            case .partial:
                Image(systemName: "ellipsis.circle.fill")
                    .font(.caption)
                    .foregroundColor(.yellow)
                Text("Interrupted")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    VStack {
        MessageRecoveryBanner(resumeAction: {})
            .previewLayout(.sizeThatFits)
        
        VStack(spacing: 20) {
            MessageStatusIndicator(status: .sending)
            MessageStatusIndicator(status: .delivered)
            MessageStatusIndicator(status: .failed)
            MessageStatusIndicator(status: .streaming)
            MessageStatusIndicator(status: .partial)
        }
        .padding()
    }
}