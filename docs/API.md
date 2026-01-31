# OpenCLI API Reference

## IPC Protocol

### Connection

**Unix Socket Path**: `/tmp/opencli.sock`

```dart
// Connect to daemon
final socket = await Socket.connect(
  InternetAddress('/tmp/opencli.sock', type: InternetAddressType.unix),
  0,
);
```

### Request Format

All requests use MessagePack serialization with a 4-byte length prefix.

**Structure**:
```
┌───────────┬──────────────────────┐
│  Length   │      Payload         │
│  4 bytes  │   MessagePack        │
│  (LE u32) │                      │
└───────────┴──────────────────────┘
```

**Request Schema**:
```typescript
interface IpcRequest {
  method: string;              // "plugin.action" format
  params: any[];               // Action parameters
  context: {[key: string]: any}; // Optional context
  request_id?: string;         // UUID for request tracking
  timeout_ms?: number;         // Request timeout (default: 30000)
}
```

**Example**:
```json
{
  "method": "flutter.launch",
  "params": ["--device=macos"],
  "context": {
    "project_path": "/path/to/project"
  },
  "request_id": "550e8400-e29b-41d4-a716-446655440000",
  "timeout_ms": 30000
}
```

### Response Format

**Response Schema**:
```typescript
interface IpcResponse {
  success: boolean;
  result: string;
  duration_us: number;         // Execution time in microseconds
  cached: boolean;             // Was result from cache?
  request_id?: string;         // Echoed from request
  error?: string;              // Error message if failed
}
```

**Success Example**:
```json
{
  "success": true,
  "result": "Flutter app launched successfully",
  "duration_us": 52100,
  "cached": false,
  "request_id": "550e8400-e29b-41d4-a716-446655440000",
  "error": null
}
```

**Error Example**:
```json
{
  "success": false,
  "result": "",
  "duration_us": 120,
  "cached": false,
  "error": "Plugin not found: nonexistent"
}
```

## Error Codes

| Code | Description | Example |
|------|-------------|---------|
| E001 | Invalid method name | `method: "invalid"` |
| E002 | Plugin not found | `plugin: "nonexistent"` |
| E003 | Action not found | `action: "unknown"` |
| E004 | Parameter error | Missing required parameter |
| E005 | Timeout | Request exceeded timeout_ms |
| E006 | Plugin crashed | Isolate exception |
| E007 | Connection error | Socket connection failed |
| E008 | Permission denied | Insufficient permissions |

## Built-in Methods

### System Commands

#### system.health
Health check endpoint.

**Parameters**: None

**Returns**: `"OK"` if healthy

**Example**:
```json
{
  "method": "system.health",
  "params": []
}
```

#### system.plugins
List all loaded plugins.

**Parameters**: None

**Returns**: Comma-separated plugin names

**Example**:
```json
{
  "method": "system.plugins",
  "params": []
}
```

#### system.version
Get daemon version.

**Parameters**: None

**Returns**: Version string (e.g., "0.1.0")

#### system.stats
Get daemon statistics.

**Parameters**: None

**Returns**: JSON object with stats

```json
{
  "uptime_seconds": 3600,
  "total_requests": 1234,
  "cache_hit_rate": 0.87,
  "memory_mb": 18.5,
  "plugins_loaded": 3
}
```

### Chat Command

#### chat
Send a message to AI assistant.

**Parameters**:
- `message` (string): The message to send

**Returns**: AI response

**Example**:
```json
{
  "method": "chat",
  "params": ["Explain async/await in Dart"]
}
```

## Plugin Methods

Plugin methods follow the format: `{plugin_name}.{action}`

### Flutter Skill Plugin

#### flutter.launch
Launch a Flutter application.

**Parameters**:
- `--device` (optional): Target device (macos, ios, android)
- `--project` (optional): Project path

**Example**:
```json
{
  "method": "flutter.launch",
  "params": ["--device=macos", "--project=/path/to/app"]
}
```

#### flutter.inspect
Get interactive UI elements.

**Parameters**: None

**Returns**: JSON list of interactive elements

#### flutter.screenshot
Take a screenshot of the running app.

**Parameters**:
- `--path` (optional): Output path

**Returns**: Path to screenshot file

#### flutter.tap
Tap on an element.

**Parameters**:
- `key` or `text`: Element identifier

**Example**:
```json
{
  "method": "flutter.tap",
  "params": ["--key=login_button"]
}
```

#### flutter.enter_text
Enter text into an input field.

**Parameters**:
- `key`: TextField identifier
- `text`: Text to enter

**Example**:
```json
{
  "method": "flutter.enter_text",
  "params": ["--key=username_field", "--text=user@example.com"]
}
```

#### flutter.hot_reload
Trigger hot reload.

**Parameters**: None

**Returns**: Reload status

## HTTP API (Optional)

If HTTP server is enabled, the following endpoints are available:

### POST /api/v1/execute

Execute a method.

**Request**:
```json
{
  "method": "flutter.launch",
  "params": ["--device=macos"],
  "context": {}
}
```

**Response**:
```json
{
  "success": true,
  "result": "App launched",
  "duration_ms": 52
}
```

### GET /api/v1/plugins

List all plugins.

**Response**:
```json
{
  "plugins": [
    {
      "name": "flutter-skill",
      "version": "0.3.0",
      "capabilities": ["launch", "inspect", "screenshot"]
    }
  ]
}
```

### GET /api/v1/health

Health check endpoint.

**Response**:
```json
{
  "status": "healthy",
  "uptime_seconds": 12345,
  "memory_mb": 18.5,
  "plugins_loaded": 3
}
```

### WebSocket /api/v1/stream

Streaming chat endpoint.

**Client Send**:
```json
{
  "type": "chat",
  "message": "Hello",
  "model": "claude"
}
```

**Server Stream**:
```json
{"type": "chunk", "content": "Hello! "}
{"type": "chunk", "content": "How can "}
{"type": "chunk", "content": "I help?"}
{"type": "done", "total_tokens": 8}
```

## Client Libraries

### Rust

```rust
use opencli::IpcClient;

let mut client = IpcClient::connect()?;
let response = client.send_request("chat", &["Hello"])?;
println!("{}", response.result);
```

### Dart

```dart
import 'package:opencli/ipc_client.dart';

final client = IpcClient();
await client.connect();

final response = await client.sendRequest(
  method: 'chat',
  params: ['Hello'],
);

print(response.result);
```

### TypeScript

```typescript
import { OpenCliClient } from 'opencli-client';

const client = new OpenCliClient();
await client.connect();

const response = await client.execute('chat', ['Hello']);
console.log(response.result);
```

## Rate Limiting

- Default: 100 concurrent requests
- Timeout: 30 seconds per request
- Queue overflow: Request rejected with E005

## Caching Behavior

Responses are automatically cached based on:
- Exact query match (L1, L2, L3)
- Semantic similarity (>95%, semantic cache)

Cache TTL:
- Default: 7 days
- Code generation: 1 day
- Explanations: 30 days (rarely change)

To bypass cache, include `"bypass_cache": true` in context.
