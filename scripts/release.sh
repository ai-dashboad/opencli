#!/bin/bash

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print functions
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }

# Check if running in git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    print_error "Not a git repository"
    exit 1
fi

# Check arguments
if [ $# -lt 1 ]; then
    print_error "Usage: $0 <version> [description]"
    echo ""
    echo "Examples:"
    echo "  $0 1.0.0 \"Initial release\""
    echo "  $0 1.0.1 \"Bug fixes and performance improvements\""
    echo "  $0 1.1.0-beta.1 \"Beta release with new features\""
    exit 1
fi

VERSION=$1
DESCRIPTION=${2:-"Release $VERSION"}

# Validate version format (SemVer)
if ! [[ $VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.-]+)?(\+[a-zA-Z0-9.-]+)?$ ]]; then
    print_error "Invalid version format: $VERSION"
    print_info "Version must follow Semantic Versioning (e.g., 1.0.0, 1.0.0-beta.1)"
    exit 1
fi

print_info "Preparing release v$VERSION..."
echo ""

# Check for uncommitted changes
if ! git diff-index --quiet HEAD --; then
    print_error "You have uncommitted changes. Please commit or stash them first."
    git status --short
    exit 1
fi

# Check if we're on main branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$CURRENT_BRANCH" != "main" ]; then
    print_warning "You are not on the main branch (current: $CURRENT_BRANCH)"
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check if tag already exists
if git rev-parse "v$VERSION" >/dev/null 2>&1; then
    print_error "Tag v$VERSION already exists"
    exit 1
fi

# Pull latest changes
print_info "Pulling latest changes..."
git pull origin $CURRENT_BRANCH

# Step 1: Update version numbers in all files
print_info "Updating version numbers..."
if ! dart scripts/bump_version.dart "$VERSION"; then
    print_error "Failed to update version numbers"
    exit 1
fi
echo ""

# Step 2: Update CHANGELOG.md
print_info "Updating CHANGELOG.md..."
CHANGELOG_FILE="CHANGELOG.md"
TEMP_CHANGELOG="temp_changelog.md"
CURRENT_DATE=$(date +%Y-%m-%d)

# Create CHANGELOG.md if it doesn't exist
if [ ! -f "$CHANGELOG_FILE" ]; then
    cat > "$CHANGELOG_FILE" << 'EOF'
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

EOF
fi

# Create new changelog entry
cat > "$TEMP_CHANGELOG" << EOF
## [$VERSION] - $CURRENT_DATE

### Added
- $DESCRIPTION

### Changed

### Fixed

### Deprecated

### Removed

### Security

EOF

# Append existing changelog (skip the header)
tail -n +6 "$CHANGELOG_FILE" >> "$TEMP_CHANGELOG"

# Add back the header
{
    head -n 5 "$CHANGELOG_FILE"
    echo ""
    tail -n +6 "$TEMP_CHANGELOG"
} > "$CHANGELOG_FILE"

rm "$TEMP_CHANGELOG"
print_success "Updated CHANGELOG.md"
echo ""

# Step 3: Run documentation sync (if script exists)
if [ -f "scripts/sync_docs.dart" ]; then
    print_info "Syncing documentation..."
    if dart scripts/sync_docs.dart; then
        print_success "Documentation synced"
    else
        print_warning "Failed to sync documentation (continuing anyway)"
    fi
    echo ""
fi

# Step 4: Show changes
print_info "Changes to be committed:"
git status --short
echo ""

# Step 5: Confirm release
print_warning "You are about to create release v$VERSION"
echo "Description: $DESCRIPTION"
echo ""
read -p "Continue with release? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_info "Release cancelled"
    # Revert changes
    git checkout -- .
    exit 0
fi

# Step 6: Commit changes
print_info "Creating release commit..."
git add .
git commit -m "Release v$VERSION

$DESCRIPTION

- Updated version to $VERSION
- Updated CHANGELOG.md
- Synced documentation across all packages
"

print_success "Created release commit"
echo ""

# Step 7: Create annotated tag
print_info "Creating git tag v$VERSION..."
git tag -a "v$VERSION" -m "$VERSION - $DESCRIPTION"
print_success "Created tag v$VERSION"
echo ""

# Step 8: Push to remote
print_info "Pushing to remote..."
if git push origin $CURRENT_BRANCH --follow-tags; then
    print_success "Pushed to remote successfully"
else
    print_error "Failed to push to remote"
    print_info "You can manually push using: git push origin $CURRENT_BRANCH --follow-tags"
    exit 1
fi

echo ""
print_success "🎉 Release v$VERSION created successfully!"
echo ""
print_info "GitHub Actions will now:"
echo "  1. Build binaries for all platforms"
echo "  2. Create GitHub Release with auto-generated notes"
echo "  3. Publish to Homebrew, Scoop, Winget, npm, etc."
echo "  4. Build and push Docker images"
echo "  5. Update MCP Markets"
echo ""
print_info "Monitor the release at:"
echo "  https://github.com/$(git config --get remote.origin.url | sed 's/.*github.com[:/]\(.*\)\.git/\1/')/actions"
echo ""
