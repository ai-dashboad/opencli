#!/bin/bash

# Build OpenCLI Menu Bar App

echo "🔨 Building OpenCLI Menu Bar App..."

# Create app bundle structure
mkdir -p OpenCLI.app/Contents/MacOS
mkdir -p OpenCLI.app/Contents/Resources

# Compile Swift code
swiftc -o OpenCLI.app/Contents/MacOS/OpenCLI OpenCLIMenuBar.swift

# Create Info.plist
cat > OpenCLI.app/Contents/Info.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>OpenCLI</string>
    <key>CFBundleIdentifier</key>
    <string>ai.opencli.menubar</string>
    <key>CFBundleName</key>
    <string>OpenCLI</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

echo "✅ Build complete!"
echo ""
echo "To run the menu bar app:"
echo "  open OpenCLI.app"
echo ""
echo "To add to login items:"
echo "  System Settings → General → Login Items → Add OpenCLI.app"
