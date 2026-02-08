#!/bin/bash
# OpenCLI Coolify Setup and Deployment - Full Automation
# This script will guide you through token creation and automatically deploy

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
COOLIFY_URL="${COOLIFY_URL:-https://cicd.dtok.io}"
GITHUB_REPO="ai-dashboad/opencli"

echo -e "${BLUE}"
echo "╔════════════════════════════════════════════════════════╗"
echo "║   OpenCLI Coolify 自动部署向导                         ║"
echo "╚════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

# Step 1: Check for existing tokens
echo -e "${YELLOW}步骤 1/4: 检查现有 tokens...${NC}"
echo ""

TOKENS_FOUND=true

if [ -z "$COOLIFY_API_TOKEN" ]; then
    echo -e "${YELLOW}  ⚠️  COOLIFY_API_TOKEN 未找到${NC}"
    TOKENS_FOUND=false
fi

if [ -z "$GITHUB_TOKEN" ]; then
    echo -e "${YELLOW}  ⚠️  GITHUB_TOKEN 未找到${NC}"
    TOKENS_FOUND=false
fi

if [ "$TOKENS_FOUND" = true ]; then
    echo -e "${GREEN}  ✓ 所有 tokens 已配置${NC}"
    echo ""
else
    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}需要创建 tokens${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
    echo ""

    # Guide for GitHub Token
    if [ -z "$GITHUB_TOKEN" ]; then
        echo -e "${YELLOW}📝 创建 GitHub Token:${NC}"
        echo ""
        echo "  1. 我会自动打开 GitHub Token 创建页面"
        echo "  2. 点击 'Generate new token (classic)'"
        echo "  3. Token name: opencli-deployment"
        echo "  4. 勾选权限: ✅ repo (Full control)"
        echo "  5. 点击底部的 'Generate token'"
        echo "  6. 复制生成的 token (格式: ghp_xxxxx)"
        echo ""
        read -p "按回车键打开 GitHub Token 页面..."
        open "https://github.com/settings/tokens/new?description=opencli-deployment&scopes=repo" || \
        xdg-open "https://github.com/settings/tokens/new?description=opencli-deployment&scopes=repo" 2>/dev/null || \
        echo "  请手动访问: https://github.com/settings/tokens/new"
        echo ""
        read -sp "  粘贴你的 GitHub Token: " GITHUB_TOKEN
        echo ""
        export GITHUB_TOKEN
        echo -e "${GREEN}  ✓ GitHub Token 已设置${NC}"
        echo ""
    fi

    # Guide for Coolify Token
    if [ -z "$COOLIFY_API_TOKEN" ]; then
        echo -e "${YELLOW}📝 创建 Coolify API Token:${NC}"
        echo ""
        echo "  1. 我会自动打开 Coolify API Token 创建页面"
        echo "  2. 点击 'Create New Token'"
        echo "  3. Name: opencli-deployment"
        echo "  4. 点击 'Create'"
        echo "  5. 复制生成的 token"
        echo ""
        read -p "按回车键打开 Coolify Token 页面..."
        open "${COOLIFY_URL}/security/api-tokens" || \
        xdg-open "${COOLIFY_URL}/security/api-tokens" 2>/dev/null || \
        echo "  请手动访问: ${COOLIFY_URL}/security/api-tokens"
        echo ""
        read -sp "  粘贴你的 Coolify Token: " COOLIFY_API_TOKEN
        echo ""
        export COOLIFY_API_TOKEN
        echo -e "${GREEN}  ✓ Coolify Token 已设置${NC}"
        echo ""
    fi
fi

# Save tokens to .env file for future use
echo "COOLIFY_API_TOKEN=$COOLIFY_API_TOKEN" > .env.local
echo "GITHUB_TOKEN=$GITHUB_TOKEN" >> .env.local
chmod 600 .env.local
echo -e "${GREEN}✓ Tokens 已保存到 .env.local${NC}"
echo ""

# Step 2: Verify Coolify connection
echo -e "${YELLOW}步骤 2/4: 验证 Coolify 连接...${NC}"

# Test connection
if curl -s -f -H "Authorization: Bearer $COOLIFY_API_TOKEN" \
   "${COOLIFY_URL}/api/v1/ping" > /dev/null 2>&1; then
    echo -e "${GREEN}  ✓ 成功连接到 Coolify${NC}"
else
    echo -e "${RED}  ❌ 无法连接到 Coolify${NC}"
    echo ""
    echo "  可能的原因:"
    echo "  - Token 无效"
    echo "  - Coolify URL 错误: $COOLIFY_URL"
    echo "  - 网络连接问题"
    echo ""
    read -p "是否继续? (y/n) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi
echo ""

# Step 3: Create applications in Coolify
echo -e "${YELLOW}步骤 3/4: 在 Coolify 中创建应用...${NC}"
echo ""

# Check if we can use Coolify API or need manual setup
echo -e "${BLUE}尝试通过 API 自动创建应用...${NC}"

# Try to run the auto-deploy script
if [ -f "./coolify-auto-deploy.sh" ]; then
    chmod +x ./coolify-auto-deploy.sh

    echo -e "${GREEN}运行自动部署脚本...${NC}"
    echo ""

    if ./coolify-auto-deploy.sh; then
        echo ""
        echo -e "${GREEN}✓ 应用创建成功！${NC}"
    else
        echo ""
        echo -e "${YELLOW}⚠️  API 创建失败，可能 Coolify API 版本不兼容${NC}"
        echo ""
        echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
        echo -e "${YELLOW}请手动在 Coolify UI 中创建应用${NC}"
        echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
        echo ""
        echo "我会打开 Coolify 和配置指南..."
        echo ""
        read -p "按回车继续..."

        # Open Coolify dashboard
        open "${COOLIFY_URL}" 2>/dev/null || xdg-open "${COOLIFY_URL}" 2>/dev/null || true

        # Open configuration guide
        open "COOLIFY_QUICK_START.md" 2>/dev/null || cat "COOLIFY_QUICK_START.md"

        echo ""
        echo "请按照 COOLIFY_QUICK_START.md 中的步骤操作"
        echo ""
        read -p "完成后按回车继续..."
    fi
else
    echo -e "${YELLOW}  自动部署脚本未找到，打开手动配置指南...${NC}"
    open "COOLIFY_QUICK_START.md" 2>/dev/null || cat "COOLIFY_QUICK_START.md"
fi

echo ""

# Step 4: Verify deployment
echo -e "${YELLOW}步骤 4/4: 验证部署...${NC}"
echo ""

echo "等待服务启动 (约 30 秒)..."
sleep 30

# Check CDN
echo -n "  检查 CDN... "
if curl -s -f "https://opencli.ai/health" > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${YELLOW}⚠️  (可能还在部署中)${NC}"
fi

# Check API
echo -n "  检查 API... "
if curl -s -f "https://opencli.ai/api/telemetry/health" > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${YELLOW}⚠️  (可能还在部署中)${NC}"
fi

echo ""
echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}🎉 部署完成！${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
echo ""
echo "服务地址:"
echo "  📦 CDN:  https://opencli.ai/api/capabilities/manifest.json"
echo "  🔔 API:  https://opencli.ai/api/telemetry/health"
echo ""
echo "Coolify 面板:"
echo "  🌐 ${COOLIFY_URL}"
echo ""
echo "验证命令:"
echo "  curl https://opencli.ai/health"
echo "  curl https://opencli.ai/api/telemetry/health"
echo ""
echo -e "${YELLOW}注意: 如果服务还在部署中，请等待几分钟后再测试${NC}"
echo ""

# Offer to update daemon configuration
echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}下一步: 更新 daemon 配置${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════${NC}"
echo ""
echo "需要更新以下文件以使用生产环境:"
echo "  • daemon/lib/capabilities/capability_loader.dart"
echo "  • daemon/lib/telemetry/issue_reporter.dart"
echo ""
read -p "是否自动更新配置文件? (y/n) " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo -e "${GREEN}更新配置文件...${NC}"

    # Update capability_loader.dart
    if [ -f "../daemon/lib/capabilities/capability_loader.dart" ]; then
        sed -i.bak "s|https://capabilities.opencli.io|https://opencli.ai/api/capabilities|g" \
            "../daemon/lib/capabilities/capability_loader.dart"
        echo "  ✓ 更新 capability_loader.dart"
    fi

    # Update issue_reporter.dart
    if [ -f "../daemon/lib/telemetry/issue_reporter.dart" ]; then
        sed -i.bak "s|http://localhost:3000|https://opencli.ai|g" \
            "../daemon/lib/telemetry/issue_reporter.dart"
        echo "  ✓ 更新 issue_reporter.dart"
    fi

    echo ""
    echo -e "${GREEN}✓ 配置已更新！${NC}"
    echo ""
    echo "现在可以提交并发布新版本了："
    echo "  git add ."
    echo "  git commit -m 'chore: update cloud endpoints to production'"
    echo "  git push"
fi

echo ""
echo -e "${GREEN}全部完成！ 🚀${NC}"
echo ""
