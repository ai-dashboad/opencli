# Plugin Generator CLI

Interactive command-line tool to quickly create new MCP plugins from templates.

## Features

- 🎯 **Interactive**: Step-by-step plugin creation
- 📋 **Templates**: Choose from API Wrapper, Database, or Basic templates
- ✨ **Auto-configuration**: Automatically updates package.json with your details
- 🚀 **Ready to use**: Generated plugins work immediately

## Usage

### Quick Start

```bash
cd /path/to/opencli
node scripts/create-plugin.js
```

### Step-by-Step

1. **Run the generator**
   ```bash
   node scripts/create-plugin.js
   ```

2. **Choose a template**
   ```
   📋 Available Templates:

   1. 🌐 API Wrapper
      Template for wrapping external REST APIs

   2. 🗄️ Database
      Template for database integrations

   3. 🎯 Basic
      Minimal template to start from scratch

   Select template (1-3): _
   ```

3. **Enter plugin details**
   ```
   Plugin name (e.g., weather-api): my-awesome-plugin
   Description: My awesome MCP plugin
   Author name: Your Name
   ```

4. **Confirm and create**
   ```
   📝 Plugin Configuration:
      Template:    API Wrapper
      Name:        my-awesome-plugin
      Description: My awesome MCP plugin
      Author:      Your Name

   Create plugin? (y/n): y
   ```

5. **Done!**
   ```
   ✨ Plugin created successfully!

   Next steps:
     1. cd plugins/my-awesome-plugin
     2. npm install
     3. Edit index.js and customize your tools
     4. npm start
   ```

## Generated Files

The generator creates a complete plugin structure:

```
plugins/my-awesome-plugin/
├── package.json      # Plugin metadata (auto-configured)
├── index.js          # MCP server implementation
├── .env.example      # Environment variables template
├── .gitignore        # Git ignore rules
└── README.md         # Plugin documentation
```

## Customization

After generation, the plugin is ready to customize:

### 1. Update Tools

Edit `index.js` and modify the `TOOLS` array:

```javascript
const TOOLS = [
  {
    name: 'my_tool',
    description: 'What my tool does',
    inputSchema: {
      type: 'object',
      properties: {
        // Your parameters
      }
    }
  }
];
```

### 2. Implement Handlers

Add your tool implementation:

```javascript
async handleMyTool(args) {
  // Your logic here
  return {
    content: [{
      type: 'text',
      text: 'Result'
    }]
  };
}
```

### 3. Configure Environment

Copy `.env.example` to `.env` and add your configuration:

```bash
cp .env.example .env
# Edit .env with your credentials
```

## Examples

### Creating an API Wrapper Plugin

```bash
$ node scripts/create-plugin.js

Select template (1-3): 1
Plugin name: weather-api
Description: Weather data from OpenWeatherMap API
Author name: John Doe
Create plugin? (y/n): y

✨ Plugin created successfully!
```

Result:
```
plugins/weather-api/
├── package.json      # @opencli/weather-api
├── index.js          # With axios, API request helpers
├── .env.example      # API_KEY placeholder
└── README.md         # API wrapper guide
```

### Creating a Database Plugin

```bash
$ node scripts/create-plugin.js

Select template (1-3): 2
Plugin name: redis-manager
Description: Redis cache management
Author name: Jane Smith
Create plugin? (y/n): y
```

Result:
```
plugins/redis-manager/
├── package.json      # @opencli/redis-manager
├── index.js          # With database connection helpers
├── .env.example      # DB connection settings
└── README.md         # Database guide
```

## Tips

### Naming Conventions

✅ **Good names:**
- `weather-api`
- `slack-bot`
- `postgres-manager`
- `file-converter`

❌ **Bad names:**
- `WeatherAPI` (use lowercase)
- `my plugin` (no spaces)
- `@opencli/weather` (don't include scope)

### Template Selection Guide

| Use Case | Template | Why |
|----------|----------|-----|
| REST API integration | API Wrapper | Includes axios, auth headers |
| Database operations | Database | Connection management patterns |
| Custom tool | Basic | Minimal, fully customizable |
| File operations | Basic | Simple, no extra dependencies |
| Web scraping | API Wrapper | HTTP requests built-in |

### After Generation

1. **Install dependencies**
   ```bash
   cd plugins/your-plugin
   npm install
   ```

2. **Add custom dependencies**
   ```bash
   npm install redis  # For Redis plugin
   npm install cheerio  # For web scraping
   ```

3. **Test immediately**
   ```bash
   npm start
   echo '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' | npm start
   ```

4. **Configure in OpenCLI**
   - Use Plugin Marketplace UI: http://localhost:9877
   - Or edit `~/.opencli/mcp-servers.json` manually

## Troubleshooting

### "Plugin directory already exists"

Solution: Choose a different name or delete the existing directory:
```bash
rm -rf plugins/your-plugin
```

### "Invalid plugin name"

Plugin names must:
- Use lowercase letters
- Use numbers
- Use hyphens (-)
- No spaces, underscores, or special characters

Examples: `my-plugin`, `api-wrapper-2`, `tool-v1`

### "Permission denied"

Make the script executable:
```bash
chmod +x scripts/create-plugin.js
```

## Advanced Usage

### Non-Interactive Mode

You can also copy templates manually:

```bash
# Copy template
cp -r plugins/templates/api-wrapper plugins/my-plugin

# Manually update package.json
sed -i '' 's/my-api-plugin/my-plugin/g' plugins/my-plugin/package.json
```

### Custom Templates

1. Create your template in `plugins/templates/my-template/`
2. Add it to `TEMPLATES` in `create-plugin.js`
3. Run the generator

## Integration

Generated plugins work with:

- ✅ OpenCLI Daemon
- ✅ Plugin Marketplace UI
- ✅ MCP Protocol v1.0
- ✅ npm/yarn package managers

## Resources

- [Plugin Templates Guide](../plugins/templates/README.md)
- [MCP SDK Documentation](https://github.com/modelcontextprotocol/sdk)
- [Example Plugins](../plugins/)

## Support

Questions? Issues?

- 📖 Check the [templates README](../plugins/templates/README.md)
- 🐛 [Report bugs](https://github.com/ai-dashboard/opencli/issues)
- 💬 [Ask questions](https://github.com/ai-dashboard/opencli/discussions)

## License

MIT
