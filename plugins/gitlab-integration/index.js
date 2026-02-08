#!/usr/bin/env node

/**
 * GitLab Integration MCP Server
 *
 * Provides tools for GitLab operations:
 * - List projects
 * - Create and manage merge requests
 * - Create and manage issues
 * - Trigger and monitor CI/CD pipelines
 */

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { CallToolRequestSchema, ListToolsRequestSchema } from '@modelcontextprotocol/sdk/types.js';
import { Gitlab } from '@gitbeaker/rest';
import dotenv from 'dotenv';

dotenv.config();

const TOOLS = [
  {
    name: 'gitlab_list_projects',
    description: 'List GitLab projects',
    inputSchema: {
      type: 'object',
      properties: {
        search: { type: 'string', description: 'Search query' },
        owned: { type: 'boolean', description: 'Only show owned projects' }
      }
    }
  },
  {
    name: 'gitlab_create_merge_request',
    description: 'Create a merge request',
    inputSchema: {
      type: 'object',
      properties: {
        projectId: { type: 'string', description: 'Project ID or path' },
        sourceBranch: { type: 'string', description: 'Source branch' },
        targetBranch: { type: 'string', description: 'Target branch' },
        title: { type: 'string', description: 'MR title' },
        description: { type: 'string', description: 'MR description' }
      },
      required: ['projectId', 'sourceBranch', 'targetBranch', 'title']
    }
  },
  {
    name: 'gitlab_list_merge_requests',
    description: 'List merge requests for a project',
    inputSchema: {
      type: 'object',
      properties: {
        projectId: { type: 'string', description: 'Project ID or path' },
        state: { type: 'string', description: 'MR state (opened, closed, merged)' }
      },
      required: ['projectId']
    }
  },
  {
    name: 'gitlab_create_issue',
    description: 'Create an issue',
    inputSchema: {
      type: 'object',
      properties: {
        projectId: { type: 'string', description: 'Project ID or path' },
        title: { type: 'string', description: 'Issue title' },
        description: { type: 'string', description: 'Issue description' }
      },
      required: ['projectId', 'title']
    }
  },
  {
    name: 'gitlab_trigger_pipeline',
    description: 'Trigger a CI/CD pipeline',
    inputSchema: {
      type: 'object',
      properties: {
        projectId: { type: 'string', description: 'Project ID or path' },
        ref: { type: 'string', description: 'Branch or tag name' }
      },
      required: ['projectId', 'ref']
    }
  }
];

class GitLabServer {
  constructor() {
    this.gitlab = new Gitlab({
      token: process.env.GITLAB_TOKEN,
      host: process.env.GITLAB_HOST || 'https://gitlab.com'
    });

    this.server = new Server(
      {
        name: 'gitlab-integration',
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
    this.server.setRequestHandler(ListToolsRequestSchema, async () => ({
      tools: TOOLS
    }));

    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      const { name, arguments: args } = request.params;

      try {
        switch (name) {
          case 'gitlab_list_projects':
            return await this.handleListProjects(args);
          case 'gitlab_create_merge_request':
            return await this.handleCreateMergeRequest(args);
          case 'gitlab_list_merge_requests':
            return await this.handleListMergeRequests(args);
          case 'gitlab_create_issue':
            return await this.handleCreateIssue(args);
          case 'gitlab_trigger_pipeline':
            return await this.handleTriggerPipeline(args);
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

  async handleListProjects(args) {
    const options = {};
    if (args.search) options.search = args.search;
    if (args.owned) options.owned = true;

    const projects = await this.gitlab.Projects.all(options);

    const projectList = projects.map(p => ({
      id: p.id,
      name: p.name,
      path: p.path_with_namespace,
      url: p.web_url
    }));

    return {
      content: [
        {
          type: 'text',
          text: `GitLab Projects:\n${JSON.stringify(projectList, null, 2)}`
        }
      ]
    };
  }

  async handleCreateMergeRequest(args) {
    const mr = await this.gitlab.MergeRequests.create(
      args.projectId,
      args.sourceBranch,
      args.targetBranch,
      args.title,
      { description: args.description }
    );

    return {
      content: [
        {
          type: 'text',
          text: `Merge Request created:\nTitle: ${mr.title}\nURL: ${mr.web_url}\nIID: ${mr.iid}`
        }
      ]
    };
  }

  async handleListMergeRequests(args) {
    const mrs = await this.gitlab.MergeRequests.all({
      projectId: args.projectId,
      state: args.state || 'opened'
    });

    const mrList = mrs.map(mr => ({
      iid: mr.iid,
      title: mr.title,
      author: mr.author.name,
      state: mr.state,
      url: mr.web_url
    }));

    return {
      content: [
        {
          type: 'text',
          text: `Merge Requests:\n${JSON.stringify(mrList, null, 2)}`
        }
      ]
    };
  }

  async handleCreateIssue(args) {
    const issue = await this.gitlab.Issues.create(args.projectId, {
      title: args.title,
      description: args.description
    });

    return {
      content: [
        {
          type: 'text',
          text: `Issue created:\nTitle: ${issue.title}\nURL: ${issue.web_url}\nIID: ${issue.iid}`
        }
      ]
    };
  }

  async handleTriggerPipeline(args) {
    const pipeline = await this.gitlab.Pipelines.create(args.projectId, args.ref);

    return {
      content: [
        {
          type: 'text',
          text: `Pipeline triggered:\nID: ${pipeline.id}\nRef: ${pipeline.ref}\nStatus: ${pipeline.status}\nURL: ${pipeline.web_url}`
        }
      ]
    };
  }

  async run() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error('GitLab Integration MCP server running on stdio');
  }
}

const server = new GitLabServer();
server.run().catch(console.error);
