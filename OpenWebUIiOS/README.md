# Open WebUI iOS Project

This directory contains the source code for the native iOS implementation of Open WebUI.

## Project Structure

- **Sources/App**: Main application files
- **Sources/Models**: Data models
- **Sources/Views**: SwiftUI views
- **Sources/ViewModels**: View models (MVVM pattern)
- **Sources/Services**: Services for networking, storage, and more
- **Sources/Utils**: Utility classes and extensions
- **Sources/Resources**: Assets and resources

## Getting Started

1. Clone this repository
2. Open the project in Xcode
3. Build and run on an iOS 16.0+ device or simulator

## Development Guidelines

- Follow the MVVM (Model-View-ViewModel) architecture pattern
- Use Swift Package Manager for dependency management
- Maintain visual consistency with the web version of Open WebUI
- Follow Swift style guidelines and best practices

## Dependencies

- **Down**: For Markdown rendering
- **Highlightr**: For code syntax highlighting
- **Starscream**: For WebSocket connections

## Core Features

- Connect to Ollama instances on the local network
- Integrate with OpenAI and OpenRouter APIs
- Multi-turn conversations with markdown support
- Real-time streaming responses
- Secure API key storage
- Conversation history management