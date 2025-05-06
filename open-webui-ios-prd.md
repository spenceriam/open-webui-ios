# Product Requirements Document: Open-WebUI for iOS

## 1. Product Overview

### 1.1 Product Vision
Create a native iOS application that faithfully recreates the Open-WebUI experience for mobile devices, providing users with a visually identical and functionally equivalent interface to interact with both local LLM models via Ollama and cloud-based AI services (OpenAI, OpenRouter, and later Google and Anthropic). The app will enable iOS users to leverage the power of AI models while maintaining control over their data and privacy through local model options, all within an interface that feels like a direct port of the web experience they're already familiar with.

### 1.2 Target Users
- AI enthusiasts who want to use various LLM models on their iOS devices
- Privacy-conscious users who prefer running AI models locally
- Developers testing and comparing different AI models
- Individuals seeking a unified interface for both local and cloud AI models
- Users with limited connectivity who need offline AI capabilities

### 1.3 Value Proposition
- Unified interface for accessing multiple AI providers
- Privacy-first approach with local model support
- Advanced chat features similar to Open-WebUI
- iOS-native experience with mobile-optimized UI
- Connectivity to both local network Ollama instances and cloud providers

## 2. Functional Requirements

### 2.1 Core Features (Phase 1)

#### 2.1.1 Model Connectivity
- Connect to Ollama instances running on the local network
- Direct integration with OpenAI API using user-provided API keys
- Integration with OpenRouter API using user-provided API keys
- Dynamic switching between different AI providers
- Model parameter customization (temperature, top_p, etc.)

#### 2.1.2 Chat Interface
- Multi-turn conversations with context retention
- Markdown and code syntax highlighting
- Code block rendering with copy functionality
- Message organization with folders/tags
- Real-time streaming responses
- Conversation history management
- Conversation export/import

#### 2.1.3 Ollama Integration
- Network discovery of Ollama instances
- Model selection from available Ollama models
- Pull/download model capability
- Model parameter customization
- Ollama model information display

#### 2.1.4 Security & Privacy
- Secure API key storage using iOS Keychain
- End-to-end encryption for network communications
- Option to keep conversations local-only
- Transparency about data usage and storage

### 2.2 Advanced Features (Phase 2)

#### 2.2.1 Additional Provider Integrations
- Google Gemini API integration
- Anthropic Claude API integration
- Provider comparison tools

#### 2.2.2 Enhanced Capabilities
- Image generation support (DALL-E, Stable Diffusion)
- Voice input and output
- Document RAG (Retrieval Augmented Generation)
- Function calling support
- Chat with multiple models simultaneously

## 3. Non-Functional Requirements

### 3.1 Performance
- Response streaming should start within 1 second
- App should launch within 3 seconds
- Low memory footprint (<200MB baseline)
- Battery consumption optimization
- Support for background processing of long responses

### 3.2 Usability
- Intuitive UI following iOS Human Interface Guidelines
- Dark/light mode support
- Dynamic text sizing for accessibility
- Support for VoiceOver and other iOS accessibility features
- Intuitive onboarding experience

### 3.3 Compatibility
- Support iOS 16.0 and above
- Optimize for both iPhone and iPad (Universal app)
- Support for landscape and portrait orientations
- Adaptable layouts for different screen sizes

### 3.4 Security
- HTTPS for all network communications
- Local encryption of conversation history
- Secure storage of API keys in iOS Keychain
- Privacy-focused analytics (opt-in only)

## 4. Technical Architecture

### 4.1 App Architecture
- SwiftUI for UI components
- MVVM architecture pattern
- Combine framework for reactive programming
- Swift concurrency (async/await) for asynchronous operations
- Core Data for local storage
- URLSession for network requests

### 4.2 Key Components

#### 4.2.1 Network Module
- REST API clients for different providers
- WebSocket implementation for streaming responses
- Network service discovery (Bonjour/mDNS) for Ollama
- Request/response interceptors for logging and error handling

#### 4.2.2 Storage Module
- Secure API key management
- Conversation history persistence
- User preferences storage
- Model metadata caching

#### 4.2.3 UI Module
- Chat interface components
- Settings and configuration screens
- Model selection interface
- Response rendering components

## 5. User Interface

### 5.1 Design Philosophy
The app should closely mirror the Open-WebUI web interface while optimizing for iOS devices. The design approach prioritizes:

- Visual consistency with the web version of Open-WebUI
- Familiar interaction patterns for users of the web interface
- iOS native feel for system interactions and animations
- Adaptations for touch interfaces and mobile screen sizes
- Consistent theming (light/dark modes, accent colors)

### 5.2 Key Screens

#### 5.2.1 Chat Interface
- Layout mirroring Open-WebUI's chat interface with iOS optimizations:
  - Left sidebar for conversation list (collapsible on iPhone)
  - Main chat area with message bubbles styled like Open-WebUI
  - Bottom input area with identical controls to web version
- Real-time streaming text rendering identical to web experience
- Code blocks with same syntax highlighting and copy button
- Model information display in the header
- Parameter adjustment panel accessible via swipe or button

#### 5.2.2 Model Selection
- Visual design matching Open-WebUI's model selection interface:
  - Provider categories in tabs (Local, OpenAI, OpenRouter, etc.)
  - Model cards with identical styling to web version
  - Parameter customization panel with sliders and inputs
  - Same iconography and visual language

#### 5.2.3 Settings
- Maintain Open-WebUI's settings organization and hierarchy:
  - API key management with similar form elements
  - Network configuration panel for Ollama
  - Identical theme options (light, dark, system)
  - Same privacy controls and data settings
  - Import/export functionality with consistent UI

#### 5.2.4 Conversation Management
- Sidebar design matching Open-WebUI:
  - Conversation list with same information architecture
  - Identical folder/tag organization system
  - Search interface with matching functionality
  - Same conversation options menu (rename, export, delete)

### 5.3 User Flows

#### 5.3.1 Initial Setup
1. App installation
2. Welcome screens explaining key features (styled like Open-WebUI onboarding)
3. Configuration of first provider (Ollama or cloud)
4. (Optional) API key entry for cloud providers with identical form design
5. Network permission requests

#### 5.3.2 Starting a Conversation
1. Select conversation type or continue existing (using sidebar identical to web version)
2. Choose AI model provider and specific model (using same selection UI)
3. Set model parameters with identical controls and default values
4. Begin conversation

#### 5.3.3 Layout Adaptations
1. iPhone Portrait: Collapsible sidebar with swipe gestures to reveal/hide
2. iPhone Landscape: Optional split view with resizable sidebar
3. iPad: Persistent sidebar and chat area similar to web layout
4. Dynamic type support while maintaining Open-WebUI aesthetic

### 5.4 Visual Reference
The app should use the Open-WebUI GitHub repository as a direct visual reference, adopting:
- Identical color schemes and theming
- Same iconography and visual elements
- Matching typography (adapted for iOS readability)
- Similar spacing and layout proportions
- Identical markdown and code rendering

## 6. Implementation Plan

### 6.1 Phase 1 (MVP)
- iOS app shell with basic UI
- Ollama connectivity via local network
- OpenAI API integration
- OpenRouter API integration
- Basic chat functionality
- Conversation history
- Essential settings

### 6.2 Phase 2
- Google and Anthropic API integrations
- Enhanced UI with advanced features
- Document RAG functionality
- Voice input/output
- Image generation support
- Multi-model conversations

### 6.3 Future Enhancements
- Apple Vision Pro support
- Apple Watch companion app
- Shortcuts integration
- iPad-specific optimizations
- Advanced prompt templates
- Custom function calling

## 7. API Specifications

### 7.1 Ollama API
- Base URL format: `http://{host}:{port}/api`
- Key endpoints:
  - `/chat`: For chat completions
  - `/generate`: For text generation
  - `/embeddings`: For creating embeddings
  - `/tags`: For listing available models
  - `/pull`: For downloading models

### 7.2 OpenAI API
- Base URL: `https://api.openai.com/v1`
- Key endpoints:
  - `/chat/completions`: For chat completions
  - `/models`: For listing available models
  - `/images/generations`: For image generation (Phase 2)

### 7.3 OpenRouter API
- Base URL: `https://openrouter.ai/api/v1`
- Similar endpoints to OpenAI with model routing capabilities

## 8. Security and Data Privacy

### 8.1 API Key Handling
- Store API keys in iOS Keychain
- Never log or export API keys
- Option to require biometric authentication for accessing keys

### 8.2 Conversation Data
- Store conversations in encrypted local database
- Optional iCloud sync with encryption
- Clear options for data deletion
- No analytics or data collection without explicit consent

### 8.3 Network Security
- Certificate pinning for cloud API connections
- Secure local network discovery
- Request/response encryption

## 9. Testing Strategy

### 9.1 Unit Testing
- API client behavior
- Data persistence
- UI component rendering
- Model parameter handling

### 9.2 Integration Testing
- End-to-end conversation flows
- Provider switching
- Network error handling
- Persistence across app restarts

### 9.3 User Testing
- Usability testing with AI enthusiasts
- Performance testing on various iOS devices
- Beta testing through TestFlight

## 10. Metrics and Success Criteria

### 10.1 Performance Metrics
- Average response time
- App launch time
- Memory usage
- Battery consumption

### 10.2 User Metrics
- Daily/monthly active users
- Conversation length and depth
- Model usage distribution
- Feature adoption rates

### 10.3 Success Criteria
- Stable app with < 1% crash rate
- Average App Store rating > 4.5
- Growing user base month-over-month
- High engagement with multiple conversation turns

## 11. Technical Implementation Notes

### 11.1 Open-WebUI Visual Reference Implementation
- **Direct UI Adaptation**: Implement the Open-WebUI interface for iOS while maintaining visual consistency
- **Asset References**: Extract and adapt UI assets, icons, and visual elements from the Open-WebUI repository
- **Component Structure**: Mirror the component hierarchy of Open-WebUI where applicable
- **CSS to SwiftUI Translation**: Convert Open-WebUI's CSS styling to equivalent SwiftUI modifiers
- **Animation Matching**: Replicate animations and transitions from the web interface
- **Theme Implementation**: Implement identical color schemes and visual themes

### 11.2 Key iOS Frameworks
- SwiftUI for UI (to recreate Open-WebUI interface elements)
- Combine for reactive programming
- Core Data for persistence
- Network framework for API communication
- NSNetService for Bonjour/mDNS
- Security framework for encryption
- AVFoundation for voice features (Phase 2)

### 11.3 Third-Party Dependencies
- Minimal use of third-party libraries
- Consider these carefully:
  - Markdown rendering library (to match Open-WebUI rendering)
  - Code syntax highlighting (using same themes as Open-WebUI)
  - WebSocket library (if needed for streaming responses identically)

### 11.4 Code Architecture
- Swift Package Manager for dependency management
- MVVM architecture
- Protocol-oriented design for provider interfaces
- Feature modules mirroring Open-WebUI organization where possible
- UI component library that mirrors Open-WebUI components

### 11.4 Open-WebUI Reference
- Reference the Open-WebUI GitHub repository for:
  - API formats and structures
  - Provider integration patterns
  - Model parameter handling
  - Chat history organization
  - Do not directly port code, but understand design patterns

## 12. Future Roadmap

### 12.1 Advanced Features
- Collaborative conversations
- Knowledge base integration
- Custom plugin system
- LLM function calling with native iOS features
- Cross-device synchronization
- Offline model embedding on device

### 12.2 Platform Expansion
- macOS companion app
- Shared conversation spaces
- Cloud backup and sync
- Widget support

## 13. References

### 13.1 External Documentation
- Ollama API documentation
- OpenAI API documentation
- OpenRouter API documentation
- Open-WebUI GitHub repository
- Apple Human Interface Guidelines

### 13.2 Design Inspirations
- Open-WebUI interface
- Apple native apps (Messages, Notes)
- Leading AI chat applications