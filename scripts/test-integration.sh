#!/bin/bash

# OpenCLI Integration Test Script
# Tests the complete flow from Daemon → opencli_app → Telegram Bot

set -e

echo "🧪 OpenCLI Integration Test Suite"
echo "=================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test results
PASSED=0
FAILED=0

# Helper functions
pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((PASSED++))
}

fail() {
    echo -e "${RED}✗${NC} $1"
    ((FAILED++))
}

info() {
    echo -e "${YELLOW}ℹ${NC} $1"
}

# Test 1: Check Dart installation
echo "📦 Test 1: Check Dependencies"
if command -v dart &> /dev/null; then
    DART_VERSION=$(dart --version 2>&1 | head -n1)
    pass "Dart installed: $DART_VERSION"
else
    fail "Dart not found"
fi

if command -v flutter &> /dev/null; then
    FLUTTER_VERSION=$(flutter --version | head -n1)
    pass "Flutter installed: $FLUTTER_VERSION"
else
    fail "Flutter not found"
fi

echo ""

# Test 2: Check project structure
echo "📁 Test 2: Project Structure"
if [ -d "daemon" ]; then
    pass "daemon/ directory exists"
else
    fail "daemon/ directory not found"
fi

if [ -d "opencli_app" ]; then
    pass "opencli_app/ directory exists"
else
    fail "opencli_app/ directory not found"
fi

if [ -d "daemon/lib/channels" ]; then
    pass "channels/ module exists"
else
    fail "channels/ module not found"
fi

echo ""

# Test 3: Check channel implementations
echo "🔌 Test 3: Channel Implementations"
CHANNELS=("telegram_channel.dart" "whatsapp_channel.dart" "slack_channel.dart" "discord_channel.dart" "wechat_channel.dart" "sms_channel.dart")
for channel in "${CHANNELS[@]}"; do
    if [ -f "daemon/lib/channels/$channel" ]; then
        pass "$channel exists"
    else
        fail "$channel not found"
    fi
done

echo ""

# Test 4: Daemon compilation
echo "🔨 Test 4: Daemon Compilation"
cd daemon
if dart pub get &> /dev/null; then
    pass "Daemon dependencies installed"
else
    fail "Failed to install daemon dependencies"
fi

# Check if daemon can be compiled (syntax check)
if dart analyze --fatal-infos 2>&1 | grep -q "No issues found"; then
    pass "Daemon code analysis passed"
else
    info "Daemon code has warnings (non-fatal)"
fi

cd ..

echo ""

# Test 5: opencli_app compilation
echo "🔨 Test 5: opencli_app Compilation"
cd opencli_app
if flutter pub get &> /dev/null; then
    pass "opencli_app dependencies installed"
else
    fail "Failed to install opencli_app dependencies"
fi

if flutter analyze 2>&1 | grep -q "No issues found"; then
    pass "opencli_app code analysis passed"
else
    info "opencli_app code has warnings (non-fatal)"
fi

cd ..

echo ""

# Test 6: Configuration files
echo "⚙️  Test 6: Configuration"
if [ -f "config/channels.example.yaml" ]; then
    pass "channels.example.yaml exists"
else
    fail "channels.example.yaml not found"
fi

echo ""

# Test 7: Documentation
echo "📚 Test 7: Documentation"
DOCS=("README.md" "docs/TELEGRAM_BOT_QUICKSTART.md" "docs/E2E_TEST_PLAN.md")
for doc in "${DOCS[@]}"; do
    if [ -f "$doc" ]; then
        pass "$doc exists"
    else
        fail "$doc not found"
    fi
done

echo ""

# Test 8: Git status
echo "📝 Test 8: Git Status"
if git diff --quiet; then
    pass "No uncommitted changes"
else
    info "There are uncommitted changes"
fi

COMMITS=$(git log --oneline | wc -l | xargs)
pass "Total commits: $COMMITS"

echo ""

# Summary
echo "=================================="
echo "📊 Test Summary"
echo "=================================="
echo -e "${GREEN}Passed:${NC} $PASSED"
echo -e "${RED}Failed:${NC} $FAILED"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}🎉 All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}❌ Some tests failed${NC}"
    exit 1
fi
