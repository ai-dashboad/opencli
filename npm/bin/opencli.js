#!/usr/bin/env node

const { spawn } = require('child_process');
const path = require('path');

// Determine binary name based on platform
const PLATFORM = process.platform;
const binaryName = PLATFORM === 'win32' ? 'opencli.exe' : 'opencli';
const binaryPath = path.join(__dirname, binaryName);

// Forward all arguments to the binary
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
