# Twitter API MCP Plugin

Twitter/X automation for OpenCLI - Post tweets, monitor keywords, auto-reply.

## Features

- ✅ **Post tweets** - Text, replies, threads
- ✅ **Search tweets** - Find tweets by keywords
- ✅ **Monitor keywords** - Track mentions and topics
- ✅ **Auto-reply** - Respond to tweets automatically
- 🚧 **Media support** - Images, videos (coming soon)
- 🚧 **Analytics** - Tweet metrics (coming soon)

## Installation

```bash
# Install from OpenCLI marketplace
opencli plugin add twitter-api

# Or install locally
cd plugins/twitter-api
npm install
```

## Configuration

1. Get Twitter API credentials from [Twitter Developer Portal](https://developer.twitter.com/en/portal/dashboard)

2. Create `.env` file:
```bash
cp .env.example .env
# Edit .env with your credentials
```

3. Add to OpenCLI MCP config (`~/.opencli/mcp-servers.json`):
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

## Usage

### Natural Language (AI-driven)

```bash
# Just talk naturally - AI calls the right tool

opencli "Post a tweet: We just released v1.0.0! 🎉"
→ AI calls: twitter_post

opencli "Search tweets about #OpenSource"
→ AI calls: twitter_search

opencli "Reply to tweet 123456: Thanks for sharing!"
→ AI calls: twitter_reply
```

### Direct Tool Call

```bash
# Post tweet
opencli mcp call twitter_post \
  --content "Hello from OpenCLI! 🚀" \

# Search tweets
opencli mcp call twitter_search \
  --query "OpenAI GPT" \
  --max_results 10

# Reply to tweet
opencli mcp call twitter_reply \
  --tweet_id "1234567890" \
  --content "Thanks for sharing!"
```

## Tools

### twitter_post
Post a tweet to Twitter/X.

**Parameters:**
- `content` (string, required) - Tweet content (max 280 chars)
- `reply_to` (string, optional) - Tweet ID to reply to
- `media_urls` (array, optional) - Media URLs to attach

**Example:**
```json
{
  "content": "We just released v1.0.0! 🎉\n\nNew features:\n- Feature A\n- Feature B\n\n#OpenSource",
  "media_urls": ["https://example.com/image.jpg"]
}
```

### twitter_search
Search tweets by keywords.

**Parameters:**
- `query` (string, required) - Search query
- `max_results` (number, optional) - Max results (default: 10)

**Example:**
```json
{
  "query": "#OpenAI OR #ChatGPT",
  "max_results": 20
}
```

### twitter_monitor
Monitor keywords in real-time.

**Parameters:**
- `keywords` (array, required) - Keywords to monitor

**Example:**
```json
{
  "keywords": ["OpenCLI", "automation", "#DevTools"]
}
```

### twitter_reply
Reply to a tweet.

**Parameters:**
- `tweet_id` (string, required) - Tweet ID
- `content` (string, required) - Reply content

## Use Cases

### 1. GitHub Release → Twitter

Automatically post to Twitter when you create a GitHub release:

```javascript
// Workflow: GitHub Release → Twitter
opencli "When I create a GitHub release, post a tweet with the release notes"

// AI orchestrates:
// 1. Monitor GitHub releases
// 2. Extract version and notes
// 3. Post tweet with twitter_post
```

### 2. Keyword Monitoring & Auto-Reply

Monitor tech keywords and auto-reply:

```javascript
opencli "Monitor tweets mentioning 'OpenCLI' and reply thanking them"

// AI:
// 1. twitter_monitor({ keywords: ["OpenCLI"] })
// 2. On new tweet → twitter_reply({ content: "Thanks!" })
```

### 3. Scheduled Tweets

Post tweets on schedule:

```javascript
opencli "Every Monday at 9am, post 'Happy Monday!' tweet"

// AI:
// 1. Schedule task
// 2. twitter_post({ content: "Happy Monday! 🌞" })
```

## Development

```bash
# Install dependencies
npm install

# Run in development mode
npm run dev

# Test the plugin
npm test

# Build for production
npm run build
```

## Permissions

This plugin requires:
- `network` - To call Twitter API
- `credentials.read` - To read API keys

## Troubleshooting

### Error: Invalid credentials
- Check your `.env` file has correct API keys
- Verify credentials at https://developer.twitter.com

### Error: Rate limit exceeded
- Twitter has rate limits
- Wait and try again
- Consider upgrading Twitter API plan

### Error: Tweet too long
- Max 280 characters
- Split into thread if needed

## Roadmap

- [x] Post tweets
- [x] Search tweets
- [x] Reply to tweets
- [x] Monitor keywords
- [ ] Media uploads (images/videos)
- [ ] Tweet threads
- [ ] Tweet analytics
- [ ] DM support
- [ ] Twitter Spaces

## License

MIT

## Links

- [Twitter API Docs](https://developer.twitter.com/en/docs)
- [OpenCLI Documentation](https://opencli.dev/docs)
- [Report Issues](https://github.com/opencli/twitter-api-plugin/issues)
