#!/bin/bash

# 编译增强版 OpenCLI 菜单栏应用

cd "$(dirname "$0")"

echo "🔨 Building OpenCLI MenuBar (Enhanced)..."

# 编译 Swift 代码
swiftc -o OpenCLI OpenCLIMenuBar_Enhanced.swift \
  -framework Cocoa \
  -framework Foundation \
  -framework UserNotifications

if [ $? -eq 0 ]; then
    echo "✅ Build successful!"

    # 创建 .app 包结构
    rm -rf OpenCLI.app
    mkdir -p OpenCLI.app/Contents/MacOS
    mkdir -p OpenCLI.app/Contents/Resources

    # 移动可执行文件
    mv OpenCLI OpenCLI.app/Contents/MacOS/

    # 创建 Info.plist
    cat > OpenCLI.app/Contents/Info.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>OpenCLI</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.opencli.menubar</string>
    <key>CFBundleName</key>
    <string>OpenCLI</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.2.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

    echo "✅ OpenCLI.app created successfully!"
    echo "📍 Location: $(pwd)/OpenCLI.app"
    echo ""
    echo "🚀 To launch: open OpenCLI.app"
else
    echo "❌ Build failed!"
    exit 1
fi
