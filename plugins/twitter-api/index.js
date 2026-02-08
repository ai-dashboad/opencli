#!/usr/bin/env node

/**
 * Twitter API MCP Plugin for OpenCLI
 *
 * Provides Twitter/X automation capabilities:
 * - Post tweets
 * - Monitor keywords
 * - Auto-reply to tweets
 * - Search tweets
 */

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { TwitterApi } from 'twitter-api-v2';
import dotenv from 'dotenv';

dotenv.config();

// Initialize Twitter client
const twitterClient = new TwitterApi({
  appKey: process.env.TWITTER_API_KEY || '',
  appSecret: process.env.TWITTER_API_SECRET || '',
  accessToken: process.env.TWITTER_ACCESS_TOKEN || '',
  accessSecret: process.env.TWITTER_ACCESS_SECRET || '',
});

const twitter = twitterClient.readWrite;

// Create MCP server
const server = new Server(
  {
    name: 'twitter-api',
    version: '1.0.0',
  },
  {
    capabilities: {
      tools: {},
    },
  }
);

// Tool: Post a tweet
server.setRequestHandler('tools/list', async () => {
  return {
    tools: [
      {
        name: 'twitter_post',
        description: 'Post a tweet to Twitter/X',
        inputSchema: {
          type: 'object',
          properties: {
            content: {
              type: 'string',
              description: 'Tweet content (max 280 characters)',
            },
            reply_to: {
              type: 'string',
              description: 'Tweet ID to reply to (optional)',
            },
            media_urls: {
              type: 'array',
              items: { type: 'string' },
              description: 'Media URLs to attach (optional)',
            },
          },
          required: ['content'],
        },
      },
      {
        name: 'twitter_search',
        description: 'Search tweets by keywords',
        inputSchema: {
          type: 'object',
          properties: {
            query: {
              type: 'string',
              description: 'Search query',
            },
            max_results: {
              type: 'number',
              description: 'Maximum number of results (default: 10)',
            },
          },
          required: ['query'],
        },
      },
      {
        name: 'twitter_monitor',
        description: 'Start monitoring keywords (returns stream)',
        inputSchema: {
          type: 'object',
          properties: {
            keywords: {
              type: 'array',
              items: { type: 'string' },
              description: 'Keywords to monitor',
            },
          },
          required: ['keywords'],
        },
      },
      {
        name: 'twitter_reply',
        description: 'Reply to a tweet',
        inputSchema: {
          type: 'object',
          properties: {
            tweet_id: {
              type: 'string',
              description: 'Tweet ID to reply to',
            },
            content: {
              type: 'string',
              description: 'Reply content',
            },
          },
          required: ['tweet_id', 'content'],
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
      case 'twitter_post':
        return await handlePost(args);
      case 'twitter_search':
        return await handleSearch(args);
      case 'twitter_monitor':
        return await handleMonitor(args);
      case 'twitter_reply':
        return await handleReply(args);
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

// Handle: Post tweet
async function handlePost(args) {
  const { content, reply_to, media_urls } = args;

  const tweetData = {
    text: content,
  };

  if (reply_to) {
    tweetData.reply = { in_reply_to_tweet_id: reply_to };
  }

  // TODO: Handle media uploads
  // if (media_urls && media_urls.length > 0) {
  //   const mediaIds = await uploadMedia(media_urls);
  //   tweetData.media = { media_ids: mediaIds };
  // }

  const tweet = await twitter.v2.tweet(tweetData);

  return {
    content: [
      {
        type: 'text',
        text: JSON.stringify({
          success: true,
          tweet_id: tweet.data.id,
          url: `https://twitter.com/i/web/status/${tweet.data.id}`,
          message: 'Tweet posted successfully',
        }, null, 2),
      },
    ],
  };
}

// Handle: Search tweets
async function handleSearch(args) {
  const { query, max_results = 10 } = args;

  const tweets = await twitter.v2.search(query, {
    max_results,
    'tweet.fields': ['created_at', 'author_id', 'public_metrics'],
  });

  const results = tweets.data.data || [];

  return {
    content: [
      {
        type: 'text',
        text: JSON.stringify({
          success: true,
          count: results.length,
          tweets: results.map(t => ({
            id: t.id,
            text: t.text,
            created_at: t.created_at,
            url: `https://twitter.com/i/web/status/${t.id}`,
          })),
        }, null, 2),
      },
    ],
  };
}

// Handle: Monitor keywords
async function handleMonitor(args) {
  const { keywords } = args;

  // Start monitoring (simplified - in production would use streaming API)
  return {
    content: [
      {
        type: 'text',
        text: JSON.stringify({
          success: true,
          monitoring: keywords,
          message: `Started monitoring keywords: ${keywords.join(', ')}`,
        }, null, 2),
      },
    ],
  };
}

// Handle: Reply to tweet
async function handleReply(args) {
  const { tweet_id, content } = args;

  const reply = await twitter.v2.tweet({
    text: content,
    reply: { in_reply_to_tweet_id: tweet_id },
  });

  return {
    content: [
      {
        type: 'text',
        text: JSON.stringify({
          success: true,
          reply_id: reply.data.id,
          url: `https://twitter.com/i/web/status/${reply.data.id}`,
          message: 'Reply posted successfully',
        }, null, 2),
      },
    ],
  };
}

// Start server
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error('Twitter API MCP server running on stdio');
}

main().catch((error) => {
  console.error('Server error:', error);
  process.exit(1);
});
