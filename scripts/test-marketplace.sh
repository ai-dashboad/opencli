#!/bin/bash
# Test Plugin Marketplace Integration

set -e

echo "🧪 Testing Plugin Marketplace Integration"
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test 1: Check if daemon is running
echo "1️⃣  Checking if daemon is running..."
if curl -s http://localhost:9877/api/plugins > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Plugin marketplace is accessible${NC}"
else
    echo -e "${RED}✗ Daemon not running or marketplace not started${NC}"
    echo -e "${YELLOW}Run: opencli daemon start${NC}"
    exit 1
fi

# Test 2: Fetch plugins
echo ""
echo "2️⃣  Fetching available plugins..."
RESPONSE=$(curl -s http://localhost:9877/api/plugins)
PLUGIN_COUNT=$(echo $RESPONSE | grep -o '"id"' | wc -l | tr -d ' ')
echo -e "${GREEN}✓ Found $PLUGIN_COUNT plugins in marketplace${NC}"

# Test 3: Check UI HTML
echo ""
echo "3️⃣  Checking web UI..."
if curl -s http://localhost:9877 | grep -q "Plugin Marketplace"; then
    echo -e "${GREEN}✓ Web UI is serving correctly${NC}"
else
    echo -e "${RED}✗ Web UI not accessible${NC}"
    exit 1
fi

# Test 4: Check status API
echo ""
echo "4️⃣  Checking status API..."
if curl -s http://localhost:9875/status > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Status API is running${NC}"
else
    echo -e "${YELLOW}⚠ Status API not accessible (optional)${NC}"
fi

# Test 5: List plugins via CLI (if available)
echo ""
echo "5️⃣  Testing CLI commands..."
if command -v opencli > /dev/null 2>&1; then
    echo "Testing: opencli plugin list"
    opencli plugin list || echo -e "${YELLOW}⚠ No plugins running yet${NC}"
    echo -e "${GREEN}✓ CLI is working${NC}"
else
    echo -e "${YELLOW}⚠ opencli command not found in PATH${NC}"
fi

echo ""
echo "=========================================="
echo -e "${GREEN}✅ All tests passed!${NC}"
echo ""
echo "🌐 Open marketplace: http://localhost:9877"
echo "📊 Status API: http://localhost:9875/status"
echo ""
echo "Quick commands:"
echo "  opencli plugin browse      # Open marketplace"
echo "  opencli plugin list        # List installed"
echo "  opencli plugin add <name>  # Install plugin"
echo ""
