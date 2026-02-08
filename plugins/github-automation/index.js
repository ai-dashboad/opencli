#!/usr/bin/env node

/**
 * GitHub Automation MCP Plugin for OpenCLI
 *
 * Provides GitHub automation capabilities:
 * - Create releases
 * - Manage PRs and issues
 * - Monitor repository events
 * - Trigger GitHub Actions
 */

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { Octokit } from '@octokit/rest';
import dotenv from 'dotenv';

dotenv.config();

// Initialize GitHub client
const octokit = new Octokit({
  auth: process.env.GITHUB_TOKEN,
});

// Create MCP server
const server = new Server(
  {
    name: 'github-automation',
    version: '1.0.0',
  },
  {
    capabilities: {
      tools: {},
    },
  }
);

// List available tools
server.setRequestHandler('tools/list', async () => {
  return {
    tools: [
      {
        name: 'github_create_release',
        description: 'Create a GitHub release',
        inputSchema: {
          type: 'object',
          properties: {
            owner: { type: 'string', description: 'Repository owner' },
            repo: { type: 'string', description: 'Repository name' },
            tag_name: { type: 'string', description: 'Tag name (e.g., v1.0.0)' },
            name: { type: 'string', description: 'Release title' },
            body: { type: 'string', description: 'Release notes' },
            draft: { type: 'boolean', description: 'Create as draft' },
            prerelease: { type: 'boolean', description: 'Mark as prerelease' },
          },
          required: ['owner', 'repo', 'tag_name'],
        },
      },
      {
        name: 'github_create_pr',
        description: 'Create a pull request',
        inputSchema: {
          type: 'object',
          properties: {
            owner: { type: 'string' },
            repo: { type: 'string' },
            title: { type: 'string', description: 'PR title' },
            body: { type: 'string', description: 'PR description' },
            head: { type: 'string', description: 'Branch to merge from' },
            base: { type: 'string', description: 'Branch to merge into' },
            draft: { type: 'boolean' },
          },
          required: ['owner', 'repo', 'title', 'head', 'base'],
        },
      },
      {
        name: 'github_create_issue',
        description: 'Create an issue',
        inputSchema: {
          type: 'object',
          properties: {
            owner: { type: 'string' },
            repo: { type: 'string' },
            title: { type: 'string', description: 'Issue title' },
            body: { type: 'string', description: 'Issue description' },
            labels: { type: 'array', items: { type: 'string' } },
            assignees: { type: 'array', items: { type: 'string' } },
          },
          required: ['owner', 'repo', 'title'],
        },
      },
      {
        name: 'github_list_releases',
        description: 'List repository releases',
        inputSchema: {
          type: 'object',
          properties: {
            owner: { type: 'string' },
            repo: { type: 'string' },
            per_page: { type: 'number', description: 'Results per page (max 100)' },
          },
          required: ['owner', 'repo'],
        },
      },
      {
        name: 'github_trigger_workflow',
        description: 'Trigger a GitHub Actions workflow',
        inputSchema: {
          type: 'object',
          properties: {
            owner: { type: 'string' },
            repo: { type: 'string' },
            workflow_id: { type: 'string', description: 'Workflow ID or filename' },
            ref: { type: 'string', description: 'Branch or tag' },
            inputs: { type: 'object', description: 'Workflow inputs' },
          },
          required: ['owner', 'repo', 'workflow_id', 'ref'],
        },
      },
    ],
  };
});

// Handle tool calls
server.setRequestHandler('tools/call', async (request) => {
  const { name, arguments: args } = request.params;

  try {
    switch (name) {
      case 'github_create_release':
        return await handleCreateRelease(args);
      case 'github_create_pr':
        return await handleCreatePR(args);
      case 'github_create_issue':
        return await handleCreateIssue(args);
      case 'github_list_releases':
        return await handleListReleases(args);
      case 'github_trigger_workflow':
        return await handleTriggerWorkflow(args);
      default:
        throw new Error(`Unknown tool: ${name}`);
    }
  } catch (error) {
    return {
      content: [
        {
          type: 'text',
          text: `Error: ${error.message}`,
        },
      ],
      isError: true,
    };
  }
});

// Handle: Create release
async function handleCreateRelease(args) {
  const { owner, repo, tag_name, name, body, draft = false, prerelease = false } = args;

  const release = await octokit.repos.createRelease({
    owner,
    repo,
    tag_name,
    name: name || tag_name,
    body: body || '',
    draft,
    prerelease,
  });

  return {
    content: [
      {
        type: 'text',
        text: JSON.stringify({
          success: true,
          release_id: release.data.id,
          url: release.data.html_url,
          tag: release.data.tag_name,
          message: 'Release created successfully',
        }, null, 2),
      },
    ],
  };
}

// Handle: Create PR
async function handleCreatePR(args) {
  const { owner, repo, title, body, head, base, draft = false } = args;

  const pr = await octokit.pulls.create({
    owner,
    repo,
    title,
    body: body || '',
    head,
    base,
    draft,
  });

  return {
    content: [
      {
        type: 'text',
        text: JSON.stringify({
          success: true,
          pr_number: pr.data.number,
          url: pr.data.html_url,
          message: 'Pull request created successfully',
        }, null, 2),
      },
    ],
  };
}

// Handle: Create issue
async function handleCreateIssue(args) {
  const { owner, repo, title, body, labels, assignees } = args;

  const issue = await octokit.issues.create({
    owner,
    repo,
    title,
    body: body || '',
    labels,
    assignees,
  });

  return {
    content: [
      {
        type: 'text',
        text: JSON.stringify({
          success: true,
          issue_number: issue.data.number,
          url: issue.data.html_url,
          message: 'Issue created successfully',
        }, null, 2),
      },
    ],
  };
}

// Handle: List releases
async function handleListReleases(args) {
  const { owner, repo, per_page = 10 } = args;

  const releases = await octokit.repos.listReleases({
    owner,
    repo,
    per_page,
  });

  return {
    content: [
      {
        type: 'text',
        text: JSON.stringify({
          success: true,
          count: releases.data.length,
          releases: releases.data.map(r => ({
            id: r.id,
            tag: r.tag_name,
            name: r.name,
            url: r.html_url,
            created_at: r.created_at,
            draft: r.draft,
            prerelease: r.prerelease,
          })),
        }, null, 2),
      },
    ],
  };
}

// Handle: Trigger workflow
async function handleTriggerWorkflow(args) {
  const { owner, repo, workflow_id, ref, inputs = {} } = args;

  await octokit.actions.createWorkflowDispatch({
    owner,
    repo,
    workflow_id,
    ref,
    inputs,
  });

  return {
    content: [
      {
        type: 'text',
        text: JSON.stringify({
          success: true,
          message: `Workflow ${workflow_id} triggered on ${ref}`,
        }, null, 2),
      },
    ],
  };
}

// Start server
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error('GitHub Automation MCP server running on stdio');
}

main().catch((error) => {
  console.error('Server error:', error);
  process.exit(1);
});
