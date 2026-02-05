#!/usr/bin/env node

/**
 * Basic MCP Server Template
 *
 * Minimal template to get started with MCP plugin development.
 * Add your own tools and functionality.
 */

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { CallToolRequestSchema, ListToolsRequestSchema } from '@modelcontextprotocol/sdk/types.js';
import dotenv from 'dotenv';

dotenv.config();

// Define your tools
const TOOLS = [
  {
    name: 'hello',
    description: 'Say hello',
    inputSchema: {
      type: 'object',
      properties: {
        name: { type: 'string', description: 'Name to greet' }
      },
      required: ['name']
    }
  },
  {
    name: 'calculate',
    description: 'Perform a calculation',
    inputSchema: {
      type: 'object',
      properties: {
        operation: { type: 'string', enum: ['add', 'subtract', 'multiply', 'divide'] },
        a: { type: 'number', description: 'First number' },
        b: { type: 'number', description: 'Second number' }
      },
      required: ['operation', 'a', 'b']
    }
  }
];

class MyMCPServer {
  constructor() {
    // Create MCP server instance
    this.server = new Server(
      {
        name: 'my-plugin',
        version: '1.0.0',
      },
      {
        capabilities: {
          tools: {},
        },
      }
    );

    this.setupHandlers();

    // Error handling
    this.server.onerror = (error) => console.error('[MCP Error]', error);

    // Graceful shutdown
    process.on('SIGINT', async () => {
      await this.server.close();
      process.exit(0);
    });
  }

  setupHandlers() {
    // Handler: List available tools
    this.server.setRequestHandler(ListToolsRequestSchema, async () => ({
      tools: TOOLS
    }));

    // Handler: Execute tool
    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      const { name, arguments: args } = request.params;

      try {
        // Route to appropriate handler
        switch (name) {
          case 'hello':
            return await this.handleHello(args);
          case 'calculate':
            return await this.handleCalculate(args);
          default:
            throw new Error(`Unknown tool: ${name}`);
        }
      } catch (error) {
        return {
          content: [
            {
              type: 'text',
              text: `Error: ${error.message}`
            }
          ],
          isError: true,
        };
      }
    });
  }

  // Tool: Say hello
  async handleHello(args) {
    const { name } = args;

    return {
      content: [
        {
          type: 'text',
          text: `Hello, ${name}! 👋`
        }
      ]
    };
  }

  // Tool: Calculate
  async handleCalculate(args) {
    const { operation, a, b } = args;

    let result;
    switch (operation) {
      case 'add':
        result = a + b;
        break;
      case 'subtract':
        result = a - b;
        break;
      case 'multiply':
        result = a * b;
        break;
      case 'divide':
        if (b === 0) throw new Error('Cannot divide by zero');
        result = a / b;
        break;
      default:
        throw new Error(`Unknown operation: ${operation}`);
    }

    return {
      content: [
        {
          type: 'text',
          text: `${a} ${operation} ${b} = ${result}`
        }
      ]
    };
  }

  async run() {
    // Connect to stdio transport
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error('MCP server running on stdio');
  }
}

// Start the server
const server = new MyMCPServer();
server.run().catch(console.error);
