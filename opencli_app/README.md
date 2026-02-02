# OpenCLI App

**Cross-platform AI task orchestration app for iOS, Android, macOS, Windows, Linux & Web**

The primary client for OpenCLI, built with Flutter for maximum code reuse and consistent user experience across all platforms.

## ✨ Features

### Core Functionality
- 🤖 **AI-Powered Chat Interface** - Natural language interaction with AI
- 📱 **Cross-Platform** - Single codebase for iOS, Android, macOS, Windows, Linux, Web
- 🔌 **Daemon Integration** - Real-time WebSocket connection to OpenCLI daemon
- 🎯 **Intent Recognition** - AI-driven command understanding via Ollama
- 🎙️ **Voice Input** - Speech-to-text for hands-free operation

### Desktop-Specific Features
- 🖥️ **System Tray Integration** - Runs in system tray/menubar
- ⌨️ **Global Hotkeys** - Cmd/Ctrl+Shift+O to show window
- 🚀 **Launch at Startup** - Auto-start on system boot
- 🪟 **Window Management** - Minimize to tray, focus control

### Platform Support

| Platform | Status | Features |
|----------|--------|----------|
| **iOS** | ✅ Production | Full chat interface, voice input, push notifications |
| **Android** | ✅ Production | Full chat interface, voice input, background tasks |
| **macOS** | ✅ Beta | Desktop features + system tray + global hotkeys |
| **Windows** | ✅ Beta | Desktop features + system tray + global hotkeys |
| **Linux** | ✅ Beta | Desktop features + system tray + global hotkeys |
| **Web** | 🚧 Development | Chat interface (no system tray) |

## 🚀 Quick Start

### Prerequisites
- Flutter SDK 3.0+
- Dart SDK 3.0+
- OpenCLI Daemon running on target machine

### Installation

```bash
# Clone repository
git clone https://github.com/yourusername/opencli.git
cd opencli/opencli_app

# Get dependencies
flutter pub get

# Run on your platform
flutter run -d macos      # macOS
flutter run -d windows    # Windows
flutter run -d linux      # Linux
flutter run -d chrome     # Web
flutter run                # iOS/Android (with device/emulator)
```

### Building

```bash
# iOS
flutter build ios --release

# Android
flutter build apk --release
flutter build appbundle --release

# macOS
flutter build macos --release

# Windows
flutter build windows --release

# Linux
flutter build linux --release

# Web
flutter build web --release
```

## 📱 Usage

### Connect to Daemon

1. Ensure OpenCLI daemon is running on your computer:
   ```bash
   opencli daemon start
   ```

2. Open OpenCLI app and it will auto-connect via WebSocket (localhost:9876)

3. Start chatting with AI to control your computer!

### Example Commands

```
"Take a screenshot"
"Open Chrome browser"
"Create a file named test.txt with content hello world"
"Search for Flutter tutorials"
"What's my system status?"
```

## 🏗️ Architecture

```
opencli_app/
├── lib/
│   ├── main.dart                    # App entry point
│   ├── pages/
│   │   ├── chat_page.dart          # Main chat interface (883 lines)
│   │   └── ...
│   ├── services/
│   │   ├── daemon_service.dart     # WebSocket connection (253 lines)
│   │   ├── intent_recognizer.dart  # AI intent recognition (258 lines)
│   │   ├── tray_service.dart       # System tray (43 lines)
│   │   ├── hotkey_service.dart     # Global shortcuts (51 lines)
│   │   ├── startup_service.dart    # Auto-launch (77 lines)
│   │   └── audio_recorder.dart     # Voice input (81 lines)
│   └── widgets/
│       ├── daemon_status_card.dart # Status monitoring
│       └── ...
├── android/                         # Android-specific
├── ios/                             # iOS-specific
├── macos/                           # macOS-specific
├── windows/                         # Windows-specific
├── linux/                           # Linux-specific
└── web/                             # Web-specific
```

## 🔧 Configuration

### Daemon Connection

By default, connects to `localhost:9876`. Modify in `lib/services/daemon_service.dart` if needed:

```dart
static const defaultHost = 'localhost';
static const defaultPort = 9876;
```

### Desktop Features

Desktop features are automatically enabled on macOS, Windows, and Linux. Disabled on mobile and web.

Platform detection:
```dart
!kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux)
```

## 📦 Dependencies

### Core
- `flutter` - Framework
- `web_socket_channel: ^3.0.1` - WebSocket communication
- `http: ^1.2.2` - HTTP requests
- `crypto: ^3.0.5` - Authentication

### Mobile
- `speech_to_text: ^7.0.0` - Voice input
- `permission_handler: ^11.3.1` - Permissions
- `device_info_plus: ^11.2.0` - Device information

### Desktop
- `tray_manager: ^0.2.3` - System tray (macOS/Windows/Linux)
- `window_manager: ^0.4.2` - Window management
- `hotkey_manager: ^0.2.2` - Global keyboard shortcuts
- `launch_at_startup: ^0.3.1` - Auto-start on boot
- `package_info_plus: ^8.0.0` - App metadata

### UI
- `cupertino_icons: ^1.0.8` - iOS-style icons
- `macos_ui: ^2.1.0` - macOS native design
- `fluent_ui: ^4.9.1` - Windows 11 Fluent Design

## 🧪 Testing

```bash
# Run tests
flutter test

# Run with coverage
flutter test --coverage

# Integration tests
flutter drive --target=test_driver/app.dart
```

## 🐛 Known Issues

### macOS
- Requires macOS 11.0+ due to `speech_to_text` plugin
- First launch may require accessibility permissions

### Windows
- System tray icon may need to be added to assets

### Linux
- Requires AppIndicator support for system tray

## 🗺️ Roadmap

### v0.3.0 (Current)
- ✅ Cross-platform desktop support
- ✅ System tray integration
- ✅ Global hotkeys
- 🚧 Ollama model management UI

### v0.4.0 (Next)
- 📋 Enhanced settings page
- 📋 Model management interface
- 📋 Light/dark theme toggle
- 📋 Multi-language support

### v0.5.0 (Future)
- 📋 Offline mode
- 📋 Local task history
- 📋 Customizable hotkeys
- 📋 Plugin system

## 📄 License

MIT License - see [LICENSE](../LICENSE) file for details.

## 🤝 Contributing

See [CONTRIBUTING.md](../CONTRIBUTING.md) for guidelines.

## 📞 Support

- 📧 Email: support@opencli.ai
- 💬 Discord: [Join our community](https://discord.gg/opencli)
- 🐛 Issues: [GitHub Issues](https://github.com/yourusername/opencli/issues)

---

**Version**: 0.2.1+8 | **Last Updated**: 2026-02-02
