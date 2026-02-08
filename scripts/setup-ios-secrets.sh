#!/bin/bash

# OpenCLI Mobile - iOS Secrets Setup Script
# This script helps configure GitHub Secrets for iOS App Store releases

set -e

echo "🍎 OpenCLI Mobile - iOS Secrets Setup"
echo "======================================"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo -e "${RED}❌ GitHub CLI (gh) is not installed${NC}"
    echo "Install it with: brew install gh"
    exit 1
fi

# Check if logged in to GitHub
if ! gh auth status &> /dev/null; then
    echo -e "${RED}❌ Not logged in to GitHub${NC}"
    echo "Run: gh auth login"
    exit 1
fi

echo -e "${GREEN}✅ GitHub CLI is ready${NC}"
echo ""

# Function to set secret
set_secret() {
    local secret_name=$1
    local secret_value=$2

    if [ -z "$secret_value" ]; then
        echo -e "${YELLOW}⏭️  Skipping $secret_name (empty value)${NC}"
        return
    fi

    echo "$secret_value" | gh secret set "$secret_name"
    echo -e "${GREEN}✅ Set secret: $secret_name${NC}"
}

# Function to set secret from file
set_secret_from_file() {
    local secret_name=$1
    local file_path=$2

    if [ ! -f "$file_path" ]; then
        echo -e "${YELLOW}⚠️  File not found: $file_path${NC}"
        echo -e "${YELLOW}⏭️  Skipping $secret_name${NC}"
        return 1
    fi

    # Base64 encode the file
    local encoded=$(base64 -i "$file_path")
    set_secret "$secret_name" "$encoded"
}

echo "📝 This script will guide you through setting up iOS secrets."
echo "You'll need:"
echo "  1. App Store Connect API Key (.p8 file)"
echo "  2. Distribution Certificate (.p12 file)"
echo "  3. Provisioning Profile (.mobileprovision file)"
echo ""
echo "Press Enter to continue or Ctrl+C to exit..."
read

# ===========================
# App Store Connect API Key
# ===========================

echo ""
echo "1️⃣  App Store Connect API Key"
echo "================================"
echo ""
echo "Get your API key from:"
echo "  https://appstoreconnect.apple.com → Users and Access → Keys"
echo ""

read -p "API Key ID (e.g., ABC123XYZ): " API_KEY_ID
read -p "Issuer ID: " ISSUER_ID
read -p "Path to .p8 file: " API_KEY_FILE

# Expand tilde
API_KEY_FILE="${API_KEY_FILE/#\~/$HOME}"

if [ -f "$API_KEY_FILE" ]; then
    set_secret "APP_STORE_CONNECT_API_KEY_ID" "$API_KEY_ID"
    set_secret "APP_STORE_CONNECT_ISSUER_ID" "$ISSUER_ID"
    set_secret_from_file "APP_STORE_CONNECT_API_KEY_BASE64" "$API_KEY_FILE"
    echo -e "${GREEN}✅ App Store Connect API Key configured${NC}"
else
    echo -e "${RED}❌ API Key file not found: $API_KEY_FILE${NC}"
    echo "Skipping API Key configuration"
fi

# ===========================
# Distribution Certificate
# ===========================

echo ""
echo "2️⃣  Distribution Certificate"
echo "============================="
echo ""
echo "Export your distribution certificate from Keychain Access:"
echo "  1. Open Keychain Access"
echo "  2. Find 'Apple Distribution: Your Name'"
echo "  3. Right-click → Export"
echo "  4. Save as .p12 file with a password"
echo ""

read -p "Path to .p12 file: " CERT_FILE
read -sp "Certificate password: " CERT_PASSWORD
echo ""

# Expand tilde
CERT_FILE="${CERT_FILE/#\~/$HOME}"

if [ -f "$CERT_FILE" ]; then
    set_secret_from_file "DISTRIBUTION_CERTIFICATE_BASE64" "$CERT_FILE"
    set_secret "DISTRIBUTION_CERTIFICATE_PASSWORD" "$CERT_PASSWORD"
    echo -e "${GREEN}✅ Distribution Certificate configured${NC}"
else
    echo -e "${RED}❌ Certificate file not found: $CERT_FILE${NC}"
    echo "Skipping certificate configuration"
fi

# ===========================
# Provisioning Profile
# ===========================

echo ""
echo "3️⃣  Provisioning Profile"
echo "========================"
echo ""
echo "Download from Apple Developer Portal:"
echo "  https://developer.apple.com/account/resources/profiles"
echo "  1. Create 'App Store' profile for com.opencli.mobile"
echo "  2. Download the .mobileprovision file"
echo ""

read -p "Path to .mobileprovision file: " PROFILE_FILE

# Expand tilde
PROFILE_FILE="${PROFILE_FILE/#\~/$HOME}"

if [ -f "$PROFILE_FILE" ]; then
    set_secret_from_file "PROVISIONING_PROFILE_BASE64" "$PROFILE_FILE"
    echo -e "${GREEN}✅ Provisioning Profile configured${NC}"
else
    echo -e "${RED}❌ Provisioning Profile not found: $PROFILE_FILE${NC}"
    echo "Skipping provisioning profile configuration"
fi

# ===========================
# Keychain Password
# ===========================

echo ""
echo "4️⃣  Keychain Password"
echo "====================="
echo ""
echo "Set a password for the CI keychain (can be anything):"
read -sp "Keychain password: " KEYCHAIN_PASSWORD
echo ""

if [ -n "$KEYCHAIN_PASSWORD" ]; then
    set_secret "KEYCHAIN_PASSWORD" "$KEYCHAIN_PASSWORD"
    echo -e "${GREEN}✅ Keychain password configured${NC}"
fi

# ===========================
# Summary
# ===========================

echo ""
echo "📊 Setup Summary"
echo "================"
echo ""

gh secret list | grep -E "(APP_STORE|DISTRIBUTION|PROVISIONING|KEYCHAIN)" || echo "No iOS secrets found"

echo ""
echo -e "${GREEN}✅ iOS Secrets Setup Complete!${NC}"
echo ""
echo "Next steps:"
echo "  1. Test the workflow: gh workflow run ios-app-store.yml"
echo "  2. Or create a git tag: git tag v0.1.2 && git push origin v0.1.2"
echo ""
echo "Documentation:"
echo "  docs/MOBILE_AUTO_RELEASE_SETUP.md"
echo ""
