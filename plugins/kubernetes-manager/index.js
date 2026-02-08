#!/usr/bin/env node

/**
 * Kubernetes Manager MCP Server
 *
 * Provides tools for Kubernetes cluster management:
 * - List pods, services, deployments
 * - Get pod logs
 * - Scale deployments
 * - Apply manifests
 */

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { CallToolRequestSchema, ListToolsRequestSchema } from '@modelcontextprotocol/sdk/types.js';
import k8s from '@kubernetes/client-node';
import dotenv from 'dotenv';

dotenv.config();

const TOOLS = [
  {
    name: 'k8s_list_pods',
    description: 'List pods in a namespace',
    inputSchema: {
      type: 'object',
      properties: {
        namespace: { type: 'string', description: 'Kubernetes namespace (default: default)' }
      }
    }
  },
  {
    name: 'k8s_get_pod_logs',
    description: 'Get logs from a pod',
    inputSchema: {
      type: 'object',
      properties: {
        pod: { type: 'string', description: 'Pod name' },
        namespace: { type: 'string', description: 'Namespace (default: default)' },
        tail: { type: 'number', description: 'Number of lines to tail' }
      },
      required: ['pod']
    }
  },
  {
    name: 'k8s_list_deployments',
    description: 'List deployments in a namespace',
    inputSchema: {
      type: 'object',
      properties: {
        namespace: { type: 'string', description: 'Kubernetes namespace (default: default)' }
      }
    }
  },
  {
    name: 'k8s_scale_deployment',
    description: 'Scale a deployment',
    inputSchema: {
      type: 'object',
      properties: {
        deployment: { type: 'string', description: 'Deployment name' },
        replicas: { type: 'number', description: 'Number of replicas' },
        namespace: { type: 'string', description: 'Namespace (default: default)' }
      },
      required: ['deployment', 'replicas']
    }
  }
];

class KubernetesServer {
  constructor() {
    this.kc = new k8s.KubeConfig();
    this.kc.loadFromDefault();
    this.k8sApi = this.kc.makeApiClient(k8s.CoreV1Api);
    this.appsApi = this.kc.makeApiClient(k8s.AppsV1Api);

    this.server = new Server(
      {
        name: 'kubernetes-manager',
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
          case 'k8s_list_pods':
            return await this.handleListPods(args);
          case 'k8s_get_pod_logs':
            return await this.handleGetPodLogs(args);
          case 'k8s_list_deployments':
            return await this.handleListDeployments(args);
          case 'k8s_scale_deployment':
            return await this.handleScaleDeployment(args);
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

  async handleListPods(args) {
    const namespace = args.namespace || 'default';
    const res = await this.k8sApi.listNamespacedPod(namespace);

    const pods = res.body.items.map(pod => ({
      name: pod.metadata.name,
      status: pod.status.phase,
      restarts: pod.status.containerStatuses?.[0]?.restartCount || 0
    }));

    return {
      content: [
        {
          type: 'text',
          text: `Pods in namespace '${namespace}':\n${JSON.stringify(pods, null, 2)}`
        }
      ]
    };
  }

  async handleGetPodLogs(args) {
    const namespace = args.namespace || 'default';
    const pod = args.pod;
    const tail = args.tail || 100;

    const logs = await this.k8sApi.readNamespacedPodLog(
      pod,
      namespace,
      undefined,
      false,
      undefined,
      undefined,
      undefined,
      undefined,
      undefined,
      tail
    );

    return {
      content: [
        {
          type: 'text',
          text: `Logs for pod '${pod}':\n${logs.body}`
        }
      ]
    };
  }

  async handleListDeployments(args) {
    const namespace = args.namespace || 'default';
    const res = await this.appsApi.listNamespacedDeployment(namespace);

    const deployments = res.body.items.map(dep => ({
      name: dep.metadata.name,
      replicas: dep.spec.replicas,
      ready: dep.status.readyReplicas || 0
    }));

    return {
      content: [
        {
          type: 'text',
          text: `Deployments in namespace '${namespace}':\n${JSON.stringify(deployments, null, 2)}`
        }
      ]
    };
  }

  async handleScaleDeployment(args) {
    const namespace = args.namespace || 'default';
    const deployment = args.deployment;
    const replicas = args.replicas;

    await this.appsApi.patchNamespacedDeploymentScale(
      deployment,
      namespace,
      { spec: { replicas } },
      undefined,
      undefined,
      undefined,
      undefined,
      { headers: { 'Content-Type': 'application/merge-patch+json' } }
    );

    return {
      content: [
        {
          type: 'text',
          text: `Scaled deployment '${deployment}' to ${replicas} replicas`
        }
      ]
    };
  }

  async run() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error('Kubernetes Manager MCP server running on stdio');
  }
}

const server = new KubernetesServer();
server.run().catch(console.error);
