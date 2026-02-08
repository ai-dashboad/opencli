# OpenCLI Plugin Templates

Quick-start templates for creating MCP (Model Context Protocol) plugins.

## Available Templates

### 1. 🌐 API Wrapper (`api-wrapper/`)

Template for wrapping external REST APIs.

**Best for:**
- Third-party API integrations
- HTTP/REST services
- OAuth-based services

**Includes:**
- axios for HTTP requests
- Environment variable configuration
- Request/response handling
- Error management

**Example use cases:**
- Weather API
- Payment gateway
- CRM integration
- Social media API

---

### 2. 🗄️ Database (`database/`)

Template for database operations.

**Best for:**
- SQL databases (PostgreSQL, MySQL)
- NoSQL databases (MongoDB)
- Database queries and management

**Includes:**
- Connection management
- Query execution
- Table listing
- Schema inspection

**Example use cases:**
- PostgreSQL manager
- MongoDB operations
- MySQL data access
- Database migrations

---

### 3. 🎯 Basic (`basic/`)

Minimal template to start from scratch.

**Best for:**
- Learning MCP development
- Custom tools
- Simple utilities
- Rapid prototyping

**Includes:**
- Basic MCP server setup
- Example tools
- Request handling
- Comments and documentation

**Example use cases:**
- File operations
- Text processing
- Custom calculations
- System utilities

---

## Quick Start

### 1. Choose a Template

```bash
# Copy the template you want
cp -r plugins/templates/api-wrapper plugins/my-plugin
cd plugins/my-plugin
```

### 2. Customize

- Update `package.json` with your plugin details
- Modify tool definitions in `index.js`
- Add your implementation logic
- Configure environment variables in `.env`

### 3. Install & Test

```bash
npm install
npm start
```

### 4. Integrate with OpenCLI

Add to `~/.opencli/mcp-servers.json`:

```json
{
  "mcpServers": {
    "my-plugin": {
      "command": "node",
      "args": ["/path/to/plugins/my-plugin/index.js"],
      "env": {
        "API_KEY": "your-key-here"
      }
    }
  }
}
```

Or use the Plugin Marketplace UI at http://localhost:9877

## Template Structure

Each template includes:

```
template-name/
├── package.json       # Plugin metadata and dependencies
├── index.js          # Main MCP server implementation
├── .env.example      # Environment variables template
└── README.md         # Template-specific documentation
```

## Development Workflow

1. **Copy template** → Customize for your needs
2. **Implement tools** → Add your business logic
3. **Test locally** → Run with `npm start`
4. **Configure** → Add to mcp-servers.json
5. **Use in OpenCLI** → Access via marketplace

## Creating Custom Templates

Want to create a template for a specific use case?

1. Copy an existing template
2. Add your specialized code
3. Update README with instructions
4. Submit a PR!

## MCP Plugin Basics

### Tool Definition

```javascript
{
  name: 'tool_name',
  description: 'What this tool does',
  inputSchema: {
    type: 'object',
    properties: {
      param: { type: 'string', description: 'Parameter description' }
    },
    required: ['param']
  }
}
```

### Tool Handler

```javascript
async handleToolName(args) {
  const { param } = args;

  // Your logic here
  const result = await doSomething(param);

  return {
    content: [{
      type: 'text',
      text: `Result: ${result}`
    }]
  };
}
```

### Error Handling

```javascript
try {
  // Your code
} catch (error) {
  return {
    content: [{
      type: 'text',
      text: `Error: ${error.message}`
    }],
    isError: true
  };
}
```

## Best Practices

1. ✅ Use environment variables for secrets
2. ✅ Validate all input parameters
3. ✅ Provide clear error messages
4. ✅ Add JSDoc comments
5. ✅ Include usage examples in README
6. ✅ Handle edge cases
7. ✅ Use semantic versioning

## Resources

- 📚 [MCP SDK Documentation](https://github.com/modelcontextprotocol/sdk)
- 📖 [MCP Protocol Spec](https://spec.modelcontextprotocol.io/)
- 💡 [Example Plugins](../)
- 🛠️ [Plugin Marketplace](http://localhost:9877)

## Contributing

Have an idea for a new template?

1. Create the template in `plugins/templates/your-template/`
2. Include all required files (package.json, index.js, README.md)
3. Add documentation with examples
4. Submit a pull request

## Examples

### Quick API Wrapper

```bash
cp -r plugins/templates/api-wrapper plugins/weather-api
cd plugins/weather-api
# Edit index.js and add your API calls
npm install
npm start
```

### Database Plugin

```bash
cp -r plugins/templates/database plugins/redis-manager
cd plugins/redis-manager
npm install redis
# Implement Redis operations
npm start
```

## Support

- 🐛 [Report Issues](https://github.com/ai-dashboard/opencli/issues)
- 💬 [Discussions](https://github.com/ai-dashboard/opencli/discussions)
- 📧 Email: support@opencli.ai

## License

MIT - Feel free to use these templates for any purpose.
