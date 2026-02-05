#!/usr/bin/env node

/**
 * API Wrapper MCP Server Template
 *
 * This template helps you quickly create an MCP plugin that wraps an external API.
 * Replace the placeholder API calls with your actual API integration.
 *
 * Quick Start:
 * 1. Copy this template to your plugin directory
 * 2. Update package.json with your plugin details
 * 3. Replace API_BASE_URL with your API endpoint
 * 4. Update tool definitions and handlers
 * 5. Add your API key to .env file
 * 6. Run: npm install && npm start
 */

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { CallToolRequestSchema, ListToolsRequestSchema } from '@modelcontextprotocol/sdk/types.js';
import axios from 'axios';
import dotenv from 'dotenv';

dotenv.config();

// Configuration
const API_BASE_URL = process.env.API_BASE_URL || 'https://api.example.com';
const API_KEY = process.env.API_KEY;

// Tool Definitions
// TODO: Replace with your actual API endpoints
const TOOLS = [
  {
    name: 'get_data',
    description: 'Get data from the API',
    inputSchema: {
      type: 'object',
      properties: {
        id: { type: 'string', description: 'Resource ID' },
        filter: { type: 'string', description: 'Optional filter' }
      },
      required: ['id']
    }
  },
  {
    name: 'list_resources',
    description: 'List all resources',
    inputSchema: {
      type: 'object',
      properties: {
        limit: { type: 'number', description: 'Max results (default: 10)' },
        offset: { type: 'number', description: 'Offset for pagination' }
      }
    }
  },
  {
    name: 'create_resource',
    description: 'Create a new resource',
    inputSchema: {
      type: 'object',
      properties: {
        name: { type: 'string', description: 'Resource name' },
        data: { type: 'object', description: 'Resource data' }
      },
      required: ['name']
    }
  }
];

class APIWrapperServer {
  constructor() {
    this.server = new Server(
      {
        name: 'my-api-plugin',
        version: '1.0.0',
      },
      {
        capabilities: {
          tools: {},
        },
      }
    );

    this.setupHandlers();
    this.server.onerror = (error) => console.error('[MCP Error]', error);

    process.on('SIGINT', async () => {
      await this.server.close();
      process.exit(0);
    });
  }

  setupHandlers() {
    // List available tools
    this.server.setRequestHandler(ListToolsRequestSchema, async () => ({
      tools: TOOLS
    }));

    // Handle tool calls
    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      const { name, arguments: args } = request.params;

      try {
        switch (name) {
          case 'get_data':
            return await this.handleGetData(args);
          case 'list_resources':
            return await this.handleListResources(args);
          case 'create_resource':
            return await this.handleCreateResource(args);
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

  // API Request Helper
  async apiRequest(method, endpoint, data = null) {
    const config = {
      method,
      url: `${API_BASE_URL}${endpoint}`,
      headers: {
        'Authorization': `Bearer ${API_KEY}`,
        'Content-Type': 'application/json'
      }
    };

    if (data) {
      config.data = data;
    }

    const response = await axios(config);
    return response.data;
  }

  // Tool Handlers
  async handleGetData(args) {
    const { id, filter } = args;

    // TODO: Replace with your actual API call
    const data = await this.apiRequest('GET', `/resources/${id}${filter ? `?filter=${filter}` : ''}`);

    return {
      content: [
        {
          type: 'text',
          text: `Resource Data:\n${JSON.stringify(data, null, 2)}`
        }
      ]
    };
  }

  async handleListResources(args) {
    const { limit = 10, offset = 0 } = args;

    // TODO: Replace with your actual API call
    const data = await this.apiRequest('GET', `/resources?limit=${limit}&offset=${offset}`);

    return {
      content: [
        {
          type: 'text',
          text: `Resources (${data.length}):\n${JSON.stringify(data, null, 2)}`
        }
      ]
    };
  }

  async handleCreateResource(args) {
    const { name, data } = args;

    // TODO: Replace with your actual API call
    const result = await this.apiRequest('POST', '/resources', { name, ...data });

    return {
      content: [
        {
          type: 'text',
          text: `Resource created successfully!\nID: ${result.id}\n${JSON.stringify(result, null, 2)}`
        }
      ]
    };
  }

  async run() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error('API Wrapper MCP server running on stdio');
  }
}

const server = new APIWrapperServer();
server.run().catch(console.error);
