# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Open WebUI iOS is a native iOS application project aimed at recreating the Open WebUI experience for iOS devices. The goal is to provide a visually identical and functionally equivalent interface to the web-based Open WebUI, allowing users to interact with both local LLM models via Ollama and cloud-based AI services (OpenAI, OpenRouter, and later Google Gemini and Anthropic Claude).

The project uses the original Open WebUI as a reference for design and functionality, but will be built as a native iOS application rather than a web-based interface.

## Repository Structure

This repository contains:

1. Original Open WebUI codebase (serving as a reference)
2. iOS-specific implementation files (to be developed)

The original web application is built with:
- **Frontend**: Svelte/SvelteKit and TypeScript
- **Backend**: Python-based FastAPI application
- **Styling**: TailwindCSS

The iOS application will be built with:
- **UI Framework**: SwiftUI
- **Architecture**: MVVM (Model-View-ViewModel)
- **Programming Paradigm**: Swift, Combine for reactive programming
- **Persistence**: Core Data
- **Networking**: URLSession, WebSockets for streaming responses

## Original Web Application Commands

These commands are for reference purposes only when working with the original web-based Open WebUI code:

### Setup & Installation

```bash
# Install dependencies
npm install

# Setup Python environment (if working on backend)
cd backend
pip install -r requirements.txt
```

### Development

```bash
# Start development server with hot reloading
npm run dev

# Start development server on port 5050 (if 3000 is in use)
npm run dev:5050

# Fetch Pyodide dependencies (automatically called by dev/build)
npm run pyodide:fetch
```

### Building

```bash
# Build for production
npm run build

# Preview production build
npm run preview
```

### Testing

```bash
# Run frontend tests
npm run test:frontend

# Open Cypress test runner
npm run cy:open
```

## iOS Development Guidelines

### Key Components

1. **Network Module**
   - REST API clients for different providers (Ollama, OpenAI, OpenRouter)
   - WebSocket implementation for streaming responses
   - Network service discovery (Bonjour/mDNS) for Ollama
   - Request/response interceptors for logging and error handling

2. **Storage Module**
   - Secure API key management using iOS Keychain
   - Conversation history persistence with Core Data
   - User preferences storage
   - Model metadata caching

3. **UI Module**
   - Chat interface components mirroring Open WebUI design
   - Settings and configuration screens
   - Model selection interface
   - Response rendering components with markdown and code syntax highlighting

### Design Guidelines

- Visual consistency with the web version of Open WebUI is paramount
- UI should follow familiar interaction patterns from the web interface
- Maintain iOS native feel for system interactions and animations
- Adapt for touch interfaces and mobile screen sizes
- Support consistent theming (light/dark modes, accent colors)

### API Integrations

The app will integrate with:

1. **Ollama API**
   - Base URL format: `http://{host}:{port}/api`
   - Key endpoints: `/chat`, `/generate`, `/embeddings`, `/tags`, `/pull`

2. **OpenAI API**
   - Base URL: `https://api.openai.com/v1`
   - Key endpoints: `/chat/completions`, `/models`, `/images/generations`

3. **OpenRouter API**
   - Base URL: `https://openrouter.ai/api/v1`
   - Similar endpoints to OpenAI with model routing capabilities

### Implementation Plan

The development will proceed in phases:

**Phase 1 (MVP)**
- iOS app shell with basic UI
- Ollama connectivity via local network
- OpenAI API integration
- OpenRouter API integration
- Basic chat functionality
- Conversation history
- Essential settings

**Phase 2**
- Google and Anthropic API integrations
- Enhanced UI with advanced features
- Document RAG functionality
- Voice input/output
- Image generation support
- Multi-model conversations

## Security Considerations

- API keys must be stored in iOS Keychain
- Local conversation data should be stored in an encrypted database
- Use certificate pinning for cloud API connections
- Implement secure local network discovery
- Ensure request/response encryption
- Never log or export sensitive data like API keys

## Testing Strategy

- Unit testing for API clients, data persistence, UI components
- Integration testing for conversation flows, provider switching
- User testing for usability and performance on various iOS devices

## References

The iOS implementation should reference:
- The Open WebUI GitHub repository for UI design, API patterns, and functionality
- Apple Human Interface Guidelines for iOS-native interactions
- Ollama, OpenAI, and OpenRouter API documentation

## Requirements

- Swift 5.7+
- iOS 16.0+ support
- Universal app (iPhone and iPad)
- Support for both portrait and landscape orientations