#!/bin/bash
# Restart OpenCLI Menubar App
# This fixes the "menu items not clickable" issue

echo "🔄 Restarting OpenCLI Menubar App..."

# Stop current app
echo "1️⃣  Stopping current menubar app..."
pkill -f "opencli_app.app/Contents/MacOS/opencli_app"
sleep 2

# Check if stopped
if ps aux | grep -v grep | grep "opencli_app.app" > /dev/null; then
    echo "⚠️  App still running, force killing..."
    pkill -9 -f "opencli_app.app"
    sleep 1
fi

echo "✅ App stopped"

# Restart app
echo "2️⃣  Starting menubar app..."
cd /Users/cw/development/opencli/opencli_app

# Run in background
nohup flutter run -d macos > /tmp/opencli-menubar-restart.log 2>&1 &

echo "✅ App starting... (check /tmp/opencli-menubar-restart.log for logs)"
echo ""
echo "The menubar icon should appear shortly."
echo "All menu items should now be clickable."
