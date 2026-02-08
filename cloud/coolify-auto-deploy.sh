#!/bin/bash
# Automatic deployment to Coolify via API
# Usage: ./coolify-auto-deploy.sh

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
COOLIFY_URL="${COOLIFY_URL:-https://cicd.dtok.io}"
COOLIFY_API_TOKEN="${COOLIFY_API_TOKEN:-}"
GITHUB_REPO="ai-dashboad/opencli"
GITHUB_BRANCH="main"

echo -e "${BLUE}🚀 OpenCLI Coolify Auto-Deployment${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if API token is provided
if [ -z "$COOLIFY_API_TOKEN" ]; then
    echo -e "${YELLOW}⚠️  Coolify API token not found${NC}"
    echo ""
    echo "Please provide your Coolify API token:"
    echo "1. Go to ${COOLIFY_URL}/security/api-tokens"
    echo "2. Create a new API token"
    echo "3. Set it as environment variable:"
    echo ""
    echo "   export COOLIFY_API_TOKEN=your_token_here"
    echo ""
    read -p "Or enter token now: " COOLIFY_API_TOKEN

    if [ -z "$COOLIFY_API_TOKEN" ]; then
        echo -e "${RED}❌ API token is required${NC}"
        exit 1
    fi
fi

# Check if GitHub token is provided
if [ -z "$GITHUB_TOKEN" ]; then
    echo -e "${YELLOW}⚠️  GitHub token not found${NC}"
    read -sp "Enter GitHub token (ghp_...): " GITHUB_TOKEN
    echo ""

    if [ -z "$GITHUB_TOKEN" ]; then
        echo -e "${RED}❌ GitHub token is required${NC}"
        exit 1
    fi
fi

# API Headers
API_HEADERS="Authorization: Bearer $COOLIFY_API_TOKEN"

echo -e "${GREEN}✓ Credentials configured${NC}"
echo ""

# Function to make API calls
coolify_api() {
    local method=$1
    local endpoint=$2
    local data=$3

    if [ -z "$data" ]; then
        curl -s -X "$method" \
            -H "$API_HEADERS" \
            -H "Content-Type: application/json" \
            "${COOLIFY_URL}/api/v1${endpoint}"
    else
        curl -s -X "$method" \
            -H "$API_HEADERS" \
            -H "Content-Type: application/json" \
            -d "$data" \
            "${COOLIFY_URL}/api/v1${endpoint}"
    fi
}

echo "📋 Step 1: Checking Coolify connection..."
if coolify_api GET "/ping" | grep -q "pong"; then
    echo -e "${GREEN}✓ Connected to Coolify${NC}"
else
    echo -e "${RED}❌ Failed to connect to Coolify${NC}"
    echo "   Please check:"
    echo "   - URL: $COOLIFY_URL"
    echo "   - API Token validity"
    exit 1
fi
echo ""

echo "📋 Step 2: Getting team and project info..."
TEAMS=$(coolify_api GET "/teams")
TEAM_ID=$(echo "$TEAMS" | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)

if [ -z "$TEAM_ID" ]; then
    echo -e "${RED}❌ Failed to get team ID${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Team ID: $TEAM_ID${NC}"
echo ""

echo "📋 Step 3: Creating Capability CDN application..."
CDN_CONFIG=$(cat <<EOF
{
  "name": "opencli-capability-cdn",
  "description": "OpenCLI Capability Package Repository",
  "team_id": $TEAM_ID,
  "source": {
    "type": "github",
    "repository": "$GITHUB_REPO",
    "branch": "$GITHUB_BRANCH",
    "dockerfile_location": "cloud/capability-cdn/Dockerfile",
    "build_command": "",
    "install_command": "",
    "start_command": ""
  },
  "destination": {
    "network": "coolifyproxy"
  },
  "environment_variables": [],
  "domains": [
    {
      "domain": "opencli.ai",
      "path": "/api/capabilities"
    }
  ],
  "ports": [
    {
      "published": 80,
      "target": 80,
      "protocol": "tcp"
    }
  ],
  "health_check": {
    "enabled": true,
    "path": "/health",
    "interval": 30,
    "timeout": 3,
    "retries": 3
  },
  "auto_deploy": true
}
EOF
)

CDN_RESPONSE=$(coolify_api POST "/applications" "$CDN_CONFIG")
CDN_ID=$(echo "$CDN_RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -n "$CDN_ID" ]; then
    echo -e "${GREEN}✓ CDN application created: $CDN_ID${NC}"
else
    echo -e "${YELLOW}⚠️  CDN creation response: $CDN_RESPONSE${NC}"
    echo -e "${YELLOW}   (may already exist)${NC}"
fi
echo ""

echo "📋 Step 4: Creating Telemetry API application..."
API_CONFIG=$(cat <<EOF
{
  "name": "opencli-telemetry-api",
  "description": "OpenCLI Telemetry and Error Reporting API",
  "team_id": $TEAM_ID,
  "source": {
    "type": "github",
    "repository": "$GITHUB_REPO",
    "branch": "$GITHUB_BRANCH",
    "dockerfile_location": "cloud/telemetry-api/Dockerfile",
    "build_command": "",
    "install_command": "",
    "start_command": ""
  },
  "destination": {
    "network": "coolifyproxy"
  },
  "environment_variables": [
    {
      "key": "GITHUB_TOKEN",
      "value": "$GITHUB_TOKEN",
      "is_build_time": false,
      "is_preview": false
    },
    {
      "key": "GITHUB_OWNER",
      "value": "ai-dashboad",
      "is_build_time": false,
      "is_preview": false
    },
    {
      "key": "GITHUB_REPO",
      "value": "opencli",
      "is_build_time": false,
      "is_preview": false
    },
    {
      "key": "PORT",
      "value": "3000",
      "is_build_time": false,
      "is_preview": false
    }
  ],
  "domains": [
    {
      "domain": "opencli.ai",
      "path": "/api/telemetry"
    }
  ],
  "ports": [
    {
      "published": 3000,
      "target": 3000,
      "protocol": "tcp"
    }
  ],
  "health_check": {
    "enabled": true,
    "path": "/health",
    "interval": 30,
    "timeout": 3,
    "retries": 3
  },
  "auto_deploy": true
}
EOF
)

API_RESPONSE=$(coolify_api POST "/applications" "$API_CONFIG")
API_ID=$(echo "$API_RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -n "$API_ID" ]; then
    echo -e "${GREEN}✓ API application created: $API_ID${NC}"
else
    echo -e "${YELLOW}⚠️  API creation response: $API_RESPONSE${NC}"
    echo -e "${YELLOW}   (may already exist)${NC}"
fi
echo ""

echo "📋 Step 5: Deploying applications..."

# Deploy CDN
if [ -n "$CDN_ID" ]; then
    echo "  Deploying CDN..."
    coolify_api POST "/applications/$CDN_ID/deploy" '{"force": false}'
    echo -e "${GREEN}  ✓ CDN deployment triggered${NC}"
fi

# Deploy API
if [ -n "$API_ID" ]; then
    echo "  Deploying API..."
    coolify_api POST "/applications/$API_ID/deploy" '{"force": false}'
    echo -e "${GREEN}  ✓ API deployment triggered${NC}"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✅ Deployment initiated successfully!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Services are now building and deploying..."
echo ""
echo "Monitor progress:"
echo "  Dashboard: ${COOLIFY_URL}/applications"
if [ -n "$CDN_ID" ]; then
    echo "  CDN:       ${COOLIFY_URL}/applications/$CDN_ID"
fi
if [ -n "$API_ID" ]; then
    echo "  API:       ${COOLIFY_URL}/applications/$API_ID"
fi
echo ""
echo "Endpoints (once deployed):"
echo "  CDN:  https://opencli.ai/api/capabilities/manifest.json"
echo "  API:  https://opencli.ai/api/telemetry/health"
echo ""
echo "Verify deployment:"
echo "  curl https://opencli.ai/health"
echo "  curl https://opencli.ai/api/telemetry/health"
echo ""
