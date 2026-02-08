#!/bin/bash
# Automated Google Play submission script
# This script provides step-by-step guidance for browser automation

set -e

echo "🚀 OpenCLI Google Play Automation Helper"
echo "========================================="
echo ""

# Check if AAB exists
AAB_PATH="opencli_mobile/build/app/outputs/bundle/release/app-release.aab"
if [ ! -f "$AAB_PATH" ]; then
    echo "❌ AAB file not found at: $AAB_PATH"
    echo "Building now..."
    cd opencli_mobile
    flutter build appbundle --release
    cd ..
fi

echo "✅ AAB file ready: $AAB_PATH"
echo "   Size: $(du -h "$AAB_PATH" | cut -f1)"
echo ""

# Step 1: GitHub Pages
echo "📋 Step 1: Enable GitHub Pages"
echo "------------------------------"
echo "URL: https://github.com/ai-dashboad/opencli/settings/pages"
echo ""
echo "Actions:"
echo "  1. Source: Deploy from a branch"
echo "  2. Branch: main"
echo "  3. Folder: /docs"
echo "  4. Click Save"
echo ""
echo "Verify: https://ai-dashboad.github.io/opencli/privacy.html"
echo ""
read -p "Press Enter when GitHub Pages is enabled..."
echo ""

# Step 2: Data Safety Form
echo "📋 Step 2: Fill Data Safety Form"
echo "---------------------------------"
echo "URL: https://play.google.com/console/u/0/developers/6298343753806217215/policy-center"
echo ""
echo "Quick Answers:"
echo "  ✓ Collect data? → Yes"
echo "  ✓ Device IDs? → Yes (Required)"
echo "  ✓ Audio? → Yes (Optional, Ephemeral)"
echo "  ✓ Crash logs? → Yes (Optional)"
echo "  ✓ Encrypted? → Yes"
echo "  ✓ Data deletion? → Yes"
echo "  ✓ Privacy URL: https://ai-dashboad.github.io/opencli/privacy.html"
echo ""
echo "Detailed guide: docs/DATA_SAFETY_DECLARATION.md"
echo ""
read -p "Press Enter when Data Safety form is submitted..."
echo ""

# Step 3: Upload Release
echo "📋 Step 3: Upload New Release"
echo "------------------------------"
echo "URL: https://play.google.com/console (Production track)"
echo ""
echo "Steps:"
echo "  1. Click 'Create new release'"
echo "  2. Upload: $AAB_PATH"
echo "  3. Release notes:"
echo ""
cat << 'EOF'
v0.2.1 - Policy Compliance & Security Update

✨ What's New
• Enhanced privacy protection with comprehensive policy
• Improved microphone permission handling
• Better security compliance

🔧 Bug Fixes
• Fixed permission request flow
• Resolved policy compliance issues
• Updated app localization to English

🔒 Security & Privacy
• End-to-end encryption
• Local data processing
• Transparent data practices
EOF
echo ""
echo "  4. Review release → Start rollout to production"
echo ""
read -p "Press Enter when release is submitted..."
echo ""

# Summary
echo "✅ All steps completed!"
echo "======================"
echo ""
echo "📧 You should receive confirmation emails from:"
echo "   • GitHub (Pages deployed)"
echo "   • Google Play (Review started)"
echo ""
echo "⏰ Expected timeline:"
echo "   • GitHub Pages: Active immediately"
echo "   • Google review: 1-3 business days"
echo "   • App goes live: Immediately after approval"
echo ""
echo "📊 Track progress at:"
echo "   https://play.google.com/console"
echo ""
echo "🎉 Good luck with your submission!"
