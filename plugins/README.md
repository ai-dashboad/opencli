# OpenCLI - Plugins

Plugin implementations for OpenCLI platform.

## Available Plugins

### flutter-skill
Flutter app automation and testing plugin.

**Capabilities:**
- Launch Flutter apps
- UI inspection
- Screenshots
- Tap/input interactions
- Hot reload

**Permissions:**
- network
- filesystem.read
- filesystem.write
- process.spawn

## Creating a Plugin

See [Plugin Development Guide](../docs/PLUGIN_GUIDE.md) for details.

### Plugin Structure

```
my-plugin/
├── plugin.yaml        # Plugin manifest
├── lib/
│   └── plugin.dart   # Plugin implementation
└── README.md
```

### Example Manifest

```yaml
name: my-plugin
version: 1.0.0
description: My awesome plugin

capabilities:
  - my_action

permissions:
  - network
  - filesystem.read
```
