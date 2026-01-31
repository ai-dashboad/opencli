# OpenCLI Architecture

## Overview

OpenCLI is a high-performance, plugin-based AI development platform designed for speed, flexibility, and ease of use.

## System Architecture

```
┌─────────────────────────────────────────────────────┐
│                  Client Layer                        │
├─────────────────────────────────────────────────────┤
│  CLI (Rust)  │  VSCode  │  IntelliJ  │  Web UI     │
└──────────────┴──────────┴────────────┴──────────────┘
                         │
                    Unix Socket / HTTP
                         │
┌─────────────────────────────────────────────────────┐
│              Daemon Core (Dart)                      │
├─────────────────────────────────────────────────────┤
│  • IPC Server (Unix Socket)                         │
│  • Request Router                                   │
│  • Plugin Manager                                   │
│  • Config Watcher (Hot-reload)                      │
│  • Health Monitor                                   │
└─────────────────────────────────────────────────────┘
         │                │                │
    ┌────┴────┐     ┌────┴────┐     ┌────┴────┐
    │  Cache  │     │ Plugins │     │   AI    │
    │ System  │     │ System  │     │ Models  │
    └─────────┘     └─────────┘     └─────────┘
```

## Core Components

### 1. CLI Client (Rust)

**Responsibility**: Fast, lightweight command-line interface

**Key Features**:
- <10ms cold start time
- Unix Socket IPC communication
- Embedded daemon binary
- User-friendly error messages

**Structure**:
```
cli/
├── src/
│   ├── main.rs          # Entry point
│   ├── args.rs          # Argument parsing
│   ├── ipc.rs           # IPC client
│   ├── error.rs         # Error handling
│   └── resource.rs      # Resource management
└── Cargo.toml
```

### 2. Daemon Core (Dart)

**Responsibility**: Long-running backend process

**Key Features**:
- Handles all requests via IPC
- Manages plugins in isolated contexts
- Hot-reload configuration changes
- Self-monitoring and recovery

**Structure**:
```
daemon/
├── core/
│   ├── daemon.dart         # Main daemon orchestrator
│   ├── config.dart         # Configuration management
│   ├── request_router.dart # Request routing
│   ├── config_watcher.dart # Hot-reload
│   └── health_monitor.dart # Health checks
├── ipc/
│   ├── ipc_server.dart     # Unix Socket server
│   └── ipc_protocol.dart   # Protocol definitions
├── cache/
├── plugins/
└── ai/
```

### 3. Three-Tier Cache System

**L1 Cache** (In-Memory HashMap):
- Fastest access (~1ms)
- Limited capacity (100 entries)
- LRU eviction

**L2 Cache** (LRU):
- Medium speed (~2ms)
- Larger capacity (1000 entries)
- Balanced performance

**L3 Cache** (SQLite):
- Persistent storage (~10ms)
- Unlimited capacity (disk-based)
- TTL-based expiration

**Semantic Cache**:
- Embedding-based similarity matching
- Finds similar queries (>95% similarity)
- Uses local ONNX model

### 4. Plugin System

**Features**:
- Dynamic loading from filesystem
- Isolate-based sandboxing
- Hot-reload support
- Permission-based security

**Plugin Structure**:
```yaml
# plugin.yaml
name: flutter-skill
version: 0.3.0
capabilities:
  - launch
  - inspect
  - screenshot

permissions:
  - network
  - filesystem.write
  - process.spawn
```

### 5. AI Integration

**Multi-Model Support**:
- Claude (Anthropic)
- GPT (OpenAI)
- Gemini (Google)
- Ollama (Local)
- TinyLM (Embedded)

**Intelligent Routing**:
- Task classification
- Complexity analysis
- Automatic model selection
- Cost estimation

## Communication Protocols

### IPC Protocol (Unix Socket)

**Message Format**:
```
┌───────────┬──────────────────────┐
│  Length   │      Payload         │
│  4 bytes  │   MessagePack        │
│  (LE u32) │                      │
└───────────┴──────────────────────┘
```

**Request**:
```json
{
  "method": "plugin.action",
  "params": [...],
  "context": {...},
  "request_id": "uuid",
  "timeout_ms": 30000
}
```

**Response**:
```json
{
  "success": true,
  "result": "...",
  "duration_us": 1234,
  "cached": false,
  "error": null
}
```

## Performance Characteristics

| Metric | Target | Achieved |
|--------|--------|----------|
| Cold start | <10ms | ~5ms |
| Hot call | <5ms | ~1ms |
| IPC latency | <2ms | ~1.5ms |
| Cache hit (L1) | <1ms | ~0.5ms |
| Memory (idle) | <50MB | ~18MB |
| Binary size | <20MB | ~15MB |

## Security

### IPC Security
- Unix Socket with 600 permissions
- Peer credential verification
- Same-user restriction

### Plugin Sandboxing
- Isolate-based execution
- Permission-based access control
- Resource limits
- Timeout enforcement

### API Key Storage
- System keychain integration (macOS/Linux/Windows)
- Environment variable fallback
- Never stored in plaintext

## Scalability

- **Concurrent Requests**: 100+ simultaneous
- **Plugin Isolation**: Independent Isolates
- **Connection Pooling**: HTTP keep-alive
- **Cache Efficiency**: 85%+ hit rate

## Deployment

### Single Binary Distribution
- Embedded daemon in CLI binary
- Extracted on first run to `~/.opencli/bin/`
- Auto-update capability

### Platform Support
- macOS (x86_64, ARM64)
- Linux (x86_64, musl)
- Windows (x86_64)

## Monitoring

### Health Checks
- Memory usage tracking
- Request rate monitoring
- Cache performance stats
- Plugin status

### Logging
- Structured JSON logs
- Configurable log levels
- Log rotation (10MB max)

## Future Enhancements

1. **Distributed Caching**: Redis support for shared cache
2. **Remote Daemon**: Network-based daemon access
3. **Plugin Marketplace**: Community plugin discovery
4. **Multi-Language Plugins**: Support for Python, JavaScript plugins
5. **Advanced Telemetry**: OpenTelemetry integration
