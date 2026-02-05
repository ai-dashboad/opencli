# Plugin Marketplace UI - User Guide

**Access plugins visually** through Web UI or Menubar!

---

## 🌐 Web UI Access

### Start the UI

```bash
# Method 1: Start daemon (auto-starts plugin marketplace)
opencli daemon start

# Method 2: Open marketplace from CLI
opencli plugin browse

# Method 3: Open manually in browser
open http://localhost:9877

# The UI is available at: http://localhost:9877
```

### Features

✅ **Browse Plugins** - Visual marketplace
✅ **Search & Filter** - Find plugins quickly
✅ **One-Click Install** - No terminal needed
✅ **Manage Plugins** - Start/stop/configure
✅ **View Details** - Tools, ratings, downloads
✅ **Real-time Stats** - Monitor plugin status

---

## 🍎 Menubar Access (macOS)

### Access

1. Click OpenCLI icon in menubar
2. Navigate to **"🔌 Plugins"** section
3. See all installed plugins with submenus

### Available Actions

For each plugin:
- **Start Plugin** - Activate the plugin
- **Stop Plugin** - Deactivate the plugin
- **Configure** - Set up credentials
- **Uninstall** - Remove the plugin

### Quick Actions

- **🛒 Browse Marketplace** - Opens web UI
- **📊 Stats** - See plugin count & tools

---

## 📦 Installing Plugins

### Via Web UI

1. Open http://localhost:9877
2. Search or browse plugins
3. Click **"Install"** button
4. Configure credentials if needed
5. Click **"Start"** to activate

### Via Menubar

1. Click menubar icon
2. Select **"🛒 Browse Marketplace"**
3. Use web UI to install

### Via CLI (Alternative)

```bash
opencli plugin add twitter-api
opencli plugin start twitter-api
```

---

## 🎨 Web UI Features

### 1. Plugin Cards

Each plugin shows:
- **Icon** - Visual identifier
- **Name & Description**
- **Rating** ⭐ - User ratings
- **Downloads** 📥 - Popularity
- **Version** - Current version
- **Status** - Installed/Running badges
- **Tools** - Available capabilities
- **Actions** - Install/Start/Stop buttons

### 2. Search & Filter

**Search Bar**: Find by name or description
**Filters**:
- All
- Social Media
- Development
- Testing
- Cloud
- Communication
- DevOps

### 3. Stats Dashboard

Top of page shows:
- **Available Plugins** - Total in marketplace
- **Installed** - Plugins you have
- **Running** - Currently active
- **Total Tools** - All capabilities

---

## 🔧 Managing Plugins

### Start/Stop Plugins

**Web UI**:
- Click **"Start"** button on plugin card
- Or click **"Stop"** to deactivate

**Menubar**:
- Navigate to plugin submenu
- Click **"Start Plugin"** or **"Stop Plugin"**

**CLI**:
```bash
opencli plugin start twitter-api
opencli plugin stop twitter-api
```

### Configure Plugins

**Web UI**:
1. Click **"Details"** on plugin
2. Go to **"Configuration"** tab
3. Enter API keys/credentials
4. Click **"Save"**

**Manual**:
Edit `.opencli/mcp-servers.json`:
```json
{
  "mcpServers": {
    "twitter-api": {
      "env": {
        "TWITTER_API_KEY": "your_key_here"
      }
    }
  }
}
```

### Uninstall Plugins

**Web UI**: Click **"Uninstall"** button
**Menubar**: Plugin menu → **"Uninstall"**
**CLI**: `opencli plugin remove twitter-api`

---

## 📊 Available Plugins

### Currently Installed (4)

1. **🐦 Twitter API** (4 tools)
   - Post tweets, search, monitor, reply

2. **🔧 GitHub Automation** (5 tools)
   - Releases, PRs, issues, workflows

3. **💬 Slack Integration** (1 tool)
   - Send messages

4. **🐳 Docker Manager** (2 tools)
   - List/run containers

### Coming Soon (60+ total)

- **AWS Integration** - S3, EC2, Lambda
- **Playwright** - Web automation
- **PostgreSQL** - Database tools
- **OpenAI** - AI integration
- And 56 more...

---

## 🚀 Quick Start Workflow

### 1. Open Web UI

```bash
# Start daemon
opencli daemon start

# UI auto-opens or visit:
open http://localhost:9877
```

### 2. Browse Plugins

- Use search bar to find plugins
- Filter by category
- Click cards to see details

### 3. Install Plugin

- Click **"Install"** button
- Wait for installation
- Plugin shows "Installed" badge

### 4. Configure

- Click **"Details"** button
- Add API keys in configuration
- Save settings

### 5. Start Using

- Click **"Start"** button
- Plugin shows "Running" badge
- Now available for AI to use!

### 6. Test It

```bash
# Natural language
opencli "Post a tweet: Hello from OpenCLI! 🚀"

# AI automatically uses your plugin
```

---

## 💡 Tips

### Web UI Tips

- **Bookmark** `http://localhost:9877` for quick access
- **Search** is instant - no need to press Enter
- **Filters** can be combined with search
- **Hover** over cards for subtle animations

### Menubar Tips

- **Right-click** menubar icon for context menu
- **Submenu** shows all plugin actions
- **Browse Marketplace** opens web UI
- **Stats** show at bottom of menu

### General Tips

- **Start plugins** you use frequently
- **Stop plugins** to save resources
- **Check ratings** before installing
- **Read descriptions** to understand capabilities

---

## 🔍 Troubleshooting

### Web UI won't open

```bash
# Check if daemon is running
opencli status

# Start daemon manually
opencli daemon start

# Check port 9877 is available
lsof -i :9877
```

### Plugin won't start

1. Check configuration is complete
2. Verify API keys are correct
3. Check plugin logs
4. Try restart: Stop then Start

### Installation fails

1. Check internet connection
2. Verify npm is installed
3. Check disk space
4. Try manual install: `cd plugins/plugin-name && npm install`

### Menubar doesn't show plugins

1. Restart daemon
2. Check daemon is running
3. Rebuild tray menu

---

## 📖 More Info

- **[Plugin System](./MCP_PLUGIN_SYSTEM.md)** - Architecture
- **[Quick Start](./QUICK_START.md)** - Setup guide
- **[Implementation](./IMPLEMENTATION_COMPLETE.md)** - What's built

---

## 🎉 Summary

**Two ways to manage plugins**:

1. **🌐 Web UI** (http://localhost:9877)
   - Visual marketplace
   - Browse, search, install
   - Manage all plugins

2. **🍎 Menubar** (macOS)
   - Quick access from menubar
   - Start/stop plugins
   - Configuration shortcuts

**Both make plugin management easy!** No terminal needed. 🚀

---

**Access now**: http://localhost:9877
