#!/bin/bash
# Update mobile app changelogs with current version

set -e

# Get current directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Read version from pubspec.yaml
VERSION=$(grep "^version:" "$PROJECT_ROOT/opencli_mobile/pubspec.yaml" | sed 's/version: //' | cut -d'+' -f1)
BUILD_NUMBER=$(grep "^version:" "$PROJECT_ROOT/opencli_mobile/pubspec.yaml" | sed 's/version: //' | cut -d'+' -f2)

echo "📋 Updating changelogs for version $VERSION (build $BUILD_NUMBER)"

# Update iOS release notes (already using default.txt)
IOS_NOTES="$PROJECT_ROOT/opencli_mobile/fastlane/metadata/en-US/release_notes.txt"
if [ -f "$IOS_NOTES" ]; then
    echo "✅ iOS release notes: $IOS_NOTES"
fi

# Create Android version-specific changelog
ANDROID_CHANGELOG_DIR="$PROJECT_ROOT/opencli_mobile/fastlane/metadata/android/en-US/changelogs"
mkdir -p "$ANDROID_CHANGELOG_DIR"

# Copy default changelog to version-specific file
if [ -f "$ANDROID_CHANGELOG_DIR/default.txt" ]; then
    cp "$ANDROID_CHANGELOG_DIR/default.txt" "$ANDROID_CHANGELOG_DIR/$BUILD_NUMBER.txt"
    echo "✅ Created Android changelog: $ANDROID_CHANGELOG_DIR/$BUILD_NUMBER.txt"
fi

echo "✨ Changelog update complete!"
echo "Version: $VERSION"
echo "Build: $BUILD_NUMBER"
