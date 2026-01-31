# OpenCLI - Daemon (Dart)

Core daemon process for OpenCLI platform.

## Modules

### Core
- **IpcServer**: Unix Socket server
- **RequestRouter**: Request routing
- **ConfigWatcher**: Hot-reload configuration
- **HealthMonitor**: Health checks

### Cache
- **L1Cache**: In-memory hash cache
- **L2Cache**: LRU cache
- **L3Cache**: SQLite persistent cache
- **SemanticMatcher**: Embedding-based similarity

### Plugins
- **PluginLoader**: Dynamic loading
- **IsolateManager**: Sandboxed execution
- **PluginRegistry**: Plugin management
- **HotReload**: Live code updates

### AI
- **ModelAdapter**: Unified model interface
- **ModelRouter**: Intelligent routing
- **ConnectionPool**: HTTP pooling
- **TaskClassifier**: Task analysis
- **CostEstimator**: Cost tracking

## Build

```bash
dart compile exe bin/daemon.dart -o opencli-daemon
```

## Performance

- Memory usage (idle): <20MB
- Request handling: >100 concurrent
- Cache hit rate: >85%
