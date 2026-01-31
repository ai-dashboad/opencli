# Creating Required Release Repositories - Detailed Guide

This guide will help you create the repositories required for the OpenCLI automated release system.

---

## 📦 Repositories to Create

### 1. homebrew-tap

**Repository Name**: `homebrew-tap`
**Full Path**: `https://github.com/ai-dashboad/homebrew-tap`
**Purpose**: Stores Homebrew formula for macOS/Linux users to install via `brew install`

### 2. scoop-bucket

**Repository Name**: `scoop-bucket`
**Full Path**: `https://github.com/ai-dashboad/scoop-bucket`
**Purpose**: Stores Scoop manifest for Windows users to install via `scoop install`

---

## 🚀 Creation Steps

### Method 1: Via GitHub Web Interface (Recommended)

#### Create homebrew-tap Repository

1. **Visit**: https://github.com/new

2. **Fill in Information**:
   - Repository name: `homebrew-tap`
   - Description: `Homebrew formula for OpenCLI`
   - Visibility: ✅ Public (must be Public)
   - ❌ Don't check "Add a README file"
   - ❌ Don't add .gitignore
   - ❌ Don't select License

3. **Click**: Create repository

4. **Initialize Repository** (execute locally):

```bash
# Create temporary directory
mkdir -p /tmp/homebrew-tap
cd /tmp/homebrew-tap

# Initialize Git repository
git init
git branch -M main

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

The formula will be automatically updated by GitHub Actions when new versions are released.
EOF

# Create Formula directory
mkdir -p Formula

# Create placeholder formula (will be auto-updated)
cat > Formula/opencli.rb << 'EOF'
class Opencli < Formula
  desc "Universal AI Development Platform"
  homepage "https://opencli.ai"
  version "0.1.0"
  license "MIT"

  # This formula will be automatically updated by GitHub Actions
  # when new releases are published

  def install
    raise "This formula is not yet populated. Please wait for the first release."
  end
end
EOF

# Commit and push
git add .
git commit -m "Initial commit for homebrew-tap"
git remote add origin https://github.com/ai-dashboad/homebrew-tap.git
git push -u origin main
```

---

#### Create scoop-bucket Repository

1. **Visit**: https://github.com/new

2. **Fill in Information**:
   - Repository name: `scoop-bucket`
   - Description: `Scoop bucket for OpenCLI`
   - Visibility: ✅ Public (must be Public)
   - ❌ Don't check "Add a README file"
   - ❌ Don't add .gitignore
   - ❌ Don't select License

3. **Click**: Create repository

4. **Initialize Repository** (execute locally):

```bash
# Create temporary directory
mkdir -p /tmp/scoop-bucket
cd /tmp/scoop-bucket

# Initialize Git repository
git init
git branch -M main

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

The manifest will be automatically updated by GitHub Actions when new versions are released.
EOF

# Create placeholder manifest (will be auto-updated)
cat > opencli.json << 'EOF'
{
  "version": "0.1.0",
  "description": "Universal AI Development Platform",
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
  }
}
EOF

# Commit and push
git add .
git commit -m "Initial commit for scoop-bucket"
git remote add origin https://github.com/ai-dashboad/scoop-bucket.git
git push -u origin main
```

---

### Method 2: Via GitHub CLI (Faster)

```bash
# Ensure gh CLI is installed
gh --version

# Login to GitHub
gh auth login

# Create homebrew-tap repository
gh repo create ai-dashboad/homebrew-tap \
  --public \
  --description "Homebrew formula for OpenCLI" \
  --clone

cd homebrew-tap
# Create README and Formula directory (refer to Method 1 commands)
mkdir -p Formula
# ... copy file creation commands from Method 1 ...
git add .
git commit -m "Initial commit"
git push origin main

# Create scoop-bucket repository
cd ..
gh repo create ai-dashboad/scoop-bucket \
  --public \
  --description "Scoop bucket for OpenCLI" \
  --clone

cd scoop-bucket
# Create README and manifest (refer to Method 1 commands)
# ... copy file creation commands from Method 1 ...
git add .
git commit -m "Initial commit"
git push origin main
```

---

## 🔑 Configure GitHub Secrets

After creating repositories, configure GitHub Personal Access Tokens:

### Step 1: Create Personal Access Token

1. **Visit**: https://github.com/settings/tokens/new

2. **Fill in Information**:
   - Note: `OpenCLI Release Automation`
   - Expiration: `No expiration` (or select longer duration)
   - Scopes (permissions):
     - ✅ `repo` (complete repository access)
       - ✅ repo:status
       - ✅ repo_deployment
       - ✅ public_repo
       - ✅ repo:invite
       - ✅ security_events

3. **Click**: Generate token

4. **Copy token** (⚠️ shown only once, save immediately!)

### Step 2: Add Secrets to Main Repository

1. **Visit**: https://github.com/ai-dashboad/opencli/settings/secrets/actions

2. **Click**: New repository secret

3. **Add HOMEBREW_TAP_TOKEN**:
   - Name: `HOMEBREW_TAP_TOKEN`
   - Secret: Paste the token you just copied
   - Click Add secret

4. **Add SCOOP_BUCKET_TOKEN**:
   - Name: `SCOOP_BUCKET_TOKEN`
   - Secret: Paste the same token (can be reused)
   - Click Add secret

---

## ✅ Verify Configuration

After creating repositories and configuring Secrets, verify everything is working:

### Verification 1: Repository Accessible

```bash
# Verify homebrew-tap
curl -I https://github.com/ai-dashboad/homebrew-tap
# Should return HTTP/2 200

# Verify scoop-bucket
curl -I https://github.com/ai-dashboad/scoop-bucket
# Should return HTTP/2 200
```

### Verification 2: Token Permissions

```bash
# Test if token has push permissions
gh auth status

# Or test using API
curl -H "Authorization: token YOUR_TOKEN" \
  https://api.github.com/repos/ai-dashboad/homebrew-tap
```

### Verification 3: Secrets Configuration

1. Visit: https://github.com/ai-dashboad/opencli/settings/secrets/actions
2. Confirm you see:
   - ✅ HOMEBREW_TAP_TOKEN
   - ✅ SCOOP_BUCKET_TOKEN

---

## 📝 Completion Checklist

- [ ] Create `homebrew-tap` repository
- [ ] Initialize `homebrew-tap` repository (README + Formula/)
- [ ] Create `scoop-bucket` repository
- [ ] Initialize `scoop-bucket` repository (README + manifest)
- [ ] Create GitHub Personal Access Token
- [ ] Add `HOMEBREW_TAP_TOKEN` secret
- [ ] Add `SCOOP_BUCKET_TOKEN` secret
- [ ] Verify repositories are accessible
- [ ] Verify Secrets are configured

---

## 🎯 Next Steps

After completing the above steps, you can:

1. ✅ Delete failed v0.1.1-beta.1 tag
2. ✅ Push fixed code
3. ✅ Release v0.1.1-beta.2 for testing
4. ✅ Verify Homebrew and Scoop auto-update is working

---

## 🆘 Troubleshooting

### Issue: Permission denied when pushing to repository

**Solution**:
- Ensure token has `repo` permission
- Regenerate token and update Secrets

### Issue: GitHub Actions cannot access repository

**Solution**:
- Ensure repository is Public
- Check Secret name is correct
- View Actions logs for detailed errors

### Issue: Repository initialization failed

**Solution**:
```bash
# If remote already has content, pull first
git pull origin main --rebase

# If force push is needed (first time only)
git push -u origin main --force
```

---

**Creation Time**: 2026-01-31
**Status**: Ready
**Estimated Time**: 10-15 minutes
