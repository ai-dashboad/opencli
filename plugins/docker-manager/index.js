#!/usr/bin/env node

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import Docker from 'dockerode';

const docker = new Docker();

const server = new Server(
  { name: 'docker-manager', version: '1.0.0' },
  { capabilities: { tools: {} } }
);

server.setRequestHandler('tools/list', async () => ({
  tools: [
    {
      name: 'docker_list_containers',
      description: 'List Docker containers',
      inputSchema: {
        type: 'object',
        properties: {
          all: { type: 'boolean', description: 'Show all containers' },
        },
      },
    },
    {
      name: 'docker_run',
      description: 'Run a Docker container',
      inputSchema: {
        type: 'object',
        properties: {
          image: { type: 'string', description: 'Image name' },
          name: { type: 'string', description: 'Container name' },
          ports: { type: 'object', description: 'Port mappings' },
        },
        required: ['image'],
      },
    },
  ],
}));

server.setRequestHandler('tools/call', async (request) => {
  const { name, arguments: args } = request.params;

  if (name === 'docker_list_containers') {
    const containers = await docker.listContainers({ all: args.all });
    return {
      content: [{
        type: 'text',
        text: JSON.stringify({ containers }, null, 2),
      }],
    };
  }

  if (name === 'docker_run') {
    const container = await docker.createContainer({
      Image: args.image,
      name: args.name,
      HostConfig: { PortBindings: args.ports },
    });
    await container.start();

    return {
      content: [{
        type: 'text',
        text: JSON.stringify({ success: true, id: container.id }, null, 2),
      }],
    };
  }
});

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error('Docker MCP server running');
}

main();
