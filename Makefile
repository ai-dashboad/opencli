.PHONY: all build test clean install format lint

all: build

build:
	@echo "Building OpenCLI..."
	@./scripts/build-all.sh

test:
	@echo "Running tests..."
	@./scripts/test-all.sh

install:
	@echo "Installing OpenCLI..."
	@./scripts/install.sh

clean:
	@echo "Cleaning build artifacts..."
	@cd cli && cargo clean
	@rm -rf daemon/opencli-daemon
	@rm -rf dist/
	@rm -f *.tar.gz

format:
	@echo "Formatting code..."
	@cd cli && cargo fmt
	@cd daemon && dart format .
	@cd plugins/flutter-skill && dart format .

lint:
	@echo "Linting code..."
	@cd cli && cargo clippy -- -D warnings
	@cd daemon && dart analyze
	@cd plugins/flutter-skill && dart analyze

cli:
	@cd cli && cargo build --release

daemon:
	@cd daemon && dart compile exe bin/daemon.dart -o opencli-daemon

help:
	@echo "OpenCLI Build System"
	@echo ""
	@echo "Available targets:"
	@echo "  make build    - Build all components"
	@echo "  make test     - Run all tests"
	@echo "  make install  - Install to ~/.opencli"
	@echo "  make clean    - Clean build artifacts"
	@echo "  make format   - Format all code"
	@echo "  make lint     - Lint all code"
	@echo "  make cli      - Build CLI only"
	@echo "  make daemon   - Build daemon only"
