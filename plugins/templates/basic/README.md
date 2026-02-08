# Basic MCP Plugin Template

Minimal template to start building your own MCP plugin.

## Quick Start

```bash
# 1. Copy template
cp -r plugins/templates/basic plugins/my-plugin
cd plugins/my-plugin

# 2. Install dependencies
npm install

# 3. Test the plugin
npm start
```

## What's Included

- ✅ MCP Server setup
- ✅ Tool definitions
- ✅ Request handlers
- ✅ Error handling
- ✅ Example tools (hello, calculate)

## Customizing Your Plugin

### 1. Update package.json

```json
{
  "name": "@opencli/your-plugin-name",
  "description": "Your plugin description",
  "author": "Your Name"
}
```

### 2. Define Your Tools

Edit the `TOOLS` array:

```javascript
const TOOLS = [
  {
    name: 'my_tool',
    description: 'What your tool does',
    inputSchema: {
      type: 'object',
      properties: {
        param1: { type: 'string', description: 'Parameter description' },
        param2: { type: 'number', description: 'Number parameter' }
      },
      required: ['param1']
    }
  }
];
```

### 3. Implement Handlers

Add a handler method:

```javascript
async handleMyTool(args) {
  const { param1, param2 } = args;

  // Your logic here
  const result = doSomething(param1, param2);

  return {
    content: [
      {
        type: 'text',
        text: `Result: ${result}`
      }
    ]
  };
}
```

### 4. Register Handler

Add to the switch statement:

```javascript
switch (name) {
  case 'my_tool':
    return await this.handleMyTool(args);
  // ... other cases
}
```

## Testing Your Plugin

1. **Run directly:**
   ```bash
   npm start
   ```

2. **Test with echo:**
   ```bash
   echo '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' | npm start
   ```

3. **Configure in OpenCLI:**
   ```json
   {
     "mcpServers": {
       "my-plugin": {
         "command": "node",
         "args": ["/path/to/plugins/my-plugin/index.js"]
       }
     }
   }
   ```

## Adding Dependencies

```bash
# For HTTP requests
npm install axios

# For file operations
npm install fs-extra

# For async operations
npm install async
```

## Best Practices

1. **Error Handling**
   - Always validate input parameters
   - Return descriptive error messages
   - Use try-catch blocks

2. **Input Validation**
   ```javascript
   if (!args.param1) {
     throw new Error('param1 is required');
   }
   ```

3. **Return Format**
   ```javascript
   return {
     content: [{
       type: 'text',
       text: 'Your response here'
     }],
     isError: false  // optional, defaults to false
   };
   ```

4. **Logging**
   ```javascript
   // Use console.error for logs (stdout is for MCP protocol)
   console.error('Processing request:', args);
   ```

## Examples

Check out these plugins for inspiration:

- **Simple:** `github-automation`, `slack-integration`
- **Complex:** `playwright-automation`, `kubernetes-manager`
- **Database:** `postgresql-manager`

## Documentation

- [MCP SDK Documentation](https://github.com/modelcontextprotocol/sdk)
- [MCP Protocol Spec](https://spec.modelcontextprotocol.io/)

## License

MIT
