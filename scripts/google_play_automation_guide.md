# Google Play Console Automation Guide

This guide provides step-by-step instructions for automating Google Play Console operations using browser automation (Claude Chrome or similar tools).

## Prerequisites

- Google Play Console access
- Built AAB file: `build/app/outputs/bundle/release/app-release.aab`
- Browser automation tool (Claude Chrome, Selenium, Playwright, etc.)

---

## Step 1: Enable GitHub Pages (Web Automation)

**URL**: https://github.com/ai-dashboad/opencli/settings/pages

### Actions:
```javascript
// 1. Navigate to GitHub Pages settings
await page.goto('https://github.com/ai-dashboad/opencli/settings/pages');

// 2. Wait for page load
await page.waitForSelector('select[name="source"]');

// 3. Select "Deploy from a branch"
await page.selectOption('select[name="source"]', 'branch');

// 4. Select branch "main"
await page.selectOption('select[name="branch"]', 'main');

// 5. Select folder "/docs"
await page.selectOption('select[name="path"]', '/docs');

// 6. Click Save
await page.click('button:has-text("Save")');

// 7. Wait for confirmation
await page.waitForSelector('text=Your site is published at');

// 8. Verify URL is accessible
await page.goto('https://ai-dashboad.github.io/opencli/privacy.html');
```

### Manual Verification:
After automation completes, verify:
- [ ] GitHub Pages is enabled
- [ ] Privacy policy is accessible at: https://ai-dashboad.github.io/opencli/privacy.html

---

## Step 2: Fill Data Safety Form (Google Play Console)

**URL**: https://play.google.com/console/developers/6298343753806217215/app/{app_id}/app-content/data-safety

### Automation Script:

```javascript
// Navigate to Data Safety section
await page.goto('https://play.google.com/console/.../data-safety');

// Click "Start" button
await page.click('button:has-text("Start")');

// ===== Question 1: Does your app collect or share user data? =====
await page.click('input[value="yes"]');
await page.click('button:has-text("Next")');

// ===== Question 2: What types of data does your app collect? =====

// Select "Device or other identifiers"
await page.click('input[aria-label="Device or other identifiers"]');

// Select "Audio"
await page.click('input[aria-label="Audio"]');

// Select "App info and performance"
await page.click('input[aria-label="App info and performance"]');

await page.click('button:has-text("Next")');

// ===== Question 3: Device or other identifiers =====
await page.click('input[value="collected"]'); // Collected only
await page.click('input[value="required"]'); // Required
await page.click('input[aria-label="App functionality"]');
await page.click('input[aria-label="Account management"]');
await page.click('button:has-text("Next")');

// ===== Question 4: Audio data =====
await page.click('input[aria-label="Voice or sound recordings"]');
await page.click('input[value="collected"]'); // Collected only
await page.click('input[value="ephemeral"]'); // Processed ephemerally
await page.click('input[value="optional"]'); // Optional
await page.click('input[aria-label="App functionality"]');
await page.click('button:has-text("Next")');

// ===== Question 5: App info and performance =====
await page.click('input[aria-label="Crash logs"]');
await page.click('input[aria-label="Diagnostics"]');
await page.click('input[value="collected"]');
await page.click('input[value="optional"]');
await page.click('input[aria-label="Analytics"]');
await page.click('button:has-text("Next")');

// ===== Question 6: Data security practices =====
await page.click('input[value="encrypted"]'); // Encrypted in transit
await page.click('input[value="user-deletion"]'); // Users can request deletion
await page.click('button:has-text("Next")');

// ===== Question 7: Privacy policy =====
await page.fill('input[name="privacy-policy-url"]', 'https://ai-dashboad.github.io/opencli/privacy.html');
await page.click('button:has-text("Next")');

// Submit the form
await page.click('button:has-text("Submit")');

// Wait for confirmation
await page.waitForSelector('text=Your data safety form has been submitted');
```

### Manual Steps (If automation fails):

Refer to `docs/DATA_SAFETY_DECLARATION.md` for detailed answers to each question.

**Quick Reference**:
- Collect data? → **Yes**
- Device ID? → **Yes** (Required, App functionality + Account management)
- Audio? → **Yes** (Optional, Ephemeral, App functionality)
- Crash logs? → **Yes** (Optional, Analytics)
- Encrypted? → **Yes**
- Data deletion? → **Yes**
- Privacy policy: → `https://ai-dashboad.github.io/opencli/privacy.html`

---

## Step 3: Upload New Release (Google Play Console)

**URL**: https://play.google.com/console/developers/{dev_id}/app/{app_id}/tracks/production

### Automation Script:

```javascript
// Navigate to Production track
await page.goto('https://play.google.com/console/.../tracks/production');

// Click "Create new release"
await page.click('button:has-text("Create new release")');

// Upload AAB file
const fileInput = await page.locator('input[type="file"]');
await fileInput.setInputFiles('/Users/cw/development/opencli/opencli_mobile/build/app/outputs/bundle/release/app-release.aab');

// Wait for upload to complete
await page.waitForSelector('text=app-release.aab', { timeout: 120000 });

// Fill release notes
await page.fill('textarea[aria-label="Release notes - en-US"]', `
v0.2.1 - Policy Compliance & Security Update

✨ What's New
• Enhanced privacy protection with comprehensive policy
• Improved microphone permission handling
• Better security compliance

🔧 Bug Fixes
• Fixed permission request flow
• Resolved policy compliance issues
• Updated app localization to English

🔒 Security & Privacy
• End-to-end encryption for all communications
• Local data processing without cloud storage
• Transparent data collection practices

This update addresses all Google Play policy requirements and improves overall app security.
`);

// Click "Review release"
await page.click('button:has-text("Review release")');

// Review and confirm
await page.click('button:has-text("Start rollout to production")');

// Confirm rollout
await page.click('button:has-text("Rollout")');

// Wait for confirmation
await page.waitForSelector('text=Production rollout has started');
```

### Manual Steps (If automation fails):

1. Go to: **Google Play Console** → **Production** → **Create new release**
2. Upload: `build/app/outputs/bundle/release/app-release.aab`
3. Release notes (copy from above)
4. Click **Review release** → **Start rollout to production**

---

## Verification Checklist

After completing all automation steps:

- [ ] GitHub Pages enabled and privacy policy accessible
- [ ] Data Safety form submitted successfully
- [ ] New release (v0.2.1) uploaded and submitted for review
- [ ] Release notes properly formatted
- [ ] Received email confirmation from Google Play

---

## Expected Timeline

| Stage | Duration |
|-------|----------|
| GitHub Pages activation | 1-2 minutes |
| Data Safety form submission | Instant |
| AAB upload | 5-10 minutes |
| Google review | 1-3 business days |
| App goes live | Immediate after approval |

---

## Troubleshooting

### GitHub Pages not activating
- Check repository settings permissions
- Ensure `/docs` folder exists with `privacy.html`
- Wait 5 minutes and refresh

### Data Safety form errors
- Refer to `docs/DATA_SAFETY_DECLARATION.md` for correct answers
- Ensure privacy policy URL is accessible before submission
- Double-check all checkboxes match the guide

### AAB upload fails
- Verify AAB file size is reasonable (should be ~40-50MB)
- Check signing configuration in `android/app/build.gradle.kts`
- Ensure version code is incremented (should be 8)

---

## Contact for Issues

If automation fails or you encounter errors:
- Review error messages carefully
- Check Google Play Console email notifications
- Refer to `docs/GOOGLE_PLAY_ISSUES.md` for common issues
- Open GitHub issue: https://github.com/ai-dashboad/opencli/issues
