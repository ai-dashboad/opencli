# Contributing to OpenCLI

Thank you for your interest in contributing to OpenCLI!

## Development Setup

### Prerequisites

- Rust 1.70+ (for CLI client)
- Dart 3.0+ (for daemon)
- Git

### Clone and Build

```bash
git clone https://github.com/opencli/opencli.git
cd opencli

# Build CLI client
cd cli
cargo build

# Build daemon
cd ../daemon
dart pub get
dart compile exe bin/daemon.dart
```

## Code Style

### Rust
- Follow official Rust style guide
- Run `cargo fmt` before committing
- Run `cargo clippy` and fix warnings

### Dart
- Follow effective Dart guidelines
- Run `dart format .` before committing
- Run `dart analyze` and fix issues

## Testing

```bash
# Rust tests
cd cli
cargo test

# Dart tests
cd daemon
dart test
```

## Submitting Changes

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Pull Request Guidelines

- Write clear, descriptive commit messages
- Include tests for new features
- Update documentation as needed
- Ensure CI passes
- Keep PRs focused on a single feature/fix

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
