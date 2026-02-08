#!/usr/bin/env node

/**
 * AWS Integration MCP Server
 *
 * Provides tools for interacting with AWS services:
 * - S3: Upload, download, list objects
 * - EC2: List, start, stop instances
 * - Lambda: Invoke, list functions
 */

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { CallToolRequestSchema, ListToolsRequestSchema } from '@modelcontextprotocol/sdk/types.js';
import dotenv from 'dotenv';

// Load environment variables
dotenv.config();

// Tool definitions
const TOOLS = [
  {
    name: 'aws_s3_upload',
    description: 'Upload a file to AWS S3 bucket',
    inputSchema: {
      type: 'object',
      properties: {
        bucket: { type: 'string', description: 'S3 bucket name' },
        key: { type: 'string', description: 'Object key (file path in bucket)' },
        filePath: { type: 'string', description: 'Local file path to upload' }
      },
      required: ['bucket', 'key', 'filePath']
    }
  },
  {
    name: 'aws_s3_list',
    description: 'List objects in an S3 bucket',
    inputSchema: {
      type: 'object',
      properties: {
        bucket: { type: 'string', description: 'S3 bucket name' },
        prefix: { type: 'string', description: 'Optional prefix filter' }
      },
      required: ['bucket']
    }
  },
  {
    name: 'aws_ec2_list',
    description: 'List EC2 instances',
    inputSchema: {
      type: 'object',
      properties: {
        region: { type: 'string', description: 'AWS region (default: us-east-1)' }
      }
    }
  },
  {
    name: 'aws_lambda_invoke',
    description: 'Invoke an AWS Lambda function',
    inputSchema: {
      type: 'object',
      properties: {
        functionName: { type: 'string', description: 'Lambda function name' },
        payload: { type: 'object', description: 'Function payload (JSON)' }
      },
      required: ['functionName']
    }
  }
];

class AWSServer {
  constructor() {
    this.server = new Server(
      {
        name: 'aws-integration',
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
          case 'aws_s3_upload':
            return await this.handleS3Upload(args);
          case 'aws_s3_list':
            return await this.handleS3List(args);
          case 'aws_ec2_list':
            return await this.handleEC2List(args);
          case 'aws_lambda_invoke':
            return await this.handleLambdaInvoke(args);
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

  async handleS3Upload(args) {
    const { bucket, key, filePath } = args;
    // TODO: Implement actual AWS SDK calls
    return {
      content: [
        {
          type: 'text',
          text: `Would upload ${filePath} to s3://${bucket}/${key}\n(AWS SDK integration required)`
        }
      ]
    };
  }

  async handleS3List(args) {
    const { bucket, prefix = '' } = args;
    return {
      content: [
        {
          type: 'text',
          text: `Would list objects in s3://${bucket}/${prefix}\n(AWS SDK integration required)`
        }
      ]
    };
  }

  async handleEC2List(args) {
    const { region = 'us-east-1' } = args;
    return {
      content: [
        {
          type: 'text',
          text: `Would list EC2 instances in ${region}\n(AWS SDK integration required)`
        }
      ]
    };
  }

  async handleLambdaInvoke(args) {
    const { functionName, payload = {} } = args;
    return {
      content: [
        {
          type: 'text',
          text: `Would invoke Lambda function ${functionName}\n(AWS SDK integration required)`
        }
      ]
    };
  }

  async run() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error('AWS Integration MCP server running on stdio');
  }
}

const server = new AWSServer();
server.run().catch(console.error);
