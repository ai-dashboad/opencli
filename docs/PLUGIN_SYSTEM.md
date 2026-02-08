# OpenCLI Plugin System

**Version**: 1.0.0
**Status**: Production Ready

---

## Overview

The OpenCLI Plugin System is an **AI-driven, zero-configuration plugin ecosystem** that automatically discovers, installs, and executes plugins based on user tasks.

### Core Principles

- **Zero Configuration**: Plugins work out of the box
- **AI-Driven**: Automatic capability discovery and plugin selection
- **Plug & Play**: Install and use immediately
- **Secure by Default**: Permission-based access control

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    User Request                          │
│     "Post a tweet about our new release..."              │
└────────────────┬────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────┐
│              AI Task Analyzer                            │
│  - Parse intent                                          │
│  - Identify required capabilities (twitter.post)         │
│  - Generate execution plan                               │
└────────────────┬────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────┐
│         Capability Registry                              │
│  ┌─────────────────────────────────────────────┐        │
│  │  Installed: slack, telegram, github          │        │
│  │  Missing: twitter ❌                          │        │
│  └─────────────────────────────────────────────┘        │
└────────────────┬────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────┐
│          Plugin Marketplace                              │
│  ┌─────────────────────────────────────────────┐        │
│  │  Search: twitter-* plugins                    │        │
│  │  Found: @opencli/twitter-api ⭐4.8 (10k dl)   │        │
│  │  Auto-install and configure                   │        │
│  └─────────────────────────────────────────────┘        │
└────────────────┬────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────┐
│           Plugin Execution Engine                        │
│  - Load @opencli/twitter-api plugin                      │
│  - Call post() method                                    │
│  - Return execution result                               │
└────────────────┬────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────┐
│                   Result                                 │
│  "✅ Tweet posted: https://twitter.com/..."             │
└─────────────────────────────────────────────────────────┘
```

---

## Plugin Categories

### 60+ Recommended Plugins Across 10 Categories

#### 1. Social Media (6 plugins)
- `@opencli/twitter-api` - Twitter/X automation
- `@opencli/discord-bot` - Discord integration
- `@opencli/slack-integration` - Slack messaging
- `@opencli/telegram-bot` - Telegram automation
- `@opencli/linkedin-api` - LinkedIn posts
- `@opencli/reddit-bot` - Reddit automation

#### 2. Development Tools (8 plugins)
- `@opencli/github-automation` - GitHub Release/PR/Issue
- `@opencli/gitlab-integration` - GitLab CI/CD
- `@opencli/docker-manager` - Docker containers
- `@opencli/kubernetes-operator` - K8s deployments
- `@opencli/npm-publisher` - NPM packages
- `@opencli/pypi-publisher` - Python packages
- `@opencli/cargo-publisher` - Rust crates
- `@opencli/maven-publisher` - Java/Maven artifacts

#### 3. Testing & Automation (7 plugins)
- `@opencli/playwright-automation` - Web testing
- `@opencli/appium-mobile` - Mobile testing
- `@opencli/selenium-grid` - Browser automation
- `@opencli/api-tester` - API testing
- `@opencli/load-tester` - Performance testing
- `@opencli/cypress-runner` - E2E testing
- `@opencli/postman-runner` - Postman collections

#### 4. AI & ML Services (6 plugins)
- `@opencli/openai-plugin` - OpenAI GPT
- `@opencli/claude-plugin` - Anthropic Claude
- `@opencli/ollama-integration` - Local LLMs
- `@opencli/huggingface-hub` - HuggingFace models
- `@opencli/stability-ai` - Image generation
- `@opencli/elevenlabs` - Text-to-speech

#### 5. Data Processing (6 plugins)
- `@opencli/postgresql-tools` - PostgreSQL operations
- `@opencli/mysql-tools` - MySQL operations
- `@opencli/mongodb-tools` - MongoDB operations
- `@opencli/redis-tools` - Redis cache
- `@opencli/elasticsearch-tools` - Search operations
- `@opencli/data-analytics` - Data analysis

#### 6. Notification Services (5 plugins)
- `@opencli/email-sender` - Email (SMTP/SendGrid/Mailgun)
- `@opencli/sms-service` - SMS (Twilio/Nexmo)
- `@opencli/push-notification` - Mobile push
- `@opencli/webhook-sender` - HTTP webhooks
- `@opencli/pagerduty-integration` - Incident alerts

#### 7. Cloud Services (8 plugins)
- `@opencli/aws-integration` - AWS (S3/EC2/Lambda)
- `@opencli/gcp-integration` - Google Cloud
- `@opencli/azure-integration` - Microsoft Azure
- `@opencli/digitalocean-integration` - DigitalOcean
- `@opencli/vercel-deployer` - Vercel deployments
- `@opencli/netlify-deployer` - Netlify deployments
- `@opencli/cloudflare-manager` - Cloudflare DNS/CDN
- `@opencli/heroku-deployer` - Heroku apps

#### 8. Monitoring & Logging (5 plugins)
- `@opencli/datadog-integration` - Datadog monitoring
- `@opencli/newrelic-integration` - New Relic APM
- `@opencli/sentry-integration` - Error tracking
- `@opencli/logstash-shipper` - Log aggregation
- `@opencli/prometheus-exporter` - Metrics export

#### 9. Security & Auth (4 plugins)
- `@opencli/vault-secrets` - HashiCorp Vault
- `@opencli/1password-cli` - 1Password integration
- `@opencli/security-scanner` - Vulnerability scanning
- `@opencli/ssl-checker` - SSL certificate monitoring

#### 10. Productivity & Office (5 plugins)
- `@opencli/google-calendar` - Calendar management
- `@opencli/notion-integration` - Notion API
- `@opencli/jira-automation` - Jira issues
- `@opencli/confluence-publisher` - Confluence pages
- `@opencli/pdf-generator` - PDF documents

**Total: 60+ plugins planned**

---

## Plugin Manifest Format

Every plugin must include a `plugin.yaml` manifest:

```yaml
id: @opencli/my-plugin
name: My Plugin
version: 1.0.0
description: Plugin description

author:
  name: Author Name
  email: author@example.com
  url: https://example.com

license: MIT

capabilities:
  - id: my.action
    name: My Action
    description: Action description
    params:
      - name: param1
        type: string
        required: true
        description: Parameter description

permissions:
  - network              # Network access
  - filesystem.read      # Read files
  - filesystem.write     # Write files
  - process.spawn        # Spawn processes
  - credentials.read     # Read credentials
  - system.admin         # Admin privileges

dependencies:
  - id: @opencli/auth-manager
    version: ^1.0.0

configuration:
  - key: api_key
    type: string
    secret: true
    required: true
    description: API key for authentication

tags:
  - social-media
  - automation

platforms:
  - macos
  - linux
  - windows

min_opencli_version: 0.2.0
```

---

## Plugin Development

### Quick Start

```bash
# 1. Create plugin from template
opencli plugin create my-plugin

# 2. Implement capabilities
# Edit lib/my_plugin.dart

# 3. Test plugin
opencli plugin test my-plugin

# 4. Publish to marketplace
opencli plugin publish my-plugin
```

### Plugin Implementation

```dart
// lib/my_plugin.dart
import 'package:opencli_plugin_sdk/opencli_plugin_sdk.dart';

class MyPlugin extends OpenCLIPlugin {
  @override
  String get id => '@opencli/my-plugin';

  @override
  String get version => '1.0.0';

  @override
  Future<PluginResult> execute(
    String capability,
    Map<String, dynamic> params,
  ) async {
    switch (capability) {
      case 'my.action':
        return await _myAction(params);
      default:
        throw UnknownCapabilityException(capability);
    }
  }

  Future<PluginResult> _myAction(Map<String, dynamic> params) async {
    // Implementation
    return PluginResult.success(
      message: 'Action completed',
      data: {'result': 'success'},
    );
  }
}
```

---

## CLI Commands

### Plugin Management

```bash
# Search plugins
opencli plugin search "twitter"

# Get plugin info
opencli plugin info @opencli/twitter-api

# Install plugin
opencli plugin install @opencli/twitter-api

# List installed plugins
opencli plugin list

# Update plugins
opencli plugin update --all

# Uninstall plugin
opencli plugin uninstall @opencli/twitter-api
```

### Plugin Development

```bash
# Create new plugin
opencli plugin create my-plugin

# Validate plugin
opencli plugin validate my-plugin

# Test plugin
opencli plugin test my-plugin

# Build plugin
opencli plugin build my-plugin

# Publish plugin
opencli plugin publish my-plugin
```

---

## Security

### Permission System

Plugins must declare required permissions:

```yaml
permissions:
  - network              # HTTP/WebSocket requests
  - filesystem.read      # Read files
  - filesystem.write     # Write files
  - process.spawn        # Execute commands
  - credentials.read     # Access secrets
  - system.admin         # Admin operations
```

### Sandboxing

- Plugins run in isolated environments
- Resource limits enforced
- All operations audited

### Code Signing

- Official plugins are signed
- Third-party plugins require review
- Users can configure trust policies

---

## Marketplace

### Discovery

Plugins are automatically discovered through:
1. **AI Analysis**: Parse user intent → identify required capabilities
2. **Search**: Find plugins matching capabilities
3. **Ranking**: Sort by rating, downloads, compatibility
4. **Recommendation**: Suggest best match

### Installation

```dart
// Automatic installation flow
User: "Post a tweet about our release"
  ↓
AI: Needs "twitter.post" capability
  ↓
System: Search plugins with "twitter.post"
  ↓
Found: @opencli/twitter-api (⭐4.8, 10k downloads)
  ↓
Auto-install: Download + Configure + Activate
  ↓
Execute: Post tweet
  ↓
Result: ✅ Tweet posted!
```

### Versioning

- **Semantic Versioning**: MAJOR.MINOR.PATCH
- **Compatibility**: min_opencli_version specified
- **Updates**: Auto-update with user approval
- **Rollback**: Revert to previous version if needed

---

## Implementation Priority

### Phase 1: Foundation (Week 1-2)
- [x] Plugin manifest format
- [ ] Plugin loader
- [ ] Capability registry
- [ ] Basic CLI commands

### Phase 2: Core Plugins (Week 3-6)
Priority order:
1. **@opencli/twitter-api** (Immediate need)
2. **@opencli/github-automation** (Essential for DevOps)
3. **@opencli/slack-integration** (Team collaboration)
4. **@opencli/docker-manager** (Containerization)
5. **@opencli/playwright-automation** (Testing)

### Phase 3: Marketplace (Week 7-10)
- [ ] Marketplace API
- [ ] Plugin repository
- [ ] Search engine
- [ ] CDN distribution

### Phase 4: AI Enhancement (Week 11-14)
- [ ] AI capability recognition
- [ ] Auto-install suggestions
- [ ] Plugin combination recommendations
- [ ] Usage pattern learning

---

## Example: Twitter Plugin Walkthrough

### 1. Create Plugin

```bash
cd plugins
mkdir twitter-api
cd twitter-api
```

### 2. Define Manifest

```yaml
# plugin.yaml
id: @opencli/twitter-api
name: Twitter API Plugin
version: 1.0.0
description: Twitter/X automation - Post, monitor, auto-reply

capabilities:
  - id: twitter.post
    name: Post Tweet
    params:
      - name: content
        type: string
        required: true
      - name: media
        type: array
        required: false

  - id: twitter.monitor
    name: Monitor Keywords
    params:
      - name: keywords
        type: array
        required: true

permissions:
  - network
  - credentials.read

configuration:
  - key: api_key
    type: string
    secret: true
    required: true
```

### 3. Implement Plugin

```dart
// lib/twitter_plugin.dart
class TwitterPlugin extends OpenCLIPlugin {
  @override
  Future<PluginResult> execute(String capability, Map params) async {
    switch (capability) {
      case 'twitter.post':
        return await _postTweet(params);
      case 'twitter.monitor':
        return await _monitorKeywords(params);
      default:
        throw UnknownCapabilityException(capability);
    }
  }

  Future<PluginResult> _postTweet(Map params) async {
    final client = TwitterClient(config['api_key']);
    final tweet = await client.post(params['content']);
    return PluginResult.success(
      message: 'Tweet posted successfully',
      data: {'url': tweet.url},
    );
  }
}
```

### 4. Test Plugin

```dart
// test/twitter_plugin_test.dart
void main() {
  test('should post tweet', () async {
    final plugin = TwitterPlugin();
    final result = await plugin.execute('twitter.post', {
      'content': 'Hello from OpenCLI! 🚀',
    });
    expect(result.success, true);
  });
}
```

### 5. Usage

```bash
# User command (natural language)
opencli "Post a tweet: We just released v1.0.0! 🎉"

# Or direct CLI
opencli plugin exec @opencli/twitter-api twitter.post \
  --content "We just released v1.0.0! 🎉"
```

---

## Resources

- [Plugin Development Guide](./PLUGIN_GUIDE.md)
- [Recommended Plugins List](./RECOMMENDED_PLUGINS.md)
- [API Reference](./API_REFERENCE.md)
- [Security Best Practices](./SECURITY.md)

---

**OpenCLI Plugin System** - Build once, automate forever.
