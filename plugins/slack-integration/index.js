#!/usr/bin/env node

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { WebClient } from '@slack/web-api';
import dotenv from 'dotenv';

dotenv.config();

const slack = new WebClient(process.env.SLACK_TOKEN);

const server = new Server(
  { name: 'slack-integration', version: '1.0.0' },
  { capabilities: { tools: {} } }
);

server.setRequestHandler('tools/list', async () => ({
  tools: [
    {
      name: 'slack_send_message',
      description: 'Send a message to Slack channel',
      inputSchema: {
        type: 'object',
        properties: {
          channel: { type: 'string', description: 'Channel ID or name' },
          text: { type: 'string', description: 'Message text' },
        },
        required: ['channel', 'text'],
      },
    },
  ],
}));

server.setRequestHandler('tools/call', async (request) => {
  const { name, arguments: args } = request.params;

  if (name === 'slack_send_message') {
    const result = await slack.chat.postMessage({
      channel: args.channel,
      text: args.text,
    });

    return {
      content: [{
        type: 'text',
        text: JSON.stringify({ success: true, ts: result.ts }, null, 2),
      }],
    };
  }
});

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error('Slack MCP server running');
}

main();
