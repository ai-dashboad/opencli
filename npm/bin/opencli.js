#!/usr/bin/env node

const { spawn } = require('child_process');
const { existsSync, accessSync, constants } = require('fs');
const path = require('path');

// Determine binary name and path
const PLATFORM = process.platform;
const binaryName = PLATFORM === 'win32' ? 'opencli.exe' : 'opencli';
const binaryPath = path.join(__dirname, binaryName);

/**
 * Check if Rust binary exists and is executable
 * @returns {boolean}
 */
function canUseRustBinary() {
  if (!existsSync(binaryPath)) {
    return false;
  }

  try {
    accessSync(binaryPath, constants.X_OK);
    return true;
  } catch {
    return false;
  }
}

/**
 * Use Rust binary (preferred for performance)
 */
function runRustBinary() {
  const child = spawn(binaryPath, process.argv.slice(2), {
    stdio: 'inherit',
    windowsHide: false
  });

  child.on('exit', (code) => {
    process.exit(code);
  });

  child.on('error', (err) => {
    console.error(`Failed to start OpenCLI: ${err.message}`);
    process.exit(1);
  });
}

/**
 * Use Node.js fallback (when Rust binary unavailable)
 */
function runNodeFallback() {
  if (process.env.OPENCLI_VERBOSE) {
    console.error('[Using Node.js IPC client fallback]');
  }

  const cliWrapper = require('../lib/cli-wrapper');
  cliWrapper(process.argv.slice(2))
    .then(code => process.exit(code))
    .catch(err => {
      console.error('Fatal error:', err);
      process.exit(1);
    });
}

// Main entry point
if (canUseRustBinary()) {
  runRustBinary();
} else {
  runNodeFallback();
}
