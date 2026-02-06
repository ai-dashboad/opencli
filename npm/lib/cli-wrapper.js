const IpcClient = require('./ipc-client');

/**
 * Run CLI command via IPC
 * @param {string[]} args - Command-line arguments
 * @returns {Promise<number>} Exit code (0 for success, 1 for error)
 */
async function runCli(args) {
  // Parse arguments
  const method = args[0] || 'help';
  const params = args.slice(1);

  // Handle special commands
  if (method === '--version' || method === '-v') {
    console.log('opencli 0.2.0 (Node.js wrapper)');
    return 0;
  }

  if (method === '--help' || method === '-h' || method === 'help') {
    console.log(`
OpenCLI - AI-powered task automation

Usage: opencli <method> [params...]

Examples:
  opencli chat "Hello, how are you?"
  opencli system.health
  opencli system.plugins
  opencli flutter.launch --device=macos

Methods:
  chat <message>         - Send a chat message
  system.health          - Check system health
  system.plugins         - List loaded plugins
  system.version         - Show daemon version
  <plugin>.<action>      - Execute plugin action

Options:
  --help, -h            - Show this help message
  --version, -v         - Show version
  --verbose             - Enable verbose output

Environment Variables:
  OPENCLI_VERBOSE       - Enable verbose output
  OPENCLI_TIMEOUT       - Request timeout in milliseconds (default: 30000)

For more information: https://github.com/ai-dashboard/opencli
    `);
    return 0;
  }

  try {
    const client = new IpcClient();

    // Get timeout from environment or use default (5 seconds for fast IPC)
    const timeout = parseInt(process.env.OPENCLI_TIMEOUT || '5000', 10);

    if (process.env.OPENCLI_VERBOSE) {
      console.error(`[Sending request: ${method} with ${params.length} params]`);
    }

    const response = await client.sendRequest(method, params, timeout);

    // Print result
    console.log(response.result);

    // Print timing info if verbose
    if (process.env.OPENCLI_VERBOSE) {
      const durationMs = (response.duration_us / 1000).toFixed(2);
      console.error(`[Completed in ${durationMs}ms]`);
      if (response.cached) {
        console.error('[Result was cached]');
      }
    }

    return 0;
  } catch (error) {
    console.error(`Error: ${error.message}`);

    if (process.env.OPENCLI_VERBOSE) {
      console.error(error.stack);
    }

    return 1;
  }
}

// Export for testing
module.exports = runCli;

// Run if called directly
if (require.main === module) {
  runCli(process.argv.slice(2))
    .then(code => process.exit(code))
    .catch(err => {
      console.error('Fatal error:', err);
      process.exit(1);
    });
}
