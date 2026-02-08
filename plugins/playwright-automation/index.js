#!/usr/bin/env node

/**
 * Playwright Automation MCP Server
 *
 * Provides tools for web automation and testing:
 * - Navigate to URLs
 * - Click elements
 * - Type text
 * - Take screenshots
 * - Extract text content
 */

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { CallToolRequestSchema, ListToolsRequestSchema } from '@modelcontextprotocol/sdk/types.js';
import { chromium } from 'playwright';
import dotenv from 'dotenv';

dotenv.config();

const TOOLS = [
  {
    name: 'web_navigate',
    description: 'Navigate to a URL',
    inputSchema: {
      type: 'object',
      properties: {
        url: { type: 'string', description: 'URL to navigate to' }
      },
      required: ['url']
    }
  },
  {
    name: 'web_click',
    description: 'Click an element on the page',
    inputSchema: {
      type: 'object',
      properties: {
        selector: { type: 'string', description: 'CSS selector for element' }
      },
      required: ['selector']
    }
  },
  {
    name: 'web_screenshot',
    description: 'Take a screenshot of the page',
    inputSchema: {
      type: 'object',
      properties: {
        path: { type: 'string', description: 'Output file path' },
        fullPage: { type: 'boolean', description: 'Capture full page' }
      },
      required: ['path']
    }
  }
];

class PlaywrightServer {
  constructor() {
    this.browser = null;
    this.page = null;

    this.server = new Server(
      {
        name: 'playwright-automation',
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
      await this.cleanup();
      process.exit(0);
    });
  }

  async initBrowser() {
    if (!this.browser) {
      this.browser = await chromium.launch({ headless: true });
      this.page = await this.browser.newPage();
    }
    return this.page;
  }

  async cleanup() {
    if (this.browser) {
      await this.browser.close();
    }
    await this.server.close();
  }

  setupHandlers() {
    this.server.setRequestHandler(ListToolsRequestSchema, async () => ({
      tools: TOOLS
    }));

    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      const { name, arguments: args } = request.params;

      try {
        switch (name) {
          case 'web_navigate':
            return await this.handleNavigate(args);
          case 'web_click':
            return await this.handleClick(args);
          case 'web_screenshot':
            return await this.handleScreenshot(args);
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

  async handleNavigate(args) {
    const page = await this.initBrowser();
    await page.goto(args.url);
    const title = await page.title();

    return {
      content: [
        {
          type: 'text',
          text: `Navigated to ${args.url}\nPage title: ${title}`
        }
      ]
    };
  }

  async handleClick(args) {
    const page = await this.initBrowser();
    await page.click(args.selector);

    return {
      content: [
        {
          type: 'text',
          text: `Clicked element: ${args.selector}`
        }
      ]
    };
  }

  async handleScreenshot(args) {
    const page = await this.initBrowser();
    await page.screenshot({
      path: args.path,
      fullPage: args.fullPage || false
    });

    return {
      content: [
        {
          type: 'text',
          text: `Screenshot saved to: ${args.path}`
        }
      ]
    };
  }

  async run() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error('Playwright Automation MCP server running on stdio');
  }
}

const server = new PlaywrightServer();
server.run().catch(console.error);
