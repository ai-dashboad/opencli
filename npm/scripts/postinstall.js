#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const https = require('https');
const { execSync } = require('child_process');

const PACKAGE_JSON = require('../package.json');
const VERSION = PACKAGE_JSON.version;

// Determine platform and architecture
const PLATFORM = process.platform;
const ARCH = process.arch;

// Binary name mapping
const BINARY_MAP = {
  'darwin-arm64': 'opencli-macos-arm64',
  'darwin-x64': 'opencli-macos-x86_64',
  'linux-x64': 'opencli-linux-x86_64',
  'linux-arm64': 'opencli-linux-arm64',
  'win32-x64': 'opencli-windows-x86_64.exe',
};

const platformKey = `${PLATFORM}-${ARCH}`;
const binaryName = BINARY_MAP[platformKey];

if (!binaryName) {
  console.error(`❌ Unsupported platform: ${platformKey}`);
  console.error(`   Supported platforms: ${Object.keys(BINARY_MAP).join(', ')}`);
  process.exit(1);
}

console.log(`\n📦 Installing OpenCLI v${VERSION} for ${platformKey}...\n`);

// GitHub release URL
const REPO = 'opencli/opencli'; // Update with actual repo
const DOWNLOAD_URL = `https://github.com/${REPO}/releases/download/v${VERSION}/${binaryName}`;

// Cache directory
const HOME_DIR = process.env.HOME || process.env.USERPROFILE;
const CACHE_DIR = path.join(HOME_DIR, '.opencli', 'bin');
const CACHED_BINARY = path.join(CACHE_DIR, binaryName);

// Install directory (npm bin)
const BIN_DIR = path.join(__dirname, '..', 'bin');
const INSTALLED_BINARY = path.join(BIN_DIR, PLATFORM === 'win32' ? 'opencli.exe' : 'opencli');

// Ensure directories exist
if (!fs.existsSync(CACHE_DIR)) {
  fs.mkdirSync(CACHE_DIR, { recursive: true });
}

if (!fs.existsSync(BIN_DIR)) {
  fs.mkdirSync(BIN_DIR, { recursive: true });
}

/**
 * Download file from URL
 */
function downloadFile(url, dest) {
  return new Promise((resolve, reject) => {
    console.log(`⬇️  Downloading from: ${url}`);

    const file = fs.createWriteStream(dest);
    let downloadedBytes = 0;
    let totalBytes = 0;

    const request = https.get(url, (response) => {
      // Handle redirects
      if (response.statusCode === 302 || response.statusCode === 301) {
        const redirectUrl = response.headers.location;
        console.log(`   Redirecting to: ${redirectUrl}`);
        file.close();
        fs.unlinkSync(dest);
        return downloadFile(redirectUrl, dest).then(resolve).catch(reject);
      }

      if (response.statusCode !== 200) {
        reject(new Error(`Download failed with status ${response.statusCode}`));
        return;
      }

      totalBytes = parseInt(response.headers['content-length'], 10);

      response.on('data', (chunk) => {
        downloadedBytes += chunk.length;
        const percent = ((downloadedBytes / totalBytes) * 100).toFixed(1);
        process.stdout.write(`\r   Progress: ${percent}% (${formatBytes(downloadedBytes)} / ${formatBytes(totalBytes)})`);
      });

      response.pipe(file);

      file.on('finish', () => {
        file.close();
        console.log('\n✅ Download completed');
        resolve();
      });
    });

    request.on('error', (err) => {
      fs.unlinkSync(dest);
      reject(err);
    });

    file.on('error', (err) => {
      fs.unlinkSync(dest);
      reject(err);
    });
  });
}

/**
 * Format bytes for display
 */
function formatBytes(bytes) {
  if (bytes < 1024) return bytes + ' B';
  if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
  return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
}

/**
 * Make file executable
 */
function makeExecutable(filePath) {
  if (PLATFORM !== 'win32') {
    fs.chmodSync(filePath, 0o755);
    console.log(`✅ Made executable: ${filePath}`);
  }
}

/**
 * Main installation logic
 */
async function install() {
  try {
    // Check if already cached
    if (fs.existsSync(CACHED_BINARY)) {
      console.log(`✅ Using cached binary: ${CACHED_BINARY}`);
    } else {
      // Download to cache
      console.log(`📥 Downloading binary to cache...`);
      await downloadFile(DOWNLOAD_URL, CACHED_BINARY);
      makeExecutable(CACHED_BINARY);
    }

    // Copy from cache to bin directory
    console.log(`📋 Installing binary...`);
    fs.copyFileSync(CACHED_BINARY, INSTALLED_BINARY);
    makeExecutable(INSTALLED_BINARY);

    console.log(`\n✅ OpenCLI v${VERSION} installed successfully!\n`);
    console.log(`Usage:`);
    console.log(`  opencli --help`);
    console.log(`  opencli daemon start`);
    console.log(`  opencli task submit "Your task here"\n`);
    console.log(`Documentation: https://docs.opencli.ai\n`);

    // Verify installation
    try {
      const output = execSync(`"${INSTALLED_BINARY}" --version`, { encoding: 'utf-8' });
      console.log(`Installed version: ${output.trim()}`);
    } catch (e) {
      console.warn('⚠️  Could not verify installation');
    }

  } catch (error) {
    console.error(`\n❌ Installation failed: ${error.message}\n`);
    console.error(`Please try manual installation:`);
    console.error(`  1. Download from: https://github.com/${REPO}/releases/latest`);
    console.error(`  2. Extract and move to your PATH\n`);
    process.exit(1);
  }
}

// Run installation
install();
