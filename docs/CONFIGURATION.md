# OpenCLI Configuration Guide

## Configuration File Location

Default: `~/.opencli/config.yaml`

## Complete Configuration Example

```yaml
# Configuration version
config_version: 1

# Auto mode (zero configuration mode)
auto_mode: true

# Model configuration
models:
  # Priority list (models tried in order)
  priority:
    - tinylm      # Local embedded model
    - ollama      # Local Ollama server
    - claude      # Cloud API (Anthropic)
    - gpt         # Cloud API (OpenAI)

  # Model-specific settings
  claude:
    provider: anthropic
    api_key: ${ANTHROPIC_API_KEY}  # From environment variable
    model: claude-sonnet-4-20250514
    max_tokens: 8192
    temperature: 1.0
    cache_enabled: true

  gpt:
    provider: openai
    api_key: ${OPENAI_API_KEY}
    model: gpt-4-turbo
    max_tokens: 4096
    temperature: 0.7

  gemini:
    provider: google
    api_key: ${GOOGLE_API_KEY}
    model: gemini-2.0-flash-exp
    max_tokens: 8192

  ollama:
    provider: ollama
    base_url: http://localhost:11434
    model: codellama
    preload: true  # Preload model into memory

  tinylm:
    provider: local
    model_path: ~/.opencli/models/tinylm.gguf
    context_length: 2048
    gpu_layers: 0  # CPU only

# Intelligent routing rules
routing:
  default: claude

  rules:
    # Simple explanations -> local model
    - task_type: explanation
      complexity: low
      model: tinylm

    # Code completion -> Ollama
    - task_type: code_completion
      model: ollama

    # Complex tasks -> Claude
    - task_type: [debugging, refactoring, architecture]
      complexity: high
      model: claude

    # Large context -> Claude (supports 200k tokens)
    - context_size: ">100000"
      model: claude

    # Vision tasks -> vision-capable model
    - has_image: true
      model: claude

  # Fallback strategy
  fallback:
    - if: api_error
      action: use_local
    - if: rate_limit
      action: retry_after_60s
    - if: no_model_available
      action: use_tinylm

# Cache configuration
cache:
  enabled: true

  # L1 Cache (in-memory)
  l1:
    max_size: 100              # Max entries
    max_memory_mb: 50          # Max memory usage

  # L2 Cache (LRU)
  l2:
    max_size: 1000             # Max entries
    eviction_policy: lru       # Eviction strategy

  # L3 Cache (persistent disk)
  l3:
    enabled: true
    dir: ~/.opencli/cache
    max_size_mb: 500
    compression: true

  # Semantic cache
  semantic:
    enabled: true
    similarity_threshold: 0.95  # 95% similarity
    embedding_model: all-MiniLM-L6-v2

  # TTL (time-to-live) settings
  ttl:
    default_seconds: 604800    # 7 days
    explanations: 2592000      # 30 days
    code_generation: 86400     # 1 day

# Connection pool
connection_pool:
  max_size: 10
  keep_alive: true
  max_idle_seconds: 300
  warmup_enabled: true

# Performance settings
performance:
  max_concurrent_requests: 100
  request_timeout_ms: 30000
  slow_request_threshold_ms: 1000

  # Resource limits
  max_memory_mb: 200
  max_cpu_percent: 50

# Plugin configuration
plugins:
  auto_load: true
  dir: ~/.opencli/plugins

  # Enabled plugins
  enabled:
    - flutter-skill
    - ai-assistants
    - custom-scripts

  # Plugin-specific settings
  flutter-skill:
    default_device: macos
    screenshot_format: png
    auto_hot_reload: true
    timeout_seconds: 30

    permissions:
      - network
      - filesystem.write
      - process.spawn

  ai-assistants:
    default_model: claude
    stream_responses: true

    permissions:
      - network

# Logging
logging:
  level: info  # debug, info, warn, error
  file: ~/.opencli/logs/opencli.log
  max_size_mb: 10
  max_files: 5
  console: true

# Auto-update
auto_update:
  enabled: true
  check_interval_seconds: 86400  # Daily
  channel: stable                # stable, beta, dev
  auto_install: false            # Requires confirmation

# Telemetry (anonymous usage statistics)
telemetry:
  enabled: false
  anonymous: true
  endpoint: https://telemetry.opencli.dev

# Security settings
security:
  socket_path: /tmp/opencli.sock
  socket_permissions: 0600

  # API key storage
  use_system_keychain: true

  # Plugin sandbox
  plugin_isolation: true
  plugin_timeout_seconds: 30

  # Input validation
  validate_params: true
  sanitize_paths: true
  sanitize_commands: true
```

## Environment Variables

### API Keys

```bash
# Anthropic Claude
export ANTHROPIC_API_KEY="sk-ant-..."

# OpenAI GPT
export OPENAI_API_KEY="sk-..."

# Google Gemini
export GOOGLE_API_KEY="AIza..."
```

### Other Settings

```bash
# Override config file location
export OPENCLI_CONFIG=~/my-custom-config.yaml

# Override socket path
export OPENCLI_SOCKET=/tmp/my-opencli.sock

# Enable debug logging
export OPENCLI_LOG_LEVEL=debug
```

## Configuration Scenarios

### Minimal (Cloud-only)

```yaml
config_version: 1
auto_mode: true

models:
  priority: [claude]

  claude:
    api_key: ${ANTHROPIC_API_KEY}
```

### Local-only (No API keys needed)

```yaml
config_version: 1
auto_mode: true

models:
  priority: [ollama, tinylm]

  ollama:
    base_url: http://localhost:11434
    model: codellama
```

### Cost-optimized (Prefer free local models)

```yaml
config_version: 1
auto_mode: true

models:
  priority: [tinylm, ollama, claude]

routing:
  rules:
    # Only use Claude for complex tasks
    - complexity: high
      model: claude

    # Everything else goes local
    - complexity: [low, medium]
      model: tinylm
```

### Performance-optimized (Aggressive caching)

```yaml
cache:
  enabled: true

  l1:
    max_size: 500
    max_memory_mb: 200

  l2:
    max_size: 5000

  l3:
    max_size_mb: 2000

  semantic:
    enabled: true
    similarity_threshold: 0.90  # More permissive
```

## Plugin Configuration

### Flutter Skill

```yaml
plugins:
  flutter-skill:
    default_device: macos  # macos, ios, android, linux, windows
    screenshot_format: png  # png, jpg
    auto_hot_reload: true
    timeout_seconds: 30
```

### Custom Plugin

```yaml
plugins:
  enabled:
    - my-custom-plugin

  my-custom-plugin:
    api_endpoint: https://api.example.com
    api_key: ${MY_PLUGIN_API_KEY}
    timeout_ms: 5000
```

## Validation

Validate your configuration:

```bash
opencli config validate
```

Show current configuration:

```bash
opencli config show
```

Test model connection:

```bash
opencli config test-model claude
```

## Hot-Reload

Configuration changes are automatically detected and reloaded without restarting the daemon.

Monitor configuration:

```bash
tail -f ~/.opencli/logs/opencli.log | grep "Configuration changed"
```

## Troubleshooting

### API Key Not Found

Ensure environment variable is set:
```bash
echo $ANTHROPIC_API_KEY
```

### Cache Not Working

Check cache directory permissions:
```bash
ls -ld ~/.opencli/cache
```

### Plugin Not Loading

Check plugin directory:
```bash
ls ~/.opencli/plugins/
```

View daemon logs:
```bash
tail -f ~/.opencli/logs/opencli.log
```
