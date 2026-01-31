#!/bin/bash
set -e

echo "Building OpenCLI - All Platforms"
echo "================================"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Build CLI (Rust)
echo -e "${BLUE}Building Rust CLI...${NC}"
cd cli
cargo build --release
echo -e "${GREEN}✓ CLI built successfully${NC}"
cd ..

# Build Daemon (Dart)
echo -e "${BLUE}Building Dart Daemon...${NC}"
cd daemon
dart pub get
dart compile exe bin/daemon.dart -o opencli-daemon
echo -e "${GREEN}✓ Daemon built successfully${NC}"
cd ..

# Create distribution directory
echo -e "${BLUE}Creating distribution...${NC}"
mkdir -p dist/bin

# Copy binaries
cp cli/target/release/opencli dist/bin/
cp daemon/opencli-daemon dist/bin/

# Copy configuration
cp -r config dist/
cp -r docs dist/

# Create archive
cd dist
tar -czf ../opencli-$(uname -s)-$(uname -m).tar.gz *
cd ..

echo -e "${GREEN}✓ Build complete!${NC}"
echo "Archive: opencli-$(uname -s)-$(uname -m).tar.gz"
