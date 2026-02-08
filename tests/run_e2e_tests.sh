#!/bin/bash
# OpenCLI E2E Test Runner
#
# This script runs the comprehensive E2E test suite for OpenCLI.
# The tests require the daemon to be running.

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  OpenCLI E2E Test Suite${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check if dependencies are installed
if [ ! -d ".dart_tool" ]; then
    echo -e "${YELLOW}📦 Installing test dependencies...${NC}"
    dart pub get
    echo ""
fi

# Parse arguments
TEST_FILE=""
VERBOSE=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -f|--file)
            TEST_FILE="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -v, --verbose    Show verbose test output"
            echo "  -d, --dry-run    Show what would be tested without running"
            echo "  -f, --file FILE  Run specific test file"
            echo "  -h, --help       Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                                    # Run all tests"
            echo "  $0 -v                                 # Run with verbose output"
            echo "  $0 -f e2e/mobile_to_ai_flow_test.dart # Run specific test"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

# Function to check if daemon is running
check_daemon() {
    if curl -s http://localhost:9875/health > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Check daemon status
echo -e "${BLUE}🔍 Checking daemon status...${NC}"
if check_daemon; then
    echo -e "${GREEN}✅ Daemon is running and healthy${NC}"
else
    echo -e "${YELLOW}⚠️  Daemon is not running${NC}"
    echo ""
    echo -e "${YELLOW}The E2E tests require the daemon to be running.${NC}"
    echo -e "${YELLOW}Please start the daemon first:${NC}"
    echo ""
    echo -e "  ${BLUE}cd ../daemon${NC}"
    echo -e "  ${BLUE}dart run bin/daemon.dart --mode personal${NC}"
    echo ""
    echo -e "${YELLOW}Or run in another terminal:${NC}"
    echo ""
    echo -e "  ${BLUE}./scripts/start_daemon.sh${NC}"
    echo ""
    exit 1
fi

echo ""

# Determine what to test
if [ -n "$TEST_FILE" ]; then
    TEST_TARGET="$TEST_FILE"
    echo -e "${BLUE}📝 Running test file: ${TEST_FILE}${NC}"
else
    TEST_TARGET="e2e/"
    echo -e "${BLUE}📝 Running all E2E tests${NC}"
fi

echo ""

# Dry run mode
if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}🏃 Dry run mode - showing test structure:${NC}"
    echo ""
    dart test --dry-run "$TEST_TARGET"
    exit 0
fi

# Run tests
echo -e "${GREEN}🧪 Running tests...${NC}"
echo ""

if [ "$VERBOSE" = true ]; then
    dart test -r expanded "$TEST_TARGET"
else
    dart test "$TEST_TARGET"
fi

TEST_EXIT_CODE=$?

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [ $TEST_EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✅ All tests passed!${NC}"
else
    echo -e "${RED}❌ Some tests failed${NC}"
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

exit $TEST_EXIT_CODE
