# OpenCLI WebSocket Protocol

## Overview

OpenCLI now supports a **unified WebSocket protocol** that allows all clients (Desktop, Mobile, Web) to communicate with the Daemon using a standardized message format.

## Connection

### Endpoint

```
ws://localhost:9875/ws
```

### Authentication

Currently, the WebSocket endpoint accepts connections without authentication for development. Production deployments should implement proper authentication.

## Message Format

All messages use the `OpenCLIMessage` format defined in `shared/lib/protocol/message.dart`.

### Message Structure

```dart
{
  "id": "1738123456789_abc123",           // Unique message ID
  "type": "command|response|notification|heartbeat",
  "source": "mobile|desktop|web|cli",     // Client type
  "target": "daemon|broadcast|specific",   // Target type
  "payload": { /* action-specific data */ },
  "timestamp": 1738123456789,              // Unix timestamp (ms)
  "priority": 5                            // Message priority (0-10)
}
```

### Message Types

1. **command** - Client requests (execute task, get status, etc.)
2. **response** - Daemon responses to commands
3. **notification** - Daemon broadcasts (task updates, events)
4. **heartbeat** - Keep-alive messages

## Client Types

- `mobile` - iOS/Android apps
- `desktop` - macOS/Windows/Linux desktop apps
- `web` - Web UI
- `cli` - Command-line interface

## Available Commands

### 1. Execute Task

Execute a task on the daemon.

```dart
CommandMessageBuilder.executeTask(
  source: ClientType.mobile,
  taskId: 'my-task-001',
  params: {
    'action': 'screenshot',
    'path': '/tmp/screen.png',
  },
)
```

**Response:**
```json
{
  "type": "response",
  "payload": {
    "requestId": "...",
    "status": "success",
    "data": {
      "taskId": "my-task-001",
      "status": "started"
    }
  }
}
```

### 2. Get Tasks

Retrieve list of tasks (optionally filtered).

```dart
CommandMessageBuilder.getTasks(
  source: ClientType.mobile,
  filter: 'running',  // optional: 'running', 'completed', 'pending'
)
```

**Response:**
```json
{
  "type": "response",
  "payload": {
    "status": "success",
    "data": {
      "tasks": [...],
      "total": 3
    }
  }
}
```

### 3. Get AI Models

Get available AI models.

```dart
CommandMessageBuilder.getModels(
  source: ClientType.mobile,
)
```

**Response:**
```json
{
  "type": "response",
  "payload": {
    "status": "success",
    "data": {
      "models": [
        {
          "id": "claude-sonnet-3.5",
          "name": "Claude Sonnet 3.5",
          "provider": "Anthropic",
          "available": true
        }
      ],
      "default": "claude-sonnet-3.5"
    }
  }
}
```

### 4. Send Chat Message

Send a message to an AI model.

```dart
CommandMessageBuilder.sendChatMessage(
  source: ClientType.mobile,
  message: 'Hello, how are you?',
  conversationId: 'conv-123',  // optional
  modelId: 'claude-sonnet-3.5', // optional
)
```

### 5. Get Daemon Status

Get daemon health and stats.

```dart
CommandMessageBuilder.getStatus(
  source: ClientType.mobile,
)
```

**Response:**
```json
{
  "type": "response",
  "payload": {
    "status": "success",
    "data": {
      "daemon": {
        "version": "0.2.0",
        "uptime_seconds": 3600,
        "memory_mb": 45.2
      },
      "mobile": {
        "connected_clients": 2
      }
    }
  }
}
```

### 6. Stop Task

Stop a running task.

```dart
CommandMessageBuilder.stopTask(
  source: ClientType.mobile,
  taskId: 'my-task-001',
)
```

## Notifications

The daemon broadcasts notifications to all connected clients for real-time updates.

### Task Progress

```json
{
  "type": "notification",
  "payload": {
    "event": "task_progress",
    "taskId": "my-task-001",
    "progress": 0.65,
    "message": "Processing..."
  }
}
```

### Task Completed

```json
{
  "type": "notification",
  "payload": {
    "event": "task_completed",
    "taskId": "my-task-001",
    "taskName": "Screenshot",
    "result": {
      "path": "/tmp/screen.png"
    }
  }
}
```

## Example: Flutter Mobile Client

```dart
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:opencli_shared/protocol/message.dart';

class OpenCLIDaemonClient {
  late WebSocketChannel _channel;

  Future<void> connect() async {
    _channel = WebSocketChannel.connect(
      Uri.parse('ws://192.168.1.100:9875/ws'),
    );

    // Listen for messages
    _channel.stream.listen((message) {
      final msg = OpenCLIMessage.fromJsonString(message);
      _handleMessage(msg);
    });
  }

  void _handleMessage(OpenCLIMessage msg) {
    switch (msg.type) {
      case MessageType.notification:
        if (msg.payload['event'] == 'connected') {
          print('Connected! Client ID: ${msg.payload['clientId']}');
        }
        break;
      case MessageType.response:
        print('Response: ${msg.payload}');
        break;
      default:
        break;
    }
  }

  void executeTask(String taskId, Map<String, dynamic> params) {
    final cmd = CommandMessageBuilder.executeTask(
      source: ClientType.mobile,
      taskId: taskId,
      params: params,
    );
    _channel.sink.add(cmd.toJsonString());
  }

  void getTasks() {
    final cmd = CommandMessageBuilder.getTasks(
      source: ClientType.mobile,
    );
    _channel.sink.add(cmd.toJsonString());
  }

  void dispose() {
    _channel.sink.close();
  }
}
```

## Testing

Run the example WebSocket client:

```bash
cd daemon
dart run test/websocket_client_example.dart
```

This will:
1. Connect to ws://localhost:9875/ws
2. Receive welcome message
3. Send test commands (get models, tasks, status, execute task)
4. Display all responses

## Architecture

### Dual WebSocket Support

The daemon now supports **two WebSocket servers**:

1. **Port 9876** - Legacy mobile protocol (MobileConnectionManager)
   - Custom JSON format
   - Mobile-specific authentication
   - Backward compatible with existing mobile app

2. **Port 9875/ws** - Unified protocol (MessageHandler)
   - Standardized OpenCLI message format
   - Supports all client types (Desktop/Mobile/Web)
   - Future-proof and extensible

### Migration Path

Mobile apps can gradually migrate from port 9876 to the unified protocol:

- **Phase 1** - Keep using port 9876 (current)
- **Phase 2** - Support both protocols simultaneously
- **Phase 3** - Migrate to unified protocol (9875/ws)
- **Phase 4** - Deprecate old protocol

## Next Steps

1. **Mobile App Integration** - Update iOS/Android apps to use new protocol
2. **Desktop App** - OpenCLI desktop app can communicate via WebSocket
3. **Web UI** - Real-time updates from daemon
4. **Authentication** - Implement secure device pairing
5. **Error Handling** - Robust error recovery and reconnection logic
