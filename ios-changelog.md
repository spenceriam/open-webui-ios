# iOS Changelog

This file tracks changes specific to the iOS version of Open WebUI.

## [0.6.0] - 2025-05-09

### Added
- Created comprehensive modernization plan for codebase
- Implemented actor-based `OllamaServiceActor` to replace Combine-based implementation
- Added `DiscoveryServiceActor` with AsyncStream for network discovery
- Created `ChatFeature` using The Composable Architecture (TCA) principles
- Implemented modern dependency injection system with protocol-based interfaces
- Added support for Swift's structured concurrency with async/await
- Created typed error handling for better error propagation

### Changed
- Migrated from Combine to Swift Concurrency for network requests
- Replaced publishers with AsyncThrowingStream for streaming responses
- Enhanced thread safety using Swift Actor model
- Improved cancellation support with structured task management
- Adopted @Reducer and @ObservableState macros for state management
- Updated UI components with modern SwiftUI bindings

### Improved
- Better performance through optimized task prioritization
- Enhanced testability with protocol-based dependencies
- Improved power management with actor-based services
- Better organization of view components using composition

## [0.5.0] - 2025-05-06

### Added
- Implemented memory optimization with adaptive caching and pagination
- Added `ImageCache` utility for efficient image handling
- Created `MemoryMonitor` for tracking memory pressure
- Implemented conversation and message pagination in StorageService
- Added battery optimization with `PowerMonitor` utility
- Enhanced WebSocketService with battery-efficient operation
- Implemented background processing for long responses
- Added message recovery system for interrupted responses
- Created notification integration for background operations
- Added UI components for resuming interrupted messages
- Implemented partial message status tracking

### Changed
- Updated ChatViewModel with memory pressure handling
- Enhanced app lifecycle management for background states
- Improved message streaming with battery awareness
- Updated storage operations with memory-efficient patterns

### Fixed
- Resolved memory leaks in conversation handling
- Fixed issues with message interruption during background transitions

## [0.4.0] - 2025-05-06

### Added
- Implemented structured onboarding flow with 3-step process
- Created provider configuration screens in onboarding
- Added comprehensive help documentation with HelpSupportView
- Built network permission request handling with NetworkPermissionHelper
- Implemented local encryption for conversation history using CryptoKit
- Added certificate pinning for cloud API connections
- Created secure network discovery for Ollama servers
- Implemented comprehensive unit tests for API clients
- Added data persistence testing with in-memory Core Data testing
- Built UI tests for all core application flows

### Changed
- Updated app architecture to conditionally show onboarding on first launch
- Enhanced KeychainService with better error handling
- Improved SecureStorageService with military-grade encryption
- Updated AppState to persist authentication state between sessions

### Fixed
- Fixed permission handling for local network access
- Addressed security issues in API key storage
- Improved error handling for network services

## [0.3.0] - 2025-05-06

### Added
- Implemented iPhone landscape layout with persistent sidebar for better screen space utilization
- Built iPad-specific layout with triple-column navigation for optimal tablet experience
- Created compact layout for smaller devices (iPhone SE/mini) with tab-based navigation
- Added comprehensive dynamic type support with `DynamicTypeHelper` utility class
- Implemented intelligent device detection to auto-select appropriate layouts
- Added responsive layout adaptations for different screen sizes
- Created documentation for device adaptations in `DEVICE_ADAPTATIONS.md`

### Changed
- Updated app architecture to dynamically adapt to device type, orientation, and accessibility settings
- Enhanced main navigation to provide better user experience across different devices
- Improved UI components with dynamic type scaling for better accessibility

### Fixed
- Addressed layout issues on smaller iPhone models
- Fixed spacing and sizing issues when using larger accessibility text sizes

## [0.2.0] - 2025-05-20

### Added
- Implemented WebSocket support for streaming responses
- Created complete message bubble component system with user/assistant styling
- Added real-time streaming text rendering with cursor animation
- Built markdown rendering with code block support
- Implemented complete model selection interface with provider categories
- Created model cards and parameter customization UI
- Added Bonjour/mDNS discovery for finding Ollama servers on the network
- Implemented server discovery view for Ollama
- Built detailed server status monitoring and connection system
- Added API key management and validation for cloud providers
- Expanded Ollama integration with model listing and pull capabilities
- Created comprehensive settings screen matching web version organization
- Built privacy and security settings panel
- Implemented conversation list with folder/tag organization system
- Added message tagging and organization capabilities
- Created import/export functionality for conversations
- Built conversation search functionality
- Added support for conversation pinning, archiving, and favorites
- Implemented theme customization options

### Changed
- Enhanced chat interface with streaming indicator
- Improved API client architecture with robust streaming capabilities
- Upgraded provider configuration screens with status monitoring
- Expanded UI component library to match Open WebUI styling
- Enhanced data models with metadata support for organization
- Improved folder/tag management for conversations and messages
- Updated sidebar navigation to include conversation management

### Fixed
- Fixed issues with WebSocket connection handling
- Improved error handling for network connections
- Fixed layout issues in the chat interface

## [0.1.0] - 2025-05-06

### Added
- Initial iOS repository setup based on Open WebUI
- Moved all files from open-webui/ subdirectory to repository root
- Created native iOS app project structure with SwiftUI
- Implemented MVVM architecture pattern
- Added Core Data for conversation storage
- Created secure Keychain service for API key management
- Implemented basic UI with light/dark mode support
- Added placeholder API clients for Ollama, OpenAI, and OpenRouter
- Created data models for conversations, messages, and AI models
- Implemented basic UI navigation with split view
- Added welcome screen with provider selection

### Changed
- Project structure reorganized for iOS compatibility
- Created detailed todo list with development roadmap

### Fixed

### Removed