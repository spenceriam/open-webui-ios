# Open WebUI iOS 📱

[![Discord](https://img.shields.io/badge/Discord-Open_WebUI-blue?logo=discord&logoColor=white)](https://discord.gg/5rJgQTnV4s)
![iOS](https://img.shields.io/badge/Platform-iOS%2016.0+-lightgrey)
![Status](https://img.shields.io/badge/Status-In%20Development-yellow)
![Language](https://img.shields.io/badge/Language-Swift-orange)
![Framework](https://img.shields.io/badge/Framework-SwiftUI-blue)

**Open WebUI iOS is a native application that faithfully recreates the Open WebUI experience for mobile devices, providing users with a visually identical and functionally equivalent interface to interact with both local LLM models via Ollama and cloud-based AI services.**

> [!NOTE]  
> This project is currently in early development. The repository contains the original Open WebUI codebase for reference purposes, with iOS-specific implementation to be developed.

## Key Features of Open WebUI iOS ⭐

- 🔄 **Ollama/OpenAI/OpenRouter Integration**: Connect to Ollama instances on your local network and seamlessly integrate with OpenAI-compatible APIs for versatile conversations, with user-provided API keys for cloud services.

- 📱 **Visual Consistency with Open WebUI**: Experience the same functionality and visual design of the web version, adapted specifically for iOS devices.

- 🔐 **iOS-Native Security**: Secure your API keys with iOS Keychain storage and enjoy end-to-end encryption for all network communications.

- 💬 **Advanced Chat Interface**: Enjoy multi-turn conversations with context retention, markdown/code syntax highlighting, and real-time streaming responses.

- 🌐 **Network Discovery**: Automatically discover Ollama instances running on your local network using Bonjour/mDNS.

- 🔄 **Model Management**: Browse, select, and manage models from both local Ollama instances and cloud providers with parameter customization.

- 🔍 **Conversation Management**: Organize your conversations with folders and tags, with search capabilities and export/import functionality.

- 🌙 **Theme Support**: Choose between light, dark, and system themes, maintaining visual consistency with the web version.

- 📊 **Universal App**: Optimized layouts for both iPhone and iPad, supporting both portrait and landscape orientations.

## Implementation Plan 🚀

### Phase 1 (MVP)
- iOS app shell with basic UI matching Open WebUI
- Ollama connectivity via local network
- OpenAI API integration
- OpenRouter API integration
- Basic chat functionality
- Conversation history management
- Essential settings

### Phase 2
- Google Gemini API integration
- Anthropic Claude API integration
- Document RAG functionality
- Voice input/output
- Image generation support (DALL-E, Stable Diffusion)
- Multi-model conversations

### Future Enhancements
- Apple Vision Pro support
- Apple Watch companion app
- Shortcuts integration
- iPad-specific optimizations
- Advanced prompt templates
- Custom function calling

## Technical Architecture 🛠️

### App Architecture
- **UI Framework**: SwiftUI for creating user interfaces that match Open WebUI design
- **Architecture Pattern**: MVVM (Model-View-ViewModel)
- **Reactive Programming**: Combine framework for asynchronous event handling
- **Concurrency**: Swift concurrency (async/await) for asynchronous operations
- **Local Storage**: Core Data for conversation history and settings
- **Networking**: URLSession for API requests, WebSockets for streaming responses

### Key Components

#### Network Module
- REST API clients for different providers (Ollama, OpenAI, OpenRouter)
- WebSocket implementation for streaming responses
- Network service discovery (Bonjour/mDNS) for Ollama
- Request/response interceptors for logging and error handling

#### Storage Module
- Secure API key management with iOS Keychain
- Conversation history persistence
- User preferences storage
- Model metadata caching

#### UI Module
- Chat interface components mirroring Open WebUI design
- Settings and configuration screens
- Model selection interface
- Response rendering components with markdown support

## Security and Privacy 🔒

Open WebUI iOS places a strong emphasis on security and privacy:

- API keys stored securely in iOS Keychain
- End-to-end encryption for network communications
- Local encryption of conversation history
- Option to keep conversations local-only
- No analytics or data collection without explicit consent
- Transparency about data usage and storage

## Requirements 📋

- iOS 16.0 or later
- iPhone or iPad
- Swift 5.7+
- Optional: Ollama instance on local network

## References 📚

This project uses the original [Open WebUI](https://github.com/open-webui/open-webui) as a reference for design and functionality. The original Open WebUI documentation can be found in the [open-webui_docs](./open-webui_docs/) directory.

## License 📜

This project is licensed under the [Open WebUI License](open-webui_docs/LICENSE), a revised BSD-3-Clause license.

## Support 💬

If you have any questions, suggestions, or need assistance, please open an issue or join the
[Open WebUI Discord community](https://discord.gg/5rJgQTnV4s) to connect with us! 🤝

---

This project aims to bring the power of Open WebUI to iOS while maintaining visual and functional consistency with the web version.