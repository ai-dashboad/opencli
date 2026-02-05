# OpenCLI - Plugins

Plugin marketplace for OpenCLI - Extend your AI automation capabilities.

---

## 🎯 Vision

Build an **AI-driven plugin ecosystem** that enables OpenCLI to:
- 🔍 Automatically discover required capabilities
- 📦 Automatically install relevant plugins
- 🤖 Intelligently invoke plugins to complete tasks
- 🔄 Automatically update plugin versions

---

## 📦 Recommended Plugins

### 🔥 P0 - Immediate Need

#### 1. [@opencli/twitter-api](./twitter-api/) ⭐⭐⭐⭐⭐
> Twitter/X automation - Post tweets, monitor keywords, auto-reply

**Use Cases**:
- Automatically publish GitHub Releases to Twitter
- Monitor tech keywords and auto-reply
- Tech community exposure and promotion

**Status**: 🚧 In Development

---

#### 2. [@opencli/github-automation](./github-automation/) ⭐⭐⭐⭐⭐
> GitHub automation - Release, PR, Issue management

**Use Cases**:
- Automatically create Releases
- Listen to GitHub events
- CI/CD integration

**Status**: 📋 Planned

---

### 🚀 P1 - High Priority

- **@opencli/slack-integration** - Slack integration
- **@opencli/docker-manager** - Docker management
- **@opencli/playwright-automation** - Web automation testing

### 📦 P2 - Medium Priority

- **@opencli/discord-bot** - Discord bot
- **@opencli/telegram-bot** - Telegram bot
- **@opencli/email-sender** - Email sender
- **@opencli/database-tools** - Database tools

Complete list: [Recommended Plugins](../docs/RECOMMENDED_PLUGINS.md)

---

## 🏗️ Plugin Marketplace Architecture

Detailed design: [Plugin Marketplace Design](../docs/PLUGIN_MARKETPLACE_DESIGN.md)

```
User Request → AI Analysis → Capability Recognition → Plugin Search → Auto Install → Execute Task
```

**Core Features**:
- 🤖 **AI-Driven**: Automatically identify needs and recommend plugins
- 🔌 **Plug & Play**: Zero configuration, auto-install
- 🌍 **Rich Ecosystem**: Cover various scenarios
- 🔒 **Secure & Reliable**: Permission control, code review

---

## 📚 Development Guide

### Creating a Plugin

```bash
# 1. Create plugin directory
mkdir -p plugins/my-plugin
cd plugins/my-plugin

# 2. Create plugin.yaml
cat > plugin.yaml <<EOF
id: @opencli/my-plugin
name: My Plugin
version: 1.0.0
description: My awesome plugin

capabilities:
  - my.action

permissions:
  - network
EOF

# 3. Implement plugin
# Reference: ../docs/PLUGIN_GUIDE.md
```

### Plugin Structure

```
my-plugin/
├── plugin.yaml              # Plugin manifest (required)
├── README.md                # Documentation
├── CHANGELOG.md             # Changelog
├── lib/
│   ├── my_plugin.dart      # Main entry point
│   ├── api/                # API implementation
│   └── models/             # Data models
├── test/                   # Tests
└── examples/               # Examples
```

### plugin.yaml Example

```yaml
id: @opencli/my-plugin
name: My Plugin
version: 1.0.0
description: My awesome plugin

author:
  name: Your Name
  email: you@example.com

capabilities:
  - id: my.action
    name: My Action
    description: Do something awesome
    params:
      - name: param1
        type: string
        required: true

permissions:
  - network
  - filesystem.read

dependencies:
  - id: @opencli/auth-manager
    version: ^1.0.0

tags:
  - automation
  - example

platforms:
  - macos
  - linux
  - windows

min_opencli_version: 0.2.0
```

---

## 📖 Documentation

- [Plugin Marketplace Design](../docs/PLUGIN_MARKETPLACE_DESIGN.md)
- [Recommended Plugins](../docs/RECOMMENDED_PLUGINS.md)
- [Plugin Development Guide](../docs/PLUGIN_GUIDE.md)
- [Twitter Plugin Tutorial](../docs/tutorials/TWITTER_PLUGIN.md)

---

## 🤝 Contributing

We welcome plugin contributions!

1. Fork the project
2. Create plugin directory
3. Implement plugin functionality
4. Add tests and documentation
5. Submit PR

---

## 📄 License

MIT License

---

**OpenCLI Plugins** - Powered by AI, Built for Developers
