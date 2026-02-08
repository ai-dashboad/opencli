# OpenCLI MCP Plugins - Quick Start

Get started with OpenCLI MCP plugins in 5 minutes.

## 📦 What's Included

✅ **4 Ready-to-Use MCP Plugins:**
1. **Twitter API** - Post tweets, monitor keywords
2. **GitHub Automation** - Releases, PRs, issues
3. **Slack Integration** - Send messages
4. **Docker Manager** - Container management

✅ **MCP Server Manager** - Manages all plugins
✅ **CLI Tools** - Easy plugin management
✅ **AI-Driven** - Natural language commands

---

## 🚀 Installation

### 1. Install Plugin Dependencies

```bash
# Twitter plugin
cd plugins/twitter-api
npm install

# GitHub plugin
cd ../github-automation
npm install

# Slack plugin
cd ../slack-integration
npm install

# Docker plugin
cd ../docker-manager
npm install
```

### 2. Configure Credentials

```bash
# Twitter
cd plugins/twitter-api
cp .env.example .env
# Edit .env with your Twitter API credentials

# GitHub
cd ../github-automation
echo "GITHUB_TOKEN=your_token" > .env

# Slack
cd ../slack-integration
echo "SLACK_TOKEN=your_token" > .env
```

### 3. Update MCP Config

Edit `.opencli/mcp-servers.json` with your credentials:

```json
{
  "mcpServers": {
    "twitter-api": {
      "command": "node",
      "args": ["plugins/twitter-api/index.js"],
      "env": {
        "TWITTER_API_KEY": "your_key",
        "TWITTER_API_SECRET": "your_secret",
        "TWITTER_ACCESS_TOKEN": "your_token",
        "TWITTER_ACCESS_SECRET": "your_token_secret"
      }
    }
  }
}
```

---

## 💡 Usage

### Natural Language (AI-Driven)

```bash
# Twitter
opencli "Post a tweet: We just released v1.0.0! 🎉"

# GitHub
opencli "Create a GitHub release v1.0.0 with release notes"

# Slack
opencli "Send a Slack message to #engineering: Deploy complete"

# Docker
opencli "List all running Docker containers"
```

**AI automatically figures out which tool to call!**

### Direct Tool Calls

```bash
# List all tools
opencli plugin tools

# Call specific tool
opencli plugin call twitter_post \
  --content "Hello from OpenCLI!"

opencli plugin call github_create_release \
  --owner myorg \
  --repo myrepo \
  --tag_name v1.0.0 \
  --name "Version 1.0.0"
```

---

## 🎯 Common Workflows

### 1. GitHub Release → Twitter

```bash
# Automated workflow
opencli "When I create a GitHub release, post it to Twitter"

# Manual
opencli plugin call github_create_release \
  --owner myorg --repo myrepo --tag_name v1.0.0

opencli plugin call twitter_post \
  --content "🎉 Released v1.0.0!"
```

### 2. Deployment Notifications

```bash
# Deploy and notify
opencli plugin call docker_run --image myapp:latest

opencli plugin call slack_send_message \
  --channel #deployments \
  --text "✅ Deployed myapp:latest"
```

---

## 🛠️ Plugin Management

```bash
# List plugins
opencli plugin list

# Start/stop plugins
opencli plugin start twitter-api
opencli plugin stop twitter-api
opencli plugin restart twitter-api

# Get plugin info
opencli plugin info twitter-api

# List available tools
opencli plugin tools twitter-api
```

---

## 📊 Current Status

| Plugin | Status | Tools | Ready |
|--------|--------|-------|-------|
| Twitter API | ✅ Complete | 4 | Yes |
| GitHub Automation | ✅ Complete | 5 | Yes |
| Slack Integration | ✅ Complete | 1 | Yes |
| Docker Manager | ✅ Complete | 2 | Yes |

**Total: 4 working plugins, 12 tools**

---

## 🎉 What's Next?

### More Plugins Coming:
- **Playwright** - Web automation
- **AWS** - Cloud management
- **Telegram** - Bot integration
- **PostgreSQL** - Database tools
- **And 56 more...**

### Features:
- Plugin marketplace
- Auto-installation
- Plugin discovery
- Hot reload
- Analytics

---

## 📚 Documentation

- [MCP Plugin System](./MCP_PLUGIN_SYSTEM.md)
- [Plugin Implementation](./PLUGIN_IMPLEMENTATION.md)
- [Twitter Plugin](../plugins/twitter-api/README.md)
- [GitHub Plugin](../plugins/github-automation/README.md)

---

## 🆘 Troubleshooting

### Plugin won't start
```bash
# Check logs
opencli plugin info <name>

# Restart plugin
opencli plugin restart <name>
```

### Tool not found
```bash
# List all tools
opencli plugin tools

# Verify plugin is running
opencli plugin list
```

### Authentication errors
- Check credentials in `.env` files
- Verify tokens are valid
- Check API permissions

---

**You're ready to go! Start automating with OpenCLI MCP plugins.** 🚀
