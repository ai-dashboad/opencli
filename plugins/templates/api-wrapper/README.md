# API Wrapper Plugin Template

This template provides a starting point for creating MCP plugins that wrap external APIs.

## Quick Start

1. **Copy this template**
   ```bash
   cp -r plugins/templates/api-wrapper plugins/my-api-plugin
   cd plugins/my-api-plugin
   ```

2. **Update package.json**
   - Change `name` to `@opencli/your-plugin-name`
   - Update `description`
   - Add your name to `author`
   - Update MCP capabilities list

3. **Configure your API**
   - Copy `.env.example` to `.env`
   - Add your API base URL and API key
   - Update `API_BASE_URL` and `API_KEY` in `.env`

4. **Customize tools**
   - Edit `TOOLS` array in `index.js`
   - Update tool names and descriptions
   - Add/remove tools as needed

5. **Implement API calls**
   - Replace placeholder API calls with your actual endpoints
   - Update `apiRequest` method if needed
   - Add authentication headers

6. **Install dependencies**
   ```bash
   npm install
   ```

7. **Test your plugin**
   ```bash
   npm start
   ```

## File Structure

```
my-api-plugin/
├── package.json      # Plugin metadata and dependencies
├── index.js          # Main MCP server implementation
├── .env.example      # Environment variables template
├── .env              # Your actual credentials (gitignored)
└── README.md         # This file
```

## Configuration

Create a `.env` file with your API credentials:

```env
API_BASE_URL=https://api.example.com
API_KEY=your-api-key-here
```

## Adding to OpenCLI

1. Configure the plugin in `~/.opencli/mcp-servers.json`:
   ```json
   {
     "mcpServers": {
       "my-api-plugin": {
         "command": "node",
         "args": ["/path/to/plugins/my-api-plugin/index.js"],
         "env": {
           "API_BASE_URL": "https://api.example.com",
           "API_KEY": "your-api-key"
         }
       }
     }
   }
   ```

2. Or use the Plugin Marketplace UI:
   - Open http://localhost:9877
   - Find your plugin
   - Click "Configure"
   - Add your settings

## Customization Tips

### Adding New Tools

```javascript
const TOOLS = [
  // ... existing tools
  {
    name: 'my_new_tool',
    description: 'Description of what it does',
    inputSchema: {
      type: 'object',
      properties: {
        param1: { type: 'string', description: 'Parameter description' }
      },
      required: ['param1']
    }
  }
];
```

Then add a handler:

```javascript
async handleMyNewTool(args) {
  const { param1 } = args;
  const data = await this.apiRequest('GET', `/endpoint/${param1}`);
  return {
    content: [{
      type: 'text',
      text: JSON.stringify(data, null, 2)
    }]
  };
}
```

### Error Handling

The template includes basic error handling. Enhance it:

```javascript
async apiRequest(method, endpoint, data = null) {
  try {
    const response = await axios({
      method,
      url: `${API_BASE_URL}${endpoint}`,
      headers: {
        'Authorization': `Bearer ${API_KEY}`,
        'Content-Type': 'application/json'
      },
      data,
      timeout: 30000
    });
    return response.data;
  } catch (error) {
    if (error.response) {
      throw new Error(`API Error ${error.response.status}: ${error.response.data.message}`);
    }
    throw error;
  }
}
```

## Examples

See the existing plugins for inspiration:
- `plugins/github-automation/` - GitHub API wrapper
- `plugins/slack-integration/` - Slack API wrapper
- `plugins/twitter-api/` - Twitter API wrapper

## License

MIT
