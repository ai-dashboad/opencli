# Telegram Bot Quick Start Guide

Control your computer from anywhere using Telegram! Send messages to your Telegram bot and watch your computer execute tasks in real-time.

## 🚀 Quick Setup (5 minutes)

### Step 1: Create Your Telegram Bot

1. Open Telegram and search for `@BotFather`
2. Send `/newbot` command
3. Choose a name for your bot (e.g., "My OpenCLI")
4. Choose a username (must end in 'bot', e.g., "my_opencli_bot")
5. Copy the bot token (looks like: `123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11`)

### Step 2: Get Your Telegram User ID

1. Search for `@userinfobot` on Telegram
2. Send any message to it
3. Copy your user ID (a number like: `123456789`)

### Step 3: Configure OpenCLI

Create or edit `config/channels.yaml`:

```yaml
channels:
  telegram:
    enabled: true
    config:
      token: "YOUR_BOT_TOKEN_HERE"  # From step 1
    allowed_users:
      - "YOUR_USER_ID_HERE"          # From step 2
    rate_limit: 30
```

Or use environment variables:

```bash
export TELEGRAM_BOT_TOKEN="your-bot-token"
```

### Step 4: Restart OpenCLI Daemon

```bash
opencli daemon restart
```

You should see:
```
✓ Telegram bot connected: @your_bot_username
✓ Channel initialized: telegram
✓ Channel manager initialized (1 channels active)
```

### Step 5: Test It!

Open Telegram and send a message to your bot:

```
/start
```

Bot should reply with a welcome message.

Now try:
```
Take a screenshot
```

Your computer will take a screenshot and send it back to you!

## 📱 Example Commands

### System Control
```
What's my system status?
Take a screenshot
Shutdown in 10 minutes
```

### File Operations
```
Create file test.txt with content hello world
Read file ~/Desktop/notes.txt
Delete file ~/Downloads/temp.zip
```

### Application Control
```
Open Chrome
Close all Chrome windows
Open VSCode
```

### Web Automation
```
Search for "Flutter tutorial" in Google
Go to youtube.com
```

### Advanced
```
Run script ~/scripts/backup.sh
Execute command "ls -la"
Download https://example.com/file.zip
```

## 🔐 Security Best Practices

### 1. Keep Your Bot Token Secret
- Never commit it to git
- Use environment variables
- Rotate regularly if compromised

### 2. Use Allowed Users Whitelist
```yaml
allowed_users:
  - "123456789"  # Only you
  - "987654321"  # Trusted family member
```

### 3. Enable Rate Limiting
```yaml
rate_limit: 30  # Max 30 messages per minute
```

### 4. Monitor Logs
```bash
opencli logs --channel telegram
```

## 🛠️ Troubleshooting

### Bot Not Responding

**Check if daemon is running:**
```bash
opencli status
```

**Check logs:**
```bash
opencli logs --tail 50
```

**Verify configuration:**
```bash
opencli config show
```

### "Unauthorized" Error

Make sure your user ID is in `allowed_users` list:
```yaml
allowed_users:
  - "YOUR_ACTUAL_USER_ID"  # Not username!
```

### Bot Token Invalid

1. Create a new bot with @BotFather
2. Update your config with new token
3. Restart daemon

## 📊 Architecture

```
You (Telegram) → Bot API → OpenCLI Daemon → Your Computer
     ↓                                            ↓
   Results ← ← ← ← ← ← ← ← ← ← ← ← ← ← ← ← ← ← ←
```

1. You send message to your Telegram bot
2. Bot API forwards to OpenCLI daemon (running on your computer)
3. AI recognizes your intent
4. Daemon executes task on your computer
5. Result sent back to you via Telegram

## 🌟 Advanced Features

### Multi-User Setup (Team/Family)

```yaml
channels:
  telegram:
    enabled: true
    config:
      token: "${TELEGRAM_BOT_TOKEN}"
    allowed_users:
      - "123456789"  # Dad
      - "987654321"  # Mom
      - "555666777"  # Son
    rate_limit: 30
```

### Notifications

Receive notifications when tasks complete:

```yaml
notifications:
  telegram:
    enabled: true
    default_recipient: "123456789"
```

### Scheduled Tasks

```
Schedule daily at 9:00 AM: Send me system status
```

Bot will send you system status every morning at 9 AM!

## 🎯 Use Cases

### Remote Work
- Check if your home computer is online
- Start background tasks remotely
- Monitor system resources

### Home Automation
- Control your computer from anywhere
- Schedule tasks while away
- Get notifications

### Team Collaboration
- Share bot with team members
- Coordinate CI/CD tasks
- Monitor shared resources

## 📝 Next Steps

- [ ] Set up WhatsApp bot (coming soon)
- [ ] Add Slack integration for team
- [ ] Configure Discord bot
- [ ] Set up automated backups

## 🆘 Need Help?

- 📖 Full documentation: [docs.opencli.ai](https://docs.opencli.ai)
- 💬 Discord community: [discord.gg/opencli](https://discord.gg/opencli)
- 🐛 Report issues: [github.com/opencli/opencli/issues](https://github.com/opencli/opencli/issues)

---

**Remember:** With great power comes great responsibility! Your bot can control your computer, so keep your token safe and only add trusted users.

Enjoy controlling your computer from anywhere! 🚀
