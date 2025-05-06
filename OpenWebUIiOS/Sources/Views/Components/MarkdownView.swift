import SwiftUI

struct MarkdownView: View {
    let text: String
    let isStreaming: Bool
    
    // For the cursor blink animation when streaming
    @State private var showCursor: Bool = true
    
    // State variables for code block extraction
    @State private var codeBlocks: [CodeBlock] = []
    
    // Represents a code block with language and content
    struct CodeBlock: Identifiable {
        let id = UUID()
        let language: String
        let code: String
        var isExpanded: Bool = true
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if text.isEmpty && isStreaming {
                // Show blinking cursor for empty streaming message
                HStack(spacing: 0) {
                    Text("▋")
                        .opacity(showCursor ? 1 : 0)
                        .animation(Animation.easeInOut(duration: 0.6).repeatForever(), value: showCursor)
                        .onAppear {
                            showCursor.toggle()
                        }
                }
            } else {
                // Parse and display the markdown content
                parsedContent
                
                // Show blinking cursor at the end when streaming
                if isStreaming {
                    Text("▋")
                        .opacity(showCursor ? 1 : 0)
                        .animation(Animation.easeInOut(duration: 0.6).repeatForever(), value: showCursor)
                        .onAppear {
                            showCursor.toggle()
                        }
                }
            }
        }
        .onAppear {
            parseCodeBlocks()
        }
        .onChange(of: text) { _ in
            parseCodeBlocks()
        }
    }
    
    private var parsedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            let segments = splitIntoSegments()
            
            ForEach(0..<segments.count, id: \.self) { index in
                let segment = segments[index]
                
                if segment.isCodeBlock {
                    if let codeBlock = segment.codeBlock {
                        CodeBlockView(
                            code: codeBlock.code,
                            language: codeBlock.language,
                            isExpanded: .constant(codeBlock.isExpanded)
                        )
                    }
                } else {
                    // Regular text segment
                    Text(LocalizedStringKey(parseInlineMarkdown(segment.text)))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
    
    // Split text into segments of regular text and code blocks
    private func splitIntoSegments() -> [TextSegment] {
        var segments: [TextSegment] = []
        
        // If no code blocks, just return the whole text as one segment
        if codeBlocks.isEmpty {
            return [TextSegment(text: text, isCodeBlock: false, codeBlock: nil)]
        }
        
        var currentIndex = text.startIndex
        
        // For each code block found, create segments before and including the code block
        for codeBlock in codeBlocks {
            // Find where this code block starts in the original text
            if let start = text.range(of: "```\(codeBlock.language)", range: currentIndex..<text.endIndex)?.lowerBound,
               let end = text.range(of: "```", range: start..<text.endIndex)?.upperBound,
               start >= currentIndex {
                
                // Add text segment before code block if there is any
                if start > currentIndex {
                    let beforeText = String(text[currentIndex..<start])
                    if !beforeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        segments.append(TextSegment(text: beforeText, isCodeBlock: false, codeBlock: nil))
                    }
                }
                
                // Add the code block segment
                segments.append(TextSegment(text: "", isCodeBlock: true, codeBlock: codeBlock))
                
                // Update current index to after this code block
                currentIndex = end
            }
        }
        
        // Add any remaining text after the last code block
        if currentIndex < text.endIndex {
            let remainingText = String(text[currentIndex..<text.endIndex])
            if !remainingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                segments.append(TextSegment(text: remainingText, isCodeBlock: false, codeBlock: nil))
            }
        }
        
        return segments
    }
    
    // Extract code blocks from the text
    private func parseCodeBlocks() {
        var newCodeBlocks: [CodeBlock] = []
        var searchRange = text.startIndex..<text.endIndex
        
        // Find all code blocks using regex pattern
        while let blockStart = text.range(of: "```", range: searchRange),
              let languageEndNewline = text.range(of: "\n", range: blockStart.upperBound..<text.endIndex),
              let blockEnd = text.range(of: "```", range: languageEndNewline.upperBound..<text.endIndex) {
            
            // Extract language identifier
            let languageRange = blockStart.upperBound..<languageEndNewline.lowerBound
            let language = String(text[languageRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Extract code content
            let codeRange = languageEndNewline.upperBound..<blockEnd.lowerBound
            let code = String(text[codeRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Add to code blocks
            newCodeBlocks.append(CodeBlock(language: language, code: code))
            
            // Update search range for next iteration
            searchRange = blockEnd.upperBound..<text.endIndex
        }
        
        self.codeBlocks = newCodeBlocks
    }
    
    // Parse inline markdown like bold, italic, etc.
    private func parseInlineMarkdown(_ text: String) -> String {
        // This is a simplified implementation
        // In a production app, you would use a proper markdown parser
        // or a library like MarkdownUI
        
        // Convert ** to bold tags
        var result = text.replacingOccurrences(of: "\\*\\*(.*?)\\*\\*", with: "**$1**", options: .regularExpression)
        
        // Convert * to italic tags
        result = result.replacingOccurrences(of: "\\*(.*?)\\*", with: "*$1*", options: .regularExpression)
        
        // Convert ` to code tags
        result = result.replacingOccurrences(of: "`(.*?)`", with: "`$1`", options: .regularExpression)
        
        // Links [text](url) - for a real implementation you'd handle this better
        result = result.replacingOccurrences(of: "\\[(.*?)\\]\\((.*?)\\)", with: "[$1]($2)", options: .regularExpression)
        
        return result
    }
}

// Represents a segment of text which is either a code block or regular text
struct TextSegment {
    let text: String
    let isCodeBlock: Bool
    let codeBlock: MarkdownView.CodeBlock?
}

// Preview
struct MarkdownView_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 20) {
                MarkdownView(
                    text: "This is a **bold** statement with *italic* words and `inline code`.\n\nHere's a code block:\n\n```swift\nfunc hello() {\n    print(\"Hello, world!\")\n}\n```\n\nAnd some more text after the code block.",
                    isStreaming: false
                )
                .padding()
                
                Divider()
                
                MarkdownView(
                    text: "This is a streaming response...",
                    isStreaming: true
                )
                .padding()
                
                Divider()
                
                MarkdownView(
                    text: "",
                    isStreaming: true
                )
                .padding()
            }
        }
    }
}