# Plugin Marketplace - Quick Reference

## 🚀 Getting Started (30 seconds)

```bash
# 1. Start the daemon
opencli daemon start

# 2. Open the marketplace
opencli plugin browse

# 3. Install a plugin (via web UI or CLI)
opencli plugin add twitter-api

# 4. Start using it
opencli "Post a tweet: Hello World! 🚀"
```

---

## 🌐 Web UI Access

**URL:** http://localhost:9877

**Features:**
- Browse 60+ plugins visually
- Search and filter by category
- One-click install/uninstall
- Start/stop plugins with buttons
- View real-time stats

**Opening the UI:**
```bash
# Method 1: CLI command (auto-opens browser)
opencli plugin browse

# Method 2: Direct URL
open http://localhost:9877

# Method 3: Menubar (macOS)
# Click OpenCLI icon → Plugins → Browse Marketplace
```

---

## 💻 CLI Commands

### Basic Operations

```bash
# Open marketplace in browser
opencli plugin browse

# List installed plugins
opencli plugin list

# Install a plugin
opencli plugin add <plugin-name>

# Start/stop a plugin
opencli plugin start <plugin-name>
opencli plugin stop <plugin-name>

# Remove a plugin
opencli plugin remove <plugin-name>

# Show plugin details
opencli plugin info <plugin-name>
```

### Advanced Usage

```bash
# List all available tools
opencli plugin tools

# List tools from specific plugin
opencli plugin tools twitter-api

# Call a tool directly
opencli plugin call twitter_post --content "Hello!"

# Restart a plugin
opencli plugin restart twitter-api
```

---

## 🔌 Available Plugins

### Social Media
- **Twitter API** - Post, search, monitor, reply
- LinkedIn Integration (coming soon)
- Facebook API (coming soon)

### Development
- **GitHub Automation** - PRs, issues, releases, workflows
- GitLab Integration (coming soon)
- Bitbucket API (coming soon)

### Communication
- **Slack Integration** - Send messages, channels
- Discord Bot (coming soon)
- Microsoft Teams (coming soon)

### DevOps
- **Docker Manager** - Containers, images
- Kubernetes Controller (coming soon)
- Terraform Runner (coming soon)

### Cloud Providers
- AWS Integration (coming soon)
- Google Cloud Platform (coming soon)
- Azure Manager (coming soon)

### Testing
- Playwright Automation (coming soon)
- Selenium WebDriver (coming soon)
- Postman Collection Runner (coming soon)

---

## 📦 Plugin Structure

Each plugin provides:
- **Tools** - Specific actions (post_tweet, create_pr, etc.)
- **Description** - What the plugin does
- **Configuration** - API keys, credentials
- **Documentation** - How to use it

---

## 🔧 Configuration

### Setting API Keys

**Via Web UI:**
1. Click "Details" on installed plugin
2. Go to "Configuration" tab
3. Enter API keys
4. Click "Save"

**Via Config File:**
Edit `~/.opencli/mcp-servers.json`:
```json
{
  "mcpServers": {
    "twitter-api": {
      "command": "node",
      "args": ["/path/to/twitter-api/index.js"],
      "env": {
        "TWITTER_API_KEY": "your_key",
        "TWITTER_API_SECRET": "your_secret"
      }
    }
  }
}
```

---

## 🎯 Common Workflows

### Install and Use Twitter Plugin

```bash
# 1. Open marketplace
opencli plugin browse

# 2. Search for "Twitter" in web UI
# 3. Click "Install" button
# 4. Click "Configure" and add API keys
# 5. Click "Start"

# 6. Use it naturally
opencli "Post a tweet: Just installed OpenCLI! 🚀"

# Or call directly
opencli plugin call twitter_post --content "Hello Twitter!"
```

### GitHub Automation Example

```bash
# Install and start
opencli plugin add github-automation
opencli plugin start github-automation

# Create a release
opencli "Create a GitHub release for v1.0.0 with notes"

# Or directly
opencli plugin call github_create_release \
  --tag v1.0.0 \
  --name "Version 1.0.0" \
  --notes "Initial release"
```

### Docker Management

```bash
# Install Docker plugin
opencli plugin add docker-manager
opencli plugin start docker-manager

# List containers
opencli "Show me all running Docker containers"

# Run a container
opencli "Start a Redis container"
```

---

## 🧪 Testing

Run the test script:
```bash
./scripts/test-marketplace.sh
```

Expected output:
```
✓ Plugin marketplace is accessible
✓ Found 6 plugins in marketplace
✓ Web UI is serving correctly
✓ Status API is running
✓ CLI is working
✅ All tests passed!
```

---

## 🐛 Troubleshooting

### Marketplace won't open

```bash
# Check if daemon is running
opencli status

# Restart daemon
opencli daemon stop
opencli daemon start

# Verify port is available
lsof -i :9877

# Test manually
curl http://localhost:9877/api/plugins
```

### Plugin won't start

```bash
# Check plugin status
opencli plugin list

# View plugin info
opencli plugin info <plugin-name>

# Check logs (if available)
tail -f ~/.opencli/logs/plugins/<plugin-name>.log

# Try restart
opencli plugin restart <plugin-name>
```

### Installation fails

```bash
# Check internet connection
ping google.com

# Check npm is installed
npm --version

# Try manual installation
cd ~/.opencli/plugins/<plugin-name>
npm install

# Check disk space
df -h
```

---

## 📊 Monitoring

### Check System Status

```bash
# Status API
curl http://localhost:9875/status | jq

# Plugin stats
curl http://localhost:9877/api/plugins | jq '.plugins | length'

# Running plugins
opencli plugin list
```

### Performance

```bash
# Check daemon health
opencli status

# Monitor memory usage
ps aux | grep opencli

# Check plugin processes
ps aux | grep "node.*plugins"
```

---

## 🎨 Web UI Features Explained

### Stats Dashboard
- **Available Plugins** - Total plugins in marketplace
- **Installed** - Plugins you've installed
- **Running** - Currently active plugins
- **Total Tools** - Sum of all tools from all plugins

### Plugin Cards
- **Icon** - Visual identifier by category
- **Rating** - ⭐ User rating (1-5)
- **Downloads** - Popularity metric
- **Status Badges** - "Installed", "Running"
- **Tool Count** - Number of available actions
- **Actions** - Install, Start, Stop, Uninstall, Details

### Search & Filter
- **Search** - Real-time, searches name and description
- **Filters** - All, Social Media, Development, Testing, Cloud, Communication, DevOps

---

## 💡 Tips & Best Practices

### For Users
1. ✅ Start daemon before using plugins
2. ✅ Use web UI for discovery
3. ✅ Use CLI for automation/scripts
4. ✅ Stop unused plugins to save resources
5. ✅ Keep API keys in config file, not in code

### For Developers
1. ✅ Follow MCP protocol standard
2. ✅ Provide clear tool descriptions
3. ✅ Handle errors gracefully
4. ✅ Document configuration requirements
5. ✅ Test with AI natural language queries

---

## 🔗 Learn More

- [Complete User Guide](docs/PLUGIN_UI_GUIDE.md)
- [Plugin System Architecture](docs/MCP_PLUGIN_SYSTEM.md)
- [5-Minute Quick Start](docs/QUICK_START.md)
- [Implementation Status](PLUGIN_MARKETPLACE_COMPLETE.md)

---

## 🆘 Support

**Need help?**
- Check documentation: `docs/`
- Run test script: `./scripts/test-marketplace.sh`
- Check logs: `~/.opencli/logs/`
- Open an issue on GitHub

---

**Happy plugin hunting! 🎉**

Access marketplace: http://localhost:9877
