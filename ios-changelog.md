# iOS Changelog

This file tracks changes specific to the iOS version of Open WebUI.

## [Unreleased]

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

### Changed
- Enhanced chat interface with streaming indicator
- Improved API client architecture with robust streaming capabilities
- Upgraded provider configuration screens with status monitoring
- Expanded UI component library to match Open WebUI styling

### Fixed

### Removed

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