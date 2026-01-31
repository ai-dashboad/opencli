# OpenCLI - CLI Client (Rust)

High-performance command-line client for OpenCLI.

## Components

- **ArgumentParser**: Command-line argument parsing with clap
- **IpcClient**: Unix Socket communication client
- **ResourceManager**: Embedded resource extraction
- **ErrorHandler**: User-friendly error messages

## Build

```bash
cargo build --release
```

## Performance Targets

- Cold start: <10ms
- IPC latency: <2ms
- Binary size: <15MB
