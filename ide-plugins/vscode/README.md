# OpenCLI VSCode Extension

Universal AI Development Platform integration for Visual Studio Code.

## Features

- 💬 AI Chat Assistant in sidebar
- 🚀 Flutter app launch and control
- 🔥 Hot reload integration
- 📸 Screenshot capture
- ⌨️ Quick commands

## Installation

### From VSIX

```bash
code --install-extension opencli-vscode-0.1.0.vsix
```

### From Source

```bash
cd ide-plugins/vscode
npm install
npm run compile
code --install-extension .
```

## Usage

### Chat Assistant

1. Click OpenCLI icon in Activity Bar
2. Type your question in the chat panel
3. Press Enter or click Send

### Flutter Commands

- **Launch App**: `Cmd+Shift+P` → "OpenCLI: Launch Flutter App"
- **Hot Reload**: `Cmd+Shift+P` → "OpenCLI: Hot Reload Flutter App"
- **Screenshot**: `Cmd+Shift+P` → "OpenCLI: Take Screenshot"

## Configuration

File → Preferences → Settings → OpenCLI

```json
{
  "opencli.socketPath": "/tmp/opencli.sock",
  "opencli.autoStart": true,
  "opencli.defaultModel": "claude"
}
```

## Requirements

- OpenCLI daemon installed (`~/.opencli/bin/opencli-daemon`)
- VSCode 1.80.0 or higher

## Development

```bash
npm install
npm run compile
npm run watch  # Watch mode
```

## License

MIT
