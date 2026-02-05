# OpenCLI MCP Plugin System

**Like Claude Code Skills** - Import and use smartly, powered by AI.

---

## 🎯 Vision

Build a **Claude Code-style plugin system** using **MCP (Model Context Protocol)**:

```bash
# Install plugin
opencli plugin add twitter-api

# AI automatically uses it
You: "Post a tweet about our v1.0.0 release"
AI: *automatically detects twitter-api MCP server*
AI: *calls twitter.post tool*
Result: ✅ Tweet posted!
```

**No configuration. No manual calls. Just works.**

---

## 🏗️ Architecture

### MCP-Based Design

```
┌─────────────────────────────────────────────┐
│          User Natural Language              │
│  "Post a tweet about our new release"       │
└────────────────┬────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────┐
│         AI (Claude/GPT/Local LLM)           │
│  • Understands intent                       │
│  • Knows available MCP tools                │
│  • Automatically calls: twitter.post        │
└────────────────┬────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────┐
│       MCP Plugin (Twitter API)              │
│  • Receives tool call                       │
│  • Executes action                          │
│  • Returns result                           │
└────────────────┬────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────┐
│             Result                          │
│  ✅ "Tweet posted: https://..."             │
└─────────────────────────────────────────────┘
```

---

## 📦 Plugin Format

Each plugin is an **MCP server** that exposes tools:

### Example: Twitter Plugin

```json
{
  "mcpServers": {
    "twitter-api": {
      "command": "node",
      "args": ["plugins/twitter-api/index.js"],
      "tools": [
        {
          "name": "twitter_post",
          "description": "Post a tweet to Twitter/X",
          "inputSchema": {
            "type": "object",
            "properties": {
              "content": {
                "type": "string",
                "description": "Tweet content"
              },
              "media": {
                "type": "array",
                "description": "Media URLs (optional)"
              }
            },
            "required": ["content"]
          }
        },
        {
          "name": "twitter_monitor",
          "description": "Monitor keywords on Twitter",
          "inputSchema": {
            "type": "object",
            "properties": {
              "keywords": {
                "type": "array",
                "items": {"type": "string"}
              }
            }
          }
        }
      ]
    }
  }
}
```

---

## 🚀 How It Works

### 1. Install Plugin

```bash
# Install from marketplace
opencli plugin add @opencli/twitter-api

# Or install from GitHub
opencli plugin add github:opencli/twitter-api-plugin

# Or install from NPM
opencli plugin add npm:@opencli/twitter-api-mcp
```

### 2. Plugin Auto-Registers

```javascript
// plugins/twitter-api/index.js (MCP server)
import { MCPServer } from '@modelcontextprotocol/sdk';

const server = new MCPServer({
  name: 'twitter-api',
  version: '1.0.0'
});

// Register tools
server.tool({
  name: 'twitter_post',
  description: 'Post a tweet to Twitter/X',
  parameters: {
    content: { type: 'string', required: true },
    media: { type: 'array', required: false }
  },
  async handler({ content, media }) {
    // Post tweet
    const result = await postTweet(content, media);
    return { success: true, url: result.url };
  }
});

server.tool({
  name: 'twitter_monitor',
  description: 'Monitor Twitter keywords',
  parameters: {
    keywords: { type: 'array', required: true }
  },
  async handler({ keywords }) {
    // Start monitoring
    return { success: true, monitoring: keywords };
  }
});

server.listen();
```

### 3. AI Uses It Automatically

```bash
# User just talks naturally
You: "Post a tweet: We just released v1.0.0! 🎉"

# AI sees available MCP tools and calls them
AI Internal:
  - User wants to post on Twitter
  - I have twitter_post tool available
  - Call: twitter_post({ content: "We just released v1.0.0! 🎉" })

# Result
✅ Tweet posted: https://twitter.com/yourhandle/status/...
```

---

## 📋 60+ Plugins as MCP Servers

All plugins are **MCP servers**:

### 1. Social Media MCP Servers

```bash
@opencli/twitter-api-mcp       # Twitter/X
@opencli/discord-bot-mcp       # Discord
@opencli/slack-mcp             # Slack
@opencli/telegram-mcp          # Telegram
```

### 2. Development Tools MCP Servers

```bash
@opencli/github-mcp            # GitHub
@opencli/gitlab-mcp            # GitLab
@opencli/docker-mcp            # Docker
@opencli/kubernetes-mcp        # Kubernetes
```

### 3. Testing MCP Servers

```bash
@opencli/playwright-mcp        # Web testing
@opencli/api-test-mcp          # API testing
```

### 4. Cloud MCP Servers

```bash
@opencli/aws-mcp               # AWS
@opencli/gcp-mcp               # Google Cloud
@opencli/azure-mcp             # Azure
```

**All 60+ plugins as MCP servers!**

---

## 🔧 Plugin Implementation

### Quick Start Template

```javascript
// plugins/my-plugin/index.js
import { MCPServer } from '@modelcontextprotocol/sdk';

const server = new MCPServer({
  name: 'my-plugin',
  version: '1.0.0',
  description: 'My awesome plugin'
});

// Define tools
server.tool({
  name: 'my_action',
  description: 'Do something awesome',
  parameters: {
    param1: {
      type: 'string',
      description: 'Parameter description',
      required: true
    }
  },
  async handler({ param1 }) {
    // Your implementation
    console.log('Doing something with:', param1);
    return {
      success: true,
      result: 'Done!'
    };
  }
});

// Start server
server.listen();
```

### Package Structure

```
my-plugin/
├── package.json           # NPM package
├── index.js              # MCP server entry
├── mcp.json              # MCP configuration
└── README.md
```

### package.json

```json
{
  "name": "@opencli/my-plugin-mcp",
  "version": "1.0.0",
  "type": "module",
  "main": "index.js",
  "keywords": ["mcp", "opencli", "plugin"],
  "dependencies": {
    "@modelcontextprotocol/sdk": "^1.0.0"
  }
}
```

---

## 🎮 Usage Examples

### Example 1: Natural Language

```bash
# No need to specify plugin - AI figures it out

You: "Post a tweet about our new feature"
→ AI calls: twitter_post()

You: "Create a GitHub release for v2.0"
→ AI calls: github_create_release()

You: "Deploy to AWS"
→ AI calls: aws_deploy()

You: "Send a Slack message to #engineering"
→ AI calls: slack_send_message()
```

### Example 2: Workflow Automation

```bash
# User describes workflow
You: "When we create a GitHub release, automatically:
     1. Post to Twitter
     2. Send Slack notification
     3. Deploy to production"

# AI orchestrates multiple MCP plugins:
→ github_monitor_releases()
→ twitter_post()
→ slack_send_message()
→ aws_deploy()
```

---

## 🔄 Plugin Lifecycle

### Installation

```bash
# Install plugin
opencli plugin add @opencli/twitter-api-mcp

# What happens:
1. Download from registry
2. Install dependencies (npm install)
3. Start MCP server
4. Register with OpenCLI daemon
5. AI now knows about twitter_post tool
```

### Auto-Start

```javascript
// Daemon automatically starts MCP servers
// ~/.opencli/mcp-servers.json
{
  "twitter-api": {
    "command": "node",
    "args": ["plugins/twitter-api/index.js"],
    "env": {
      "TWITTER_API_KEY": "..."
    }
  }
}
```

### Hot Reload

```bash
# Update plugin
opencli plugin update twitter-api

# Restart MCP server
opencli plugin restart twitter-api
```

---

## 🛠️ CLI Commands

```bash
# Plugin management
opencli plugin list                    # List installed
opencli plugin add <name>              # Install
opencli plugin remove <name>           # Uninstall
opencli plugin update <name>           # Update
opencli plugin restart <name>          # Restart MCP server

# Plugin development
opencli plugin create <name>           # Create from template
opencli plugin test <name>             # Test plugin
opencli plugin publish <name>          # Publish to registry

# Plugin discovery
opencli plugin search "twitter"        # Search marketplace
opencli plugin info twitter-api        # Show details
```

---

## 🔒 Security

### Permission System

```json
{
  "permissions": {
    "network": true,
    "filesystem.read": true,
    "filesystem.write": false,
    "credentials.read": true
  }
}
```

### Sandboxing

Each MCP server runs in isolated process with:
- Resource limits
- Permission checks
- Operation auditing

---

## 📦 Plugin Registry

### Official Registry

```
https://plugins.opencli.dev

Categories:
- Social Media
- Development Tools
- Testing & Automation
- AI & ML
- Cloud Services
- Monitoring
- Security
- Productivity
```

### Install from Any Source

```bash
# Official registry
opencli plugin add twitter-api

# GitHub
opencli plugin add github:user/repo

# NPM
opencli plugin add npm:@scope/package

# Local
opencli plugin add ./path/to/plugin
```

---

## 🎯 Key Advantages

### vs Traditional Plugins

| Feature | Traditional | MCP-Based |
|---------|------------|-----------|
| Installation | Manual config | One command |
| Discovery | Manual search | AI knows all tools |
| Invocation | Explicit call | AI decides |
| Updates | Manual | Auto-update |
| Integration | Custom code | Standard MCP |

### Why MCP?

1. **Standard Protocol** - Works with any AI
2. **Zero Config** - Just install and use
3. **AI-Native** - Designed for AI to use
4. **Hot Reload** - Update without restart
5. **Ecosystem** - Growing MCP community

---

## 🚀 Implementation Plan

### Phase 1: MCP Infrastructure (Week 1)
- [ ] MCP server manager
- [ ] Plugin installer
- [ ] Auto-registration
- [ ] CLI commands

### Phase 2: Core MCP Plugins (Weeks 2-4)
Priority order:
1. **Twitter API MCP** (GitHub Release → Tweet)
2. **GitHub Automation MCP** (Release monitoring)
3. **Slack Integration MCP** (Notifications)
4. **Docker Manager MCP** (Deployment)

### Phase 3: Expand Ecosystem (Weeks 5-12)
- 20+ MCP plugins
- Plugin marketplace
- Auto-discovery
- AI orchestration

---

## 💡 First Plugin: Twitter API MCP

Let me implement it now as an example:

```javascript
// plugins/twitter-api/index.js
import { MCPServer } from '@modelcontextprotocol/sdk';
import { TwitterApi } from 'twitter-api-v2';

const server = new MCPServer({
  name: 'twitter-api',
  version: '1.0.0'
});

const client = new TwitterApi(process.env.TWITTER_API_KEY);

server.tool({
  name: 'twitter_post',
  description: 'Post a tweet to Twitter/X',
  parameters: {
    content: { type: 'string', required: true },
    media: { type: 'array', required: false }
  },
  async handler({ content, media }) {
    const tweet = await client.v2.tweet({ text: content });
    return {
      success: true,
      url: `https://twitter.com/i/web/status/${tweet.data.id}`,
      id: tweet.data.id
    };
  }
});

server.listen();
```

---

## 🎉 Summary

**New Approach: MCP-Based Smart Plugins**

✅ Like Claude Code skills
✅ Install and use instantly
✅ AI automatically detects when to use
✅ Zero configuration
✅ Standard MCP protocol
✅ 60+ plugins as MCP servers

**Next Step**: Implement first MCP plugin (Twitter API) to demonstrate the system?
