#!/usr/bin/env node

/**
 * OpenCLI Plugin Generator
 *
 * Interactive CLI tool to create new MCP plugins from templates.
 *
 * Usage:
 *   node scripts/create-plugin.js
 *   npm run create-plugin
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import readline from 'readline';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const PROJECT_ROOT = path.join(__dirname, '..');

// Colors for terminal output
const colors = {
  reset: '\x1b[0m',
  bright: '\x1b[1m',
  green: '\x1b[32m',
  blue: '\x1b[34m',
  yellow: '\x1b[33m',
  cyan: '\x1b[36m',
  red: '\x1b[31m',
};

function colorize(text, color) {
  return `${colors[color]}${text}${colors.reset}`;
}

// Available templates
const TEMPLATES = {
  'api-wrapper': {
    name: 'API Wrapper',
    description: 'Template for wrapping external REST APIs',
    icon: '🌐',
  },
  'database': {
    name: 'Database',
    description: 'Template for database integrations',
    icon: '🗄️',
  },
  'basic': {
    name: 'Basic',
    description: 'Minimal template to start from scratch',
    icon: '🎯',
  },
};

// Create readline interface
const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
});

function question(query) {
  return new Promise((resolve) => rl.question(query, resolve));
}

async function main() {
  console.log('\n' + colorize('╔═══════════════════════════════════════════╗', 'cyan'));
  console.log(colorize('║   🔌 OpenCLI Plugin Generator            ║', 'cyan'));
  console.log(colorize('╚═══════════════════════════════════════════╝', 'cyan') + '\n');

  // Step 1: Choose template
  console.log(colorize('📋 Available Templates:\n', 'bright'));
  Object.entries(TEMPLATES).forEach(([key, template], index) => {
    console.log(`  ${index + 1}. ${template.icon} ${colorize(template.name, 'green')}`);
    console.log(`     ${colorize(template.description, 'reset')}\n`);
  });

  const templateChoice = await question(colorize('Select template (1-3): ', 'yellow'));
  const templateKeys = Object.keys(TEMPLATES);
  const selectedTemplateKey = templateKeys[parseInt(templateChoice) - 1];

  if (!selectedTemplateKey) {
    console.log(colorize('\n❌ Invalid template selection', 'red'));
    rl.close();
    return;
  }

  const selectedTemplate = TEMPLATES[selectedTemplateKey];
  console.log(colorize(`\n✅ Selected: ${selectedTemplate.name}\n`, 'green'));

  // Step 2: Plugin name
  const pluginName = await question(colorize('Plugin name (e.g., weather-api): ', 'yellow'));

  if (!pluginName || !/^[a-z0-9-]+$/.test(pluginName)) {
    console.log(colorize('\n❌ Invalid plugin name. Use lowercase letters, numbers, and hyphens only.', 'red'));
    rl.close();
    return;
  }

  // Step 3: Plugin description
  const description = await question(colorize('Description: ', 'yellow'));

  // Step 4: Author name
  const author = await question(colorize('Author name: ', 'yellow'));

  // Step 5: Confirm
  console.log(colorize('\n📝 Plugin Configuration:', 'bright'));
  console.log(`   Template:    ${selectedTemplate.name}`);
  console.log(`   Name:        ${pluginName}`);
  console.log(`   Description: ${description}`);
  console.log(`   Author:      ${author}`);

  const confirm = await question(colorize('\nCreate plugin? (y/n): ', 'yellow'));

  if (confirm.toLowerCase() !== 'y') {
    console.log(colorize('\n❌ Cancelled', 'red'));
    rl.close();
    return;
  }

  // Step 6: Create plugin
  try {
    await createPlugin({
      template: selectedTemplateKey,
      name: pluginName,
      description,
      author,
    });

    console.log(colorize('\n✨ Plugin created successfully!\n', 'green'));
    console.log(colorize('Next steps:', 'bright'));
    console.log(`  1. cd plugins/${pluginName}`);
    console.log(`  2. npm install`);
    console.log(`  3. Edit index.js and customize your tools`);
    console.log(`  4. npm start\n`);

    console.log(colorize('📚 Documentation:', 'bright'));
    console.log(`  - README: plugins/${pluginName}/README.md`);
    console.log(`  - Templates Guide: plugins/templates/README.md\n`);

  } catch (error) {
    console.log(colorize(`\n❌ Error creating plugin: ${error.message}`, 'red'));
  }

  rl.close();
}

async function createPlugin({ template, name, description, author }) {
  const templatePath = path.join(PROJECT_ROOT, 'plugins', 'templates', template);
  const targetPath = path.join(PROJECT_ROOT, 'plugins', name);

  // Check if target already exists
  if (fs.existsSync(targetPath)) {
    throw new Error(`Plugin directory already exists: plugins/${name}`);
  }

  // Create plugin directory
  fs.mkdirSync(targetPath, { recursive: true });

  // Copy template files
  const files = fs.readdirSync(templatePath);

  for (const file of files) {
    const sourcePath = path.join(templatePath, file);
    const destPath = path.join(targetPath, file);

    let content = fs.readFileSync(sourcePath, 'utf8');

    // Replace placeholders
    content = content
      .replace(/@opencli\/my-\w+-plugin/g, `@opencli/${name}`)
      .replace(/my-\w+-plugin/g, name)
      .replace(/MCP plugin for OpenCLI/g, description || 'MCP plugin for OpenCLI')
      .replace(/Your Name/g, author || 'OpenCLI Developer')
      .replace(/my_plugin/g, name.replace(/-/g, '_'));

    fs.writeFileSync(destPath, content);
  }

  // Create .gitignore
  fs.writeFileSync(
    path.join(targetPath, '.gitignore'),
    'node_modules/\n.env\n*.log\n.DS_Store\n'
  );

  console.log(colorize(`\n📁 Created files in plugins/${name}/`, 'cyan'));
  files.forEach(file => {
    console.log(`   ✓ ${file}`);
  });
  console.log(`   ✓ .gitignore`);
}

// Handle errors
process.on('unhandledRejection', (error) => {
  console.error(colorize(`\n❌ Error: ${error.message}`, 'red'));
  process.exit(1);
});

// Run the generator
main().catch(console.error);
