#!/bin/bash

# Screenshot Generation Script for OpenCLI Mobile
# This script automates screenshot capture for app store submission

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SCREENSHOTS_DIR="$PROJECT_DIR/app_store_materials/screenshots"

echo "📸 OpenCLI Mobile - Screenshot Generator"
echo "========================================"
echo ""

# Create screenshot directories
mkdir -p "$SCREENSHOTS_DIR/android/phone"
mkdir -p "$SCREENSHOTS_DIR/android/tablet"
mkdir -p "$SCREENSHOTS_DIR/ios/6.7"
mkdir -p "$SCREENSHOTS_DIR/ios/6.5"
mkdir -p "$SCREENSHOTS_DIR/ios/5.5"

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter not found. Please install Flutter first."
    exit 1
fi

echo "✅ Flutter found: $(flutter --version | head -n 1)"
echo ""

# Function to run app and wait for user
run_and_capture() {
    local device=$1
    local output_dir=$2
    local device_name=$3

    echo "📱 Starting app on $device_name..."
    echo "   Device: $device"
    echo "   Output: $output_dir"
    echo ""
    echo "   Instructions:"
    echo "   1. Wait for app to launch"
    echo "   2. Navigate to each page (Tasks, Status, Settings)"
    echo "   3. Take screenshots using:"
    echo "      - Android Emulator: Click camera icon or Cmd+S"
    echo "      - iOS Simulator: Cmd+S"
    echo "   4. Press Ctrl+C to stop when done"
    echo ""

    cd "$PROJECT_DIR"
    flutter run --release -d "$device" || true
}

# Show menu
echo "Select screenshot generation option:"
echo ""
echo "1. Android Phone (1080x1920)"
echo "2. Android Tablet 7\" (1920x1200)"
echo "3. iOS 6.7\" - iPhone 14 Pro Max (1290x2796)"
echo "4. iOS 6.5\" - iPhone 11 Pro Max (1242x2688)"
echo "5. iOS 5.5\" - iPhone 8 Plus (1242x2208)"
echo "6. All Android"
echo "7. All iOS"
echo "8. List available devices"
echo "9. Manual instructions only"
echo ""
read -p "Enter choice (1-9): " choice

case $choice in
    1)
        echo ""
        echo "Starting Android Phone screenshot session..."
        run_and_capture "emulator" "$SCREENSHOTS_DIR/android/phone" "Android Emulator"
        ;;
    2)
        echo ""
        echo "Starting Android Tablet screenshot session..."
        run_and_capture "emulator" "$SCREENSHOTS_DIR/android/tablet" "Android Tablet"
        ;;
    3)
        echo ""
        echo "Starting iOS 6.7\" screenshot session..."
        run_and_capture "iPhone 14 Pro Max" "$SCREENSHOTS_DIR/ios/6.7" "iPhone 14 Pro Max"
        ;;
    4)
        echo ""
        echo "Starting iOS 6.5\" screenshot session..."
        run_and_capture "iPhone 11 Pro Max" "$SCREENSHOTS_DIR/ios/6.5" "iPhone 11 Pro Max"
        ;;
    5)
        echo ""
        echo "Starting iOS 5.5\" screenshot session..."
        run_and_capture "iPhone 8 Plus" "$SCREENSHOTS_DIR/ios/5.5" "iPhone 8 Plus"
        ;;
    6)
        echo ""
        echo "📱 Android Screenshot Guide"
        echo "=========================="
        echo ""
        echo "1. Start Android Emulator (Pixel 4 or similar)"
        echo "2. Run: flutter run --release"
        echo "3. Navigate to each page and take screenshots"
        echo "4. Screenshots are saved to: ~/Desktop or Emulator controls"
        echo "5. Move screenshots to: $SCREENSHOTS_DIR/android/phone/"
        echo ""
        ;;
    7)
        echo ""
        echo "📱 iOS Screenshot Guide"
        echo "======================"
        echo ""
        echo "For each device size:"
        echo ""
        echo "iPhone 14 Pro Max (6.7\"):"
        echo "  open -a Simulator --args -CurrentDeviceName 'iPhone 14 Pro Max'"
        echo "  flutter run --release"
        echo "  Take screenshots with Cmd+S"
        echo "  Move from Desktop to: $SCREENSHOTS_DIR/ios/6.7/"
        echo ""
        echo "iPhone 11 Pro Max (6.5\"):"
        echo "  open -a Simulator --args -CurrentDeviceName 'iPhone 11 Pro Max'"
        echo "  flutter run --release"
        echo "  Take screenshots with Cmd+S"
        echo "  Move from Desktop to: $SCREENSHOTS_DIR/ios/6.5/"
        echo ""
        echo "iPhone 8 Plus (5.5\"):"
        echo "  open -a Simulator --args -CurrentDeviceName 'iPhone 8 Plus'"
        echo "  flutter run --release"
        echo "  Take screenshots with Cmd+S"
        echo "  Move from Desktop to: $SCREENSHOTS_DIR/ios/5.5/"
        echo ""
        ;;
    8)
        echo ""
        echo "📱 Available Devices:"
        echo "==================="
        flutter devices
        ;;
    9)
        cat << 'EOF'

📸 Manual Screenshot Instructions
==================================

Required Screenshots:
--------------------

Android Phone (2-8 screenshots):
  Size: 1080 x 1920 or higher
  Format: PNG or JPG
  Suggested screens:
    1. Tasks page with "Submit New Task" button
    2. Status page showing daemon status
    3. Settings page
    4. Dark mode example

iOS Screenshots (3-10 per size):

  6.7" Display (iPhone 14 Pro Max):
    Size: 1290 x 2796 pixels
    Required: Yes

  6.5" Display (iPhone 11 Pro Max):
    Size: 1242 x 2688 pixels
    Required: Yes

  5.5" Display (iPhone 8 Plus):
    Size: 1242 x 2208 pixels
    Required: Yes

Screenshot Capture Methods:
--------------------------

Android Emulator:
  - Click camera icon in emulator toolbar
  - Or press Cmd+S (Mac) / Ctrl+S (Windows)
  - Screenshots saved to Desktop

iOS Simulator:
  - Press Cmd+S while simulator is active
  - Screenshots saved to Desktop
  - File name includes device and timestamp

Physical Device:
  - Android: Power + Volume Down
  - iOS: Side button + Volume Up
  - Transfer via USB or AirDrop

Screenshot Enhancement:
----------------------

Optional tools to add device frames and backgrounds:
  - Figma: https://www.figma.com
  - Screenshot.rocks: https://screenshot.rocks
  - App Mockup: https://app-mockup.com
  - Appure: https://appure.io

Tips:
-----
  - Use release build for clean UI
  - Capture in both light and dark mode
  - Show actual content, not empty states
  - Keep text readable
  - Highlight key features
  - Maintain consistent styling

Save screenshots to:
  $SCREENSHOTS_DIR/

EOF
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "✅ Screenshot generation complete!"
echo ""
echo "📁 Screenshots location: $SCREENSHOTS_DIR"
echo ""
echo "Next steps:"
echo "1. Review and rename screenshots descriptively"
echo "2. Optionally add device frames using screenshot.rocks or Figma"
echo "3. Follow the submission guides in docs/"
echo ""
