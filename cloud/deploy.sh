#!/bin/bash
# Deploy OpenCLI Cloud Services to Coolify
# Usage: ./deploy.sh [service] [coolify-url]

set -e

SERVICE=${1:-all}
COOLIFY_URL=${2:-https://cicd.dtok.io}

echo "🚀 OpenCLI Cloud Deployment"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Service: $SERVICE"
echo "Coolify: $COOLIFY_URL"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check prerequisites
check_prerequisites() {
    echo "📋 Checking prerequisites..."

    if ! command -v docker &> /dev/null; then
        echo -e "${RED}❌ Docker is not installed${NC}"
        exit 1
    fi

    if ! command -v git &> /dev/null; then
        echo -e "${RED}❌ Git is not installed${NC}"
        exit 1
    fi

    if [ -z "$GITHUB_TOKEN" ]; then
        echo -e "${YELLOW}⚠️  GITHUB_TOKEN not set${NC}"
        read -sp "Enter your GitHub token: " GITHUB_TOKEN
        echo ""
        export GITHUB_TOKEN
    fi

    echo -e "${GREEN}✓ Prerequisites OK${NC}\n"
}

# Build capability CDN
build_cdn() {
    echo "🔨 Building Capability CDN..."

    cd capability-cdn
    docker build -t opencli-capability-cdn -f Dockerfile ..

    echo -e "${GREEN}✓ CDN built successfully${NC}\n"
}

# Build telemetry API
build_api() {
    echo "🔨 Building Telemetry API..."

    cd telemetry-api
    docker build -t opencli-telemetry-api .

    echo -e "${GREEN}✓ API built successfully${NC}\n"
}

# Deploy with docker-compose
deploy_local() {
    echo "🚢 Deploying locally..."

    docker-compose down
    docker-compose up -d

    echo -e "${GREEN}✓ Services deployed${NC}\n"

    # Wait for services to start
    echo "⏳ Waiting for services to start..."
    sleep 5

    # Check health
    check_health_local
}

# Check service health (local)
check_health_local() {
    echo "🏥 Checking service health..."

    # Check CDN
    if curl -sf http://localhost:8080/health > /dev/null; then
        echo -e "${GREEN}✓ CDN is healthy${NC}"
    else
        echo -e "${RED}❌ CDN is not responding${NC}"
    fi

    # Check API
    if curl -sf http://localhost:3000/health > /dev/null; then
        echo -e "${GREEN}✓ API is healthy${NC}"
    else
        echo -e "${RED}❌ API is not responding${NC}"
    fi

    echo ""
}

# Deploy to Coolify (via Coolify CLI or API)
deploy_coolify() {
    echo "🌐 Deploying to Coolify..."
    echo ""
    echo "Please follow these steps:"
    echo ""
    echo "1. Go to ${COOLIFY_URL}"
    echo "2. Create a new 'Docker Compose' resource"
    echo "3. Paste the contents of cloud/docker-compose.yml"
    echo "4. Add environment variable: GITHUB_TOKEN=${GITHUB_TOKEN:0:10}..."
    echo "5. Set domain: opencli.ai"
    echo "6. Click 'Deploy'"
    echo ""
    echo "Or use Coolify CLI (if available):"
    echo ""
    echo "  coolify app:create --name opencli --compose cloud/docker-compose.yml"
    echo ""
}

# Print deployment info
print_info() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 Deployment Information"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Services:"
    echo "  • CDN:  http://localhost:8080"
    echo "  • API:  http://localhost:3000"
    echo ""
    echo "Endpoints:"
    echo "  • Manifest: http://localhost:8080/api/capabilities/manifest.json"
    echo "  • Health:   http://localhost:8080/health"
    echo "  • Health:   http://localhost:3000/health"
    echo "  • Report:   http://localhost:3000/api/telemetry/report"
    echo ""
    echo "Testing:"
    echo "  curl http://localhost:8080/health"
    echo "  curl http://localhost:3000/health"
    echo ""
    echo "Logs:"
    echo "  docker logs -f opencli-capability-cdn"
    echo "  docker logs -f opencli-telemetry-api"
    echo ""
}

# Main deployment flow
main() {
    check_prerequisites

    cd "$(dirname "$0")"

    case $SERVICE in
        cdn)
            build_cdn
            ;;
        api)
            build_api
            ;;
        all)
            deploy_local
            print_info
            echo ""
            echo -e "${YELLOW}To deploy to Coolify production:${NC}"
            deploy_coolify
            ;;
        coolify)
            deploy_coolify
            ;;
        *)
            echo -e "${RED}Unknown service: $SERVICE${NC}"
            echo "Usage: $0 [cdn|api|all|coolify] [coolify-url]"
            exit 1
            ;;
    esac
}

main
