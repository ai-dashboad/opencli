# OpenCLI Plugin Development Guide

## Overview

OpenCLI plugins extend the platform with custom functionality. Plugins are written in Dart and run in isolated Isolates for security and stability.

## Quick Start

### 1. Create Plugin Directory

```bash
mkdir -p ~/.opencli/plugins/my-plugin
cd ~/.opencli/plugins/my-plugin
```

### 2. Create Plugin Manifest

Create `plugin.yaml`:

```yaml
name: my-plugin
version: 1.0.0
description: My awesome OpenCLI plugin
author: Your Name
license: MIT

capabilities:
  - hello
  - goodbye

dependencies:
  http: ^1.1.0

requirements:
  dart_sdk: ">=3.0.0 <4.0.0"
  platforms:
    - macos
    - linux
    - windows

permissions:
  - network
  - filesystem.read
```

### 3. Implement Plugin

Create `lib/plugin.dart`:

```dart
import 'package:opencli_plugin_api/plugin.dart';

class MyPlugin extends Plugin {
  @override
  String get name => 'my-plugin';

  @override
  String get version => '1.0.0';

  @override
  List<String> get capabilities => ['hello', 'goodbye'];

  @override
  Future<void> initialize() async {
    print('MyPlugin initialized');
  }

  @override
  Future<dynamic> execute(
    String action,
    List<dynamic> params,
    Map<String, dynamic> context,
  ) async {
    switch (action) {
      case 'hello':
        return _handleHello(params);
      case 'goodbye':
        return _handleGoodbye(params);
      default:
        throw Exception('Unknown action: $action');
    }
  }

  Future<String> _handleHello(List<dynamic> params) async {
    final name = params.isNotEmpty ? params[0] : 'World';
    return 'Hello, $name!';
  }

  Future<String> _handleGoodbye(List<dynamic> params) async {
    final name = params.isNotEmpty ? params[0] : 'World';
    return 'Goodbye, $name!';
  }

  @override
  ValidationResult validate(String action, List<dynamic> params) {
    if (action == 'hello' || action == 'goodbye') {
      return ValidationResult.valid();
    }
    return ValidationResult.invalid('Unknown action: $action');
  }

  @override
  String getHelp(String action) {
    switch (action) {
      case 'hello':
        return 'Say hello to someone. Usage: my-plugin.hello [name]';
      case 'goodbye':
        return 'Say goodbye to someone. Usage: my-plugin.goodbye [name]';
      default:
        return 'No help available for: $action';
    }
  }

  @override
  Future<Map<String, dynamic>> saveState() async {
    return {}; // Save any state needed for hot-reload
  }

  @override
  Future<void> restoreState(Map<String, dynamic> state) async {
    // Restore state after hot-reload
  }

  @override
  Future<void> dispose() async {
    print('MyPlugin disposed');
  }
}
```

### 4. Enable Plugin

Edit `~/.opencli/config.yaml`:

```yaml
plugins:
  enabled:
    - my-plugin
```

### 5. Test Plugin

```bash
opencli my-plugin.hello Alice
# Output: Hello, Alice!
```

## Plugin API Reference

### Plugin Base Class

```dart
abstract class Plugin {
  /// Plugin name (must match manifest)
  String get name;

  /// Plugin version
  String get version;

  /// List of supported capabilities
  List<String> get capabilities;

  /// Initialize plugin (called once on load)
  Future<void> initialize();

  /// Execute an action
  Future<dynamic> execute(
    String action,
    List<dynamic> params,
    Map<String, dynamic> context,
  );

  /// Validate parameters before execution
  ValidationResult validate(String action, List<dynamic> params);

  /// Get help text for an action
  String getHelp(String action);

  /// Save state (for hot-reload)
  Future<Map<String, dynamic>> saveState();

  /// Restore state (after hot-reload)
  Future<void> restoreState(Map<String, dynamic> state);

  /// Clean up resources
  Future<void> dispose();
}
```

### Validation Result

```dart
class ValidationResult {
  final bool isValid;
  final String? error;
  final List<String>? suggestions;

  ValidationResult.valid();
  ValidationResult.invalid(String error, {List<String>? suggestions});
}
```

## Permissions

### Available Permissions

| Permission | Description |
|------------|-------------|
| `network` | Access to HTTP/HTTPS requests |
| `filesystem.read` | Read files from disk |
| `filesystem.write` | Write files to disk |
| `process.spawn` | Spawn child processes |

### Requesting Permissions

In `plugin.yaml`:

```yaml
permissions:
  - network
  - filesystem.write
```

### Checking Permissions

```dart
class MyPlugin extends Plugin {
  Future<String> downloadFile(String url) async {
    // Permission automatically checked by daemon
    // Throws PermissionDeniedException if not granted

    final response = await http.get(Uri.parse(url));
    return response.body;
  }
}
```

## Context Information

The `context` parameter provides environment information:

```dart
Future<dynamic> execute(
  String action,
  List<dynamic> params,
  Map<String, dynamic> context,
) async {
  final projectPath = context['project_path'];
  final currentFile = context['current_file'];
  final workingDir = context['working_dir'];

  // Use context for environment-aware actions
}
```

## Hot-Reload Support

Implement `saveState` and `restoreState` for hot-reload:

```dart
class MyPlugin extends Plugin {
  int _counter = 0;

  @override
  Future<Map<String, dynamic>> saveState() async {
    return {'counter': _counter};
  }

  @override
  Future<void> restoreState(Map<String, dynamic> state) async {
    _counter = state['counter'] ?? 0;
  }
}
```

## Error Handling

### Throw Descriptive Errors

```dart
Future<String> myAction(List<dynamic> params) async {
  if (params.isEmpty) {
    throw ArgumentError('Missing required parameter: filename');
  }

  final file = File(params[0]);
  if (!await file.exists()) {
    throw FileSystemException('File not found: ${params[0]}');
  }

  // ... process file
}
```

### Custom Error Types

```dart
class PluginException implements Exception {
  final String message;
  final String? suggestion;

  PluginException(this.message, {this.suggestion});

  @override
  String toString() {
    final msg = 'PluginException: $message';
    return suggestion != null ? '$msg\nSuggestion: $suggestion' : msg;
  }
}
```

## Best Practices

### 1. Validate Parameters Early

```dart
@override
ValidationResult validate(String action, List<dynamic> params) {
  if (action == 'process_file') {
    if (params.isEmpty) {
      return ValidationResult.invalid(
        'Missing filename',
        suggestions: ['Usage: process_file <filename>'],
      );
    }
  }
  return ValidationResult.valid();
}
```

### 2. Provide Helpful Error Messages

```dart
if (!await file.exists()) {
  throw PluginException(
    'File not found: ${file.path}',
    suggestion: 'Check the file path and try again',
  );
}
```

### 3. Use Async Properly

```dart
// Good - sequential when needed
final config = await loadConfig();
final data = await processData(config);

// Good - parallel when possible
final results = await Future.wait([
  fetchDataA(),
  fetchDataB(),
  fetchDataC(),
]);
```

### 4. Clean Up Resources

```dart
@override
Future<void> dispose() async {
  await _httpClient.close();
  await _database.close();
  _timer?.cancel();
}
```

## Testing Plugins

### Unit Tests

```dart
import 'package:test/test.dart';
import 'package:my_plugin/plugin.dart';

void main() {
  late MyPlugin plugin;

  setUp(() async {
    plugin = MyPlugin();
    await plugin.initialize();
  });

  tearDown(() async {
    await plugin.dispose();
  });

  test('hello action returns greeting', () async {
    final result = await plugin.execute('hello', ['Alice'], {});
    expect(result, equals('Hello, Alice!'));
  });

  test('validation fails for unknown action', () {
    final result = plugin.validate('unknown', []);
    expect(result.isValid, isFalse);
  });
}
```

### Integration Tests

Test with live daemon:

```bash
# Start daemon
opencli daemon start

# Test plugin
opencli my-plugin.hello World

# Check logs
tail -f ~/.opencli/logs/opencli.log
```

## Publishing Plugins

1. Create repository with plugin code
2. Tag version: `git tag v1.0.0`
3. Publish to pub.dev (optional)
4. Submit to OpenCLI plugin registry

## Example Plugins

See the `plugins/` directory for examples:
- `flutter-skill`: Flutter app automation
- `ai-assistants`: AI model integration
- `custom-scripts`: Custom script runner

## Troubleshooting

### Plugin Not Loading

Check daemon logs:
```bash
tail -f ~/.opencli/logs/opencli.log
```

Common issues:
- Missing `plugin.yaml`
- Invalid Dart syntax
- Missing dependencies
- Permission errors

### Hot-Reload Not Working

Ensure `saveState` and `restoreState` are implemented properly.

### Performance Issues

- Use caching for expensive operations
- Avoid synchronous blocking calls
- Profile with DevTools
