#!/bin/bash

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_error() { echo -e "${RED}❌ $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }

echo -e "${BLUE}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║  OpenCLI Release Repositories Setup                       ║
║  Creating homebrew-tap and scoop-bucket repositories      ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    print_error "GitHub CLI (gh) is not installed"
    print_info "Install it from: https://cli.github.com/"
    exit 1
fi

# Check if authenticated
if ! gh auth status &> /dev/null; then
    print_error "Not authenticated with GitHub"
    print_info "Run: gh auth login"
    exit 1
fi

ORG="ai-dashboad"
print_info "Organization: $ORG"
echo ""

# Create homebrew-tap repository
print_info "Creating homebrew-tap repository..."
echo ""

if gh repo view "$ORG/homebrew-tap" &> /dev/null; then
    print_warning "Repository $ORG/homebrew-tap already exists"
else
    gh repo create "$ORG/homebrew-tap" \
        --public \
        --description "Homebrew formula for OpenCLI" \
        --clone

    cd homebrew-tap

    # Create README
    cat > README.md << 'EOF'
# Homebrew Tap for OpenCLI

Official Homebrew tap for [OpenCLI](https://github.com/ai-dashboad/opencli).

## Installation

```bash
brew tap ai-dashboad/tap
brew install opencli
```

## Updating

```bash
brew update
brew upgrade opencli
```

## Uninstall

```bash
brew uninstall opencli
brew untap ai-dashboad/tap
```

## Formula

The formula is automatically updated by GitHub Actions when new versions are released.
EOF

    # Create Formula directory
    mkdir -p Formula

    # Create placeholder formula
    cat > Formula/opencli.rb << 'EOF'
class Opencli < Formula
  desc "Universal AI Development Platform - Enterprise Autonomous Company Operating System"
  homepage "https://opencli.ai"
  version "0.1.0"
  license "MIT"

  # This formula will be automatically updated by GitHub Actions

  def install
    raise "This formula is not yet populated. Please wait for the first release."
  end

  test do
    system "false"
  end
end
EOF

    git add .
    git commit -m "Initial commit for homebrew-tap

- Add README with installation instructions
- Create Formula directory structure
- Add placeholder opencli.rb formula

This repository will be automatically updated by GitHub Actions
when new releases are published to ai-dashboad/opencli."

    git push -u origin main

    cd ..
    print_success "Created and initialized homebrew-tap repository"
fi

echo ""

# Create scoop-bucket repository
print_info "Creating scoop-bucket repository..."
echo ""

if gh repo view "$ORG/scoop-bucket" &> /dev/null; then
    print_warning "Repository $ORG/scoop-bucket already exists"
else
    gh repo create "$ORG/scoop-bucket" \
        --public \
        --description "Scoop bucket for OpenCLI" \
        --clone

    cd scoop-bucket

    # Create README
    cat > README.md << 'EOF'
# Scoop Bucket for OpenCLI

Official Scoop bucket for [OpenCLI](https://github.com/ai-dashboad/opencli).

## Installation

```powershell
scoop bucket add opencli https://github.com/ai-dashboad/scoop-bucket
scoop install opencli
```

## Updating

```powershell
scoop update opencli
```

## Uninstall

```powershell
scoop uninstall opencli
```

## Manifest

The manifest is automatically updated by GitHub Actions when new versions are released.
EOF

    # Create placeholder manifest
    cat > opencli.json << 'EOF'
{
  "version": "0.1.0",
  "description": "Universal AI Development Platform - Enterprise Autonomous Company Operating System",
  "homepage": "https://opencli.ai",
  "license": "MIT",
  "architecture": {
    "64bit": {
      "url": "https://github.com/ai-dashboad/opencli/releases/download/v0.1.0/opencli-windows-x86_64.exe",
      "hash": ""
    }
  },
  "bin": [["opencli-windows-x86_64.exe", "opencli"]],
  "checkver": {
    "github": "https://github.com/ai-dashboad/opencli"
  },
  "autoupdate": {
    "architecture": {
      "64bit": {
        "url": "https://github.com/ai-dashboad/opencli/releases/download/v$version/opencli-windows-x86_64.exe"
      }
    }
  },
  "post_install": [
    "Write-Host '✅ OpenCLI installed successfully!' -ForegroundColor Green",
    "Write-Host ''",
    "Write-Host 'Quick Start:' -ForegroundColor Yellow",
    "Write-Host '  1. Start daemon:  opencli daemon start'",
    "Write-Host '  2. Submit task:   opencli task submit \"Your task\"'",
    "Write-Host '  3. Check status:  opencli status'",
    "Write-Host ''",
    "Write-Host 'Documentation: https://docs.opencli.ai' -ForegroundColor Cyan"
  ]
}
EOF

    git add .
    git commit -m "Initial commit for scoop-bucket

- Add README with installation instructions
- Add placeholder opencli.json manifest

This repository will be automatically updated by GitHub Actions
when new releases are published to ai-dashboad/opencli."

    git push -u origin main

    cd ..
    print_success "Created and initialized scoop-bucket repository"
fi

echo ""
echo -e "${GREEN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║  ✅ Repository Setup Complete!                            ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

print_info "Repositories created:"
echo "  • https://github.com/$ORG/homebrew-tap"
echo "  • https://github.com/$ORG/scoop-bucket"
echo ""

print_warning "Next Steps:"
echo ""
echo "1. Create GitHub Personal Access Token:"
echo "   https://github.com/settings/tokens/new"
echo ""
echo "2. Add Secrets to main repository:"
echo "   https://github.com/$ORG/opencli/settings/secrets/actions"
echo ""
echo "   Required secrets:"
echo "   - HOMEBREW_TAP_TOKEN (the token you just created)"
echo "   - SCOOP_BUCKET_TOKEN (same token)"
echo ""
echo "3. Push fixes and test new release:"
echo "   git push origin main"
echo "   ./scripts/release.sh 0.1.1-beta.2 \"Fix build issues and test automation\""
echo ""

print_success "All done! 🎉"
