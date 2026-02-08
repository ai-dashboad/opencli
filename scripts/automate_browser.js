#!/usr/bin/env node
/**
 * Browser Automation Script for Google Play Submission
 *
 * Requirements:
 * - Node.js installed
 * - Run: npm install playwright
 *
 * Usage:
 * - node scripts/automate_browser.js github-pages
 * - node scripts/automate_browser.js data-safety
 * - node scripts/automate_browser.js upload
 */

const { chromium } = require('playwright');

const GITHUB_PAGES_URL = 'https://github.com/ai-dashboad/opencli/settings/pages';
const DATA_SAFETY_URL = 'https://play.google.com/console/u/0/developers/6298343753806217215/policy-center';
const PRIVACY_URL = 'https://ai-dashboad.github.io/opencli/privacy.html';

async function setupGitHubPages() {
  console.log('🚀 Setting up GitHub Pages...');
  const browser = await chromium.launch({ headless: false });
  const context = await browser.newContext();
  const page = await context.newPage();

  try {
    await page.goto(GITHUB_PAGES_URL);

    // Wait for login if needed
    await page.waitForSelector('select[name="source"], input[type="password"]', { timeout: 60000 });

    // Check if already logged in
    const passwordField = await page.$('input[type="password"]');
    if (passwordField) {
      console.log('⚠️  Please log in to GitHub manually...');
      await page.waitForSelector('select[name="source"]', { timeout: 300000 });
    }

    console.log('✓ Logged in to GitHub');

    // Select "Deploy from a branch"
    await page.selectOption('select[name="source"]', { label: 'Deploy from a branch' });
    console.log('✓ Selected deployment source');

    // Wait a moment for the branch selector to appear
    await page.waitForTimeout(1000);

    // Select branch and folder
    await page.selectOption('select#settings-pages-branch', 'main');
    console.log('✓ Selected main branch');

    await page.selectOption('select#settings-pages-directory', '/docs');
    console.log('✓ Selected /docs folder');

    // Click Save
    await page.click('button:has-text("Save")');
    console.log('✓ Saved settings');

    // Wait for confirmation
    await page.waitForSelector('text=/Your site is (published|live)/i', { timeout: 30000 });
    console.log('✅ GitHub Pages enabled successfully!');

    // Verify privacy policy
    console.log('🔍 Verifying privacy policy...');
    await page.goto(PRIVACY_URL);
    await page.waitForSelector('text=Privacy Policy', { timeout: 10000 });
    console.log('✅ Privacy policy is accessible!');

  } catch (error) {
    console.error('❌ Error:', error.message);
    throw error;
  } finally {
    await browser.close();
  }
}

async function fillDataSafety() {
  console.log('🚀 Filling Data Safety form...');
  const browser = await chromium.launch({ headless: false });
  const context = await browser.newContext();
  const page = await context.newPage();

  try {
    await page.goto(DATA_SAFETY_URL);

    console.log('⚠️  Please log in to Google Play Console manually...');
    console.log('⚠️  Navigate to: App content → Data safety');
    console.log('⚠️  Then press Enter to continue...');

    // Wait for user to navigate manually
    await new Promise(resolve => {
      process.stdin.once('data', () => resolve());
    });

    console.log('📝 Starting form automation...');

    // Question 1: Does your app collect or share user data?
    await page.click('input[value="yes"]');
    await page.click('button:has-text("Next")');
    console.log('✓ Question 1 completed');

    // Question 2: Data types
    await page.click('input[aria-label*="Device"]');
    await page.click('input[aria-label*="Audio"]');
    await page.click('input[aria-label*="performance"]');
    await page.click('button:has-text("Next")');
    console.log('✓ Question 2 completed');

    // Device ID details
    await page.click('input[value="collected"]');
    await page.click('input[value="required"]');
    await page.click('input[aria-label*="functionality"]');
    await page.click('button:has-text("Next")');
    console.log('✓ Device ID details completed');

    // Audio details
    await page.click('input[value="ephemeral"]');
    await page.click('input[value="optional"]');
    await page.click('button:has-text("Next")');
    console.log('✓ Audio details completed');

    // Security practices
    await page.click('input[value="encrypted"]');
    await page.click('input[value="user-deletion"]');
    await page.click('button:has-text("Next")');
    console.log('✓ Security practices completed');

    // Privacy policy
    await page.fill('input[name*="privacy"]', PRIVACY_URL);
    await page.click('button:has-text("Submit")');
    console.log('✅ Data Safety form submitted!');

  } catch (error) {
    console.error('❌ Error:', error.message);
    console.log('💡 Tip: Complete the form manually using docs/DATA_SAFETY_DECLARATION.md');
    throw error;
  } finally {
    await browser.close();
  }
}

async function uploadRelease() {
  console.log('🚀 Uploading release...');
  const browser = await chromium.launch({ headless: false });
  const context = await browser.newContext();
  const page = await context.newPage();

  const AAB_PATH = '/Users/cw/development/opencli/opencli_mobile/build/app/outputs/bundle/release/app-release.aab';
  const RELEASE_NOTES = `v0.2.1 - Policy Compliance & Security Update

✨ What's New
• Enhanced privacy protection with comprehensive policy
• Improved microphone permission handling
• Better security compliance

🔧 Bug Fixes
• Fixed permission request flow
• Resolved policy compliance issues
• Updated app localization to English

🔒 Security & Privacy
• End-to-end encryption
• Local data processing
• Transparent data practices`;

  try {
    await page.goto('https://play.google.com/console');

    console.log('⚠️  Please log in and navigate to Production track manually');
    console.log('⚠️  Then press Enter to continue...');

    await new Promise(resolve => {
      process.stdin.once('data', () => resolve());
    });

    console.log('📝 Creating release...');

    // Click Create new release
    await page.click('button:has-text("Create new release")');
    console.log('✓ Creating new release');

    // Upload AAB
    const fileInput = await page.locator('input[type="file"]');
    await fileInput.setInputFiles(AAB_PATH);
    console.log('✓ Uploading AAB...');

    // Wait for upload
    await page.waitForSelector('text=app-release.aab', { timeout: 120000 });
    console.log('✓ AAB uploaded successfully');

    // Fill release notes
    await page.fill('textarea[aria-label*="Release notes"]', RELEASE_NOTES);
    console.log('✓ Release notes added');

    // Review
    await page.click('button:has-text("Review release")');
    console.log('✓ Reviewing release');

    console.log('');
    console.log('⚠️  Please review the release details');
    console.log('⚠️  Then click "Start rollout to production"');
    console.log('⚠️  Press Enter when done...');

    await new Promise(resolve => {
      process.stdin.once('data', () => resolve());
    });

    console.log('✅ Release submitted!');

  } catch (error) {
    console.error('❌ Error:', error.message);
    throw error;
  } finally {
    await browser.close();
  }
}

// Main execution
const command = process.argv[2];

(async () => {
  try {
    switch (command) {
      case 'github-pages':
        await setupGitHubPages();
        break;
      case 'data-safety':
        await fillDataSafety();
        break;
      case 'upload':
        await uploadRelease();
        break;
      case 'all':
        console.log('🎯 Running full automation...\n');
        await setupGitHubPages();
        console.log('\n---\n');
        await fillDataSafety();
        console.log('\n---\n');
        await uploadRelease();
        break;
      default:
        console.log('Usage:');
        console.log('  node automate_browser.js github-pages   # Enable GitHub Pages');
        console.log('  node automate_browser.js data-safety    # Fill Data Safety form');
        console.log('  node automate_browser.js upload         # Upload release');
        console.log('  node automate_browser.js all            # Run all steps');
        process.exit(1);
    }

    console.log('\n✅ Automation completed successfully!');
  } catch (error) {
    console.error('\n❌ Automation failed:', error.message);
    process.exit(1);
  }
})();
