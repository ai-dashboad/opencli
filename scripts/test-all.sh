#!/bin/bash
set -e

echo "Running All Tests"
echo "================="

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

FAILED=0

# Test CLI
echo -e "${BLUE}Testing Rust CLI...${NC}"
cd cli
if cargo test; then
    echo -e "${GREEN}✓ CLI tests passed${NC}"
else
    echo -e "${RED}✗ CLI tests failed${NC}"
    FAILED=1
fi
cd ..

# Test Daemon
echo -e "${BLUE}Testing Dart Daemon...${NC}"
cd daemon
if dart test; then
    echo -e "${GREEN}✓ Daemon tests passed${NC}"
else
    echo -e "${RED}✗ Daemon tests failed${NC}"
    FAILED=1
fi
cd ..

# Test Flutter Skill Plugin
echo -e "${BLUE}Testing Flutter Skill Plugin...${NC}"
cd plugins/flutter-skill
dart pub get
if dart test; then
    echo -e "${GREEN}✓ Plugin tests passed${NC}"
else
    echo -e "${RED}✗ Plugin tests failed${NC}"
    FAILED=1
fi
cd ../..

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed${NC}"
    exit 1
fi
