/**
 * @opencli/cli - Universal AI Development Platform
 *
 * This package provides the OpenCLI command-line interface with
 * platform-specific native binaries.
 *
 * The binary is automatically downloaded during installation based on
 * your platform (macOS, Linux, Windows) and architecture (x64, arm64).
 *
 * Usage:
 *   const opencli = require('@opencli/cli');
 *   // Or use the CLI directly: npx opencli --help
 */

const { execSync } = require('child_process');
const path = require('path');

const PLATFORM = process.platform;
const binaryName = PLATFORM === 'win32' ? 'opencli.exe' : 'opencli';
const binaryPath = path.join(__dirname, 'bin', binaryName);

module.exports = {
  /**
   * Get the path to the OpenCLI binary
   */
  getBinaryPath() {
    return binaryPath;
  },

  /**
   * Execute OpenCLI command
   * @param {string[]} args - Command arguments
   * @param {object} options - exec options
   * @returns {Buffer} - Command output
   */
  exec(args = [], options = {}) {
    const cmd = `"${binaryPath}" ${args.join(' ')}`;
    return execSync(cmd, {
      encoding: 'utf-8',
      ...options
    });
  },

  /**
   * Get OpenCLI version
   * @returns {string} - Version string
   */
  version() {
    try {
      return this.exec(['--version']).trim();
    } catch (e) {
      throw new Error('Failed to get OpenCLI version');
    }
  }
};
