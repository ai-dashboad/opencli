#!/usr/bin/env node

/**
 * Database MCP Server Template
 *
 * This template helps you create an MCP plugin for database operations.
 * Supports any database with a Node.js driver (PostgreSQL, MySQL, MongoDB, etc.)
 *
 * Quick Start:
 * 1. Install your database driver: npm install pg (or mysql2, mongodb, etc.)
 * 2. Update DB_TYPE and connection configuration
 * 3. Implement query methods for your database
 * 4. Add your connection string to .env
 * 5. Run: npm install && npm start
 */

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { CallToolRequestSchema, ListToolsRequestSchema } from '@modelcontextprotocol/sdk/types.js';
import dotenv from 'dotenv';

dotenv.config();

// Configuration
// TODO: Install your database driver and import it
// import pg from 'pg';  // For PostgreSQL
// import mysql from 'mysql2/promise';  // For MySQL
// import { MongoClient } from 'mongodb';  // For MongoDB

const DB_TYPE = process.env.DB_TYPE || 'postgresql';
const DB_HOST = process.env.DB_HOST || 'localhost';
const DB_PORT = process.env.DB_PORT || 5432;
const DB_NAME = process.env.DB_NAME;
const DB_USER = process.env.DB_USER;
const DB_PASSWORD = process.env.DB_PASSWORD;

// Tool Definitions
const TOOLS = [
  {
    name: 'execute_query',
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
    name: 'list_tables',
    description: 'List all tables in the database',
    inputSchema: {
      type: 'object',
      properties: {
        schema: { type: 'string', description: 'Schema name (optional)' }
      }
    }
  },
  {
    name: 'describe_table',
    description: 'Get table schema information',
    inputSchema: {
      type: 'object',
      properties: {
        table: { type: 'string', description: 'Table name' }
      },
      required: ['table']
    }
  },
  {
    name: 'get_table_data',
    description: 'Get data from a table with optional filters',
    inputSchema: {
      type: 'object',
      properties: {
        table: { type: 'string', description: 'Table name' },
        limit: { type: 'number', description: 'Max rows (default: 100)' },
        where: { type: 'string', description: 'WHERE clause (optional)' }
      },
      required: ['table']
    }
  }
];

class DatabaseServer {
  constructor() {
    this.client = null;

    this.server = new Server(
      {
        name: 'my-database-plugin',
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

  // Database Connection
  async getClient() {
    if (!this.client) {
      // TODO: Implement connection for your database type
      // Example for PostgreSQL:
      // const { Client } = await import('pg');
      // this.client = new Client({
      //   host: DB_HOST,
      //   port: DB_PORT,
      //   database: DB_NAME,
      //   user: DB_USER,
      //   password: DB_PASSWORD,
      // });
      // await this.client.connect();

      throw new Error('Database client not implemented. Please add your database driver.');
    }
    return this.client;
  }

  async cleanup() {
    if (this.client) {
      // TODO: Implement cleanup for your database type
      // await this.client.end();
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
          case 'execute_query':
            return await this.handleExecuteQuery(args);
          case 'list_tables':
            return await this.handleListTables(args);
          case 'describe_table':
            return await this.handleDescribeTable(args);
          case 'get_table_data':
            return await this.handleGetTableData(args);
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

  // Tool Handlers
  async handleExecuteQuery(args) {
    const client = await this.getClient();
    const { query, params = [] } = args;

    // TODO: Execute query with your database client
    // Example for PostgreSQL:
    // const result = await client.query(query, params);
    // return {
    //   content: [{
    //     type: 'text',
    //     text: `Query executed\nRows: ${result.rowCount}\n${JSON.stringify(result.rows, null, 2)}`
    //   }]
    // };

    return {
      content: [{
        type: 'text',
        text: 'Query execution not implemented. Please add your database driver.'
      }]
    };
  }

  async handleListTables(args) {
    const client = await this.getClient();
    const { schema = 'public' } = args;

    // TODO: Implement table listing for your database
    // Example for PostgreSQL:
    // const result = await client.query(
    //   `SELECT tablename FROM pg_tables WHERE schemaname = $1 ORDER BY tablename`,
    //   [schema]
    // );
    // const tables = result.rows.map(r => r.tablename);

    return {
      content: [{
        type: 'text',
        text: 'Table listing not implemented. Please add your database driver.'
      }]
    };
  }

  async handleDescribeTable(args) {
    const client = await this.getClient();
    const { table } = args;

    // TODO: Implement table description for your database
    // Example for PostgreSQL:
    // const result = await client.query(
    //   `SELECT column_name, data_type, is_nullable
    //    FROM information_schema.columns
    //    WHERE table_name = $1
    //    ORDER BY ordinal_position`,
    //   [table]
    // );

    return {
      content: [{
        type: 'text',
        text: `Table schema not implemented. Please add your database driver.`
      }]
    };
  }

  async handleGetTableData(args) {
    const client = await this.getClient();
    const { table, limit = 100, where } = args;

    // TODO: Implement data retrieval for your database
    // Example for PostgreSQL:
    // let query = `SELECT * FROM ${table}`;
    // if (where) query += ` WHERE ${where}`;
    // query += ` LIMIT ${limit}`;
    // const result = await client.query(query);

    return {
      content: [{
        type: 'text',
        text: `Data retrieval not implemented. Please add your database driver.`
      }]
    };
  }

  async run() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error(`Database MCP server running on stdio (${DB_TYPE})`);
  }
}

const server = new DatabaseServer();
server.run().catch(console.error);
