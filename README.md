# OpenCLI - Universal AI Development Platform

A high-performance, plugin-based AI development platform with intelligent caching and multi-model support.

## Features

- **Blazing Fast**: <10ms cold start, <1ms hot execution
- **Zero Configuration**: Auto-detection, works out of the box
- **Cross-Platform**: Terminal, IDE (IntelliJ/VSCode), and Web UI
- **Intelligent Caching**: Three-tier cache with semantic matching
- **Multi-Model Support**: Claude, GPT, Gemini, Ollama, local models
- **Plugin System**: Extensible architecture with hot-reload

## Quick Start

```bash
# Install OpenCLI
brew install opencli  # macOS
scoop install opencli # Windows

# Basic usage
opencli chat "Hello"
opencli flutter launch
```

## Project Structure

```
opencli/
├── cli/                    # Rust CLI client
├── daemon/                 # Dart daemon core
│   ├── core/              # Core daemon logic
│   ├── cache/             # Three-tier caching
│   ├── plugins/           # Plugin management
│   ├── ai/                # AI model integration
│   └── ipc/               # IPC communication
├── plugins/               # Plugin implementations
│   └── flutter-skill/     # Flutter automation plugin
├── web-ui/                # Web interface
├── scripts/               # Build and deployment
├── tests/                 # Test suites
│   ├── unit/             # Unit tests
│   ├── integration/      # Integration tests
│   └── e2e/              # End-to-end tests
├── docs/                  # Documentation
└── config/                # Configuration examples
```

## Documentation

- [Architecture](docs/ARCHITECTURE.md)
- [Technical Design](docs/OPENCLI_TECHNICAL_DESIGN.md)
- [Plugin Development Guide](docs/PLUGIN_GUIDE.md)
- [API Reference](docs/API.md)
- [Configuration Guide](docs/CONFIGURATION.md)

## Development

See [CONTRIBUTING.md](CONTRIBUTING.md) for development guidelines.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Status

🚧 Under active development - Alpha stage
