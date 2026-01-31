# Flutter Skill Plugin

Flutter app automation and testing plugin for OpenCLI.

## Features

- 🚀 Launch Flutter apps on any device
- 🔍 Inspect UI elements and widget tree
- 📸 Take screenshots
- 👆 Tap, scroll, and interact with UI
- 🔥 Hot reload support
- 🧭 Navigation control
- ⏰ Wait for elements with timeout

## Usage

### Launch App

```bash
opencli flutter.launch --device=macos
opencli flutter.launch --device=ios --project=/path/to/app
```

### Connect to Running App

```bash
opencli flutter.connect ws://127.0.0.1:54321/ws
```

### UI Interaction

```bash
# Tap on element by key
opencli flutter.tap --key=login_button

# Tap on element by text
opencli flutter.tap --text="Submit"

# Enter text
opencli flutter.enter_text --key=username_field --text=user@example.com

# Scroll to element
opencli flutter.scroll_to --key=bottom_widget
```

### Screenshots

```bash
opencli flutter.screenshot
opencli flutter.screenshot --path=my_screenshot.png
```

### Hot Reload

```bash
opencli flutter.hot_reload
```

### Navigation

```bash
# Get current route
opencli flutter.get_route

# Go back
opencli flutter.go_back
```

### Inspection

```bash
# Get all interactive elements
opencli flutter.inspect
```

## Configuration

Add to `~/.opencli/config.yaml`:

```yaml
plugins:
  flutter-skill:
    default_device: macos
    screenshot_format: png
    auto_hot_reload: true
    timeout_seconds: 30
```

## Supported Devices

- macOS (desktop)
- iOS (simulator/device)
- Android (emulator/device)
- Linux (desktop)
- Windows (desktop)
- Web (Chrome)

## Requirements

- Flutter SDK installed
- `flutter` command in PATH
- VM Service enabled in app (automatic in debug mode)

## Advanced Usage

### Wait for Element

```bash
opencli flutter.wait_for --key=loading_indicator --timeout=5000
```

### Complex Gestures

```bash
# Long press
opencli flutter.long_press --key=context_menu

# Double tap
opencli flutter.double_tap --key=zoom_target

# Swipe
opencli flutter.swipe --direction=up --distance=300

# Drag
opencli flutter.drag --from=item1 --to=dropzone
```

## Troubleshooting

### App Won't Launch

- Check Flutter SDK: `flutter doctor`
- Verify device is available: `flutter devices`
- Check project path is correct

### Cannot Connect to VM Service

- Ensure app is in debug mode
- Check firewall settings
- Verify VM Service URI is correct

### Element Not Found

- Use `inspect` to list all elements
- Check element keys in widget code
- Increase timeout for slow-loading elements

## Examples

See `examples/` directory for complete automation scripts.
