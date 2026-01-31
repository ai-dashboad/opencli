# OpenCLI Test Suite

Comprehensive test suite for OpenCLI platform.

## Test Structure

```
tests/
├── unit/              # Unit tests
│   ├── cli_test.rs   # Rust CLI tests
│   └── daemon_test.dart  # Dart daemon tests
├── integration/       # Integration tests
│   ├── ipc_test.dart     # IPC communication
│   └── cache_test.dart   # Cache system
└── e2e/              # End-to-end tests
    └── full_workflow_test.dart
```

## Running Tests

### All Tests

```bash
make test
# or
./scripts/test-all.sh
```

### Unit Tests Only

**Rust CLI:**
```bash
cd cli
cargo test
```

**Dart Daemon:**
```bash
cd daemon
dart test tests/unit
```

### Integration Tests

```bash
cd daemon
dart test tests/integration
```

### End-to-End Tests

```bash
cd daemon
dart test tests/e2e
```

## Test Coverage

Target coverage: >80% for all modules

**Check coverage:**

```bash
# Rust
cd cli
cargo tarpaulin

# Dart
cd daemon
dart pub global activate coverage
dart test --coverage=coverage
genhtml coverage/lcov.info -o coverage/html
```

## Performance Tests

Performance benchmarks with strict requirements:

- Cold start: <10ms
- Hot call: <2ms
- IPC latency: <2ms
- Cache hit (L1): <1ms
- Memory (idle): <50MB

**Run benchmarks:**

```bash
cd cli
cargo bench
```

## Writing Tests

### Unit Test Example

```dart
test('should cache values', () {
  final cache = L1Cache(maxSize: 10);
  cache.put('key', 'value');

  expect(cache.get('key'), equals('value'));
});
```

### Integration Test Example

```dart
test('should handle IPC requests', () async {
  final socket = await Socket.connect(...);
  // Send request
  // Verify response
  await socket.close();
});
```

### E2E Test Example

```dart
test('complete workflow', () async {
  // Start daemon
  // Execute CLI
  // Verify result
  // Stop daemon
});
```

## Continuous Integration

Tests run automatically on:
- Every push to main/develop
- All pull requests
- Pre-release builds

See `.github/workflows/build.yml` for CI configuration.

## Test Data

Test fixtures and mock data in `tests/fixtures/`:
- Sample configurations
- Mock API responses
- Test plugins

## Troubleshooting

### Tests Timeout

Increase timeout in test files:
```dart
test('slow test', () async {
  // test code
}, timeout: Timeout(Duration(seconds: 60)));
```

### Port Already in Use

Kill existing daemon:
```bash
pkill -f opencli-daemon
```

### Permission Errors

Ensure test socket is writable:
```bash
chmod 600 /tmp/opencli-test.sock
```
