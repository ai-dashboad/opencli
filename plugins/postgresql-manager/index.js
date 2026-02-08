#!/usr/bin/env node

/**
 * PostgreSQL Manager MCP Server
 *
 * Provides tools for database operations:
 * - Execute queries
 * - List tables
 * - Describe table schema
 * - Connect to database
 */

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { CallToolRequestSchema, ListToolsRequestSchema } from '@modelcontextprotocol/sdk/types.js';
import pg from 'pg';
import dotenv from 'dotenv';

dotenv.config();

const { Client } = pg;

const TOOLS = [
  {
    name: 'pg_query',
    description: 'Execute a SQL query',
    inputSchema: {
      type: 'object',
      properties: {
        query: { type: 'string', description: 'SQL query to execute' },
        params: { type: 'array', description: 'Query parameters', items: { type: 'string' } }
      },
      required: ['query']
    }
  },
  {
    name: 'pg_list_tables',
    description: 'List all tables in the database',
    inputSchema: {
      type: 'object',
      properties: {
        schema: { type: 'string', description: 'Schema name (default: public)' }
      }
    }
  },
  {
    name: 'pg_describe_table',
    description: 'Get table schema information',
    inputSchema: {
      type: 'object',
      properties: {
        table: { type: 'string', description: 'Table name' }
      },
      required: ['table']
    }
  }
];

class PostgreSQLServer {
  constructor() {
    this.client = null;

    this.server = new Server(
      {
        name: 'postgresql-manager',
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

  async getClient() {
    if (!this.client) {
      this.client = new Client({
        host: process.env.PG_HOST || 'localhost',
        port: parseInt(process.env.PG_PORT || '5432'),
        database: process.env.PG_DATABASE,
        user: process.env.PG_USER,
        password: process.env.PG_PASSWORD,
      });
      await this.client.connect();
    }
    return this.client;
  }

  async cleanup() {
    if (this.client) {
      await this.client.end();
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
          case 'pg_query':
            return await this.handleQuery(args);
          case 'pg_list_tables':
            return await this.handleListTables(args);
          case 'pg_describe_table':
            return await this.handleDescribeTable(args);
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

  async handleQuery(args) {
    const client = await this.getClient();
    const result = await client.query(args.query, args.params || []);

    return {
      content: [
        {
          type: 'text',
          text: `Query executed successfully\nRows affected: ${result.rowCount}\n\n${JSON.stringify(result.rows, null, 2)}`
        }
      ]
    };
  }

  async handleListTables(args) {
    const client = await this.getClient();
    const schema = args.schema || 'public';

    const result = await client.query(
      `SELECT tablename FROM pg_tables WHERE schemaname = $1 ORDER BY tablename`,
      [schema]
    );

    const tables = result.rows.map(r => r.tablename);

    return {
      content: [
        {
          type: 'text',
          text: `Tables in schema '${schema}':\n${tables.join('\n')}`
        }
      ]
    };
  }

  async handleDescribeTable(args) {
    const client = await this.getClient();

    const result = await client.query(
      `SELECT column_name, data_type, is_nullable
       FROM information_schema.columns
       WHERE table_name = $1
       ORDER BY ordinal_position`,
      [args.table]
    );

    const columns = result.rows.map(c =>
      `${c.column_name} (${c.data_type}) ${c.is_nullable === 'YES' ? 'NULL' : 'NOT NULL'}`
    );

    return {
      content: [
        {
          type: 'text',
          text: `Schema for table '${args.table}':\n${columns.join('\n')}`
        }
      ]
    };
  }

  async run() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error('PostgreSQL Manager MCP server running on stdio');
  }
}

const server = new PostgreSQLServer();
server.run().catch(console.error);
