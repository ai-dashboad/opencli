import express from 'express';
import cors from 'cors';
import { Octokit } from '@octokit/rest';
import crypto from 'crypto';

const app = express();
const PORT = process.env.PORT || 3000;

// Configuration
const GITHUB_TOKEN = process.env.GITHUB_TOKEN;
const GITHUB_OWNER = process.env.GITHUB_OWNER || 'ai-dashboad';
const GITHUB_REPO = process.env.GITHUB_REPO || 'opencli';

if (!GITHUB_TOKEN) {
  console.warn('⚠️ GITHUB_TOKEN not set — issue creation disabled');
}

const octokit = GITHUB_TOKEN ? new Octokit({ auth: GITHUB_TOKEN }) : null;

// Middleware
app.use(cors());
app.use(express.json({ limit: '10mb' }));

// In-memory cache for duplicate detection (in production, use Redis)
const recentIssues = new Map();
const CACHE_TTL = 3600000; // 1 hour

// Clean cache periodically
setInterval(() => {
  const now = Date.now();
  for (const [key, value] of recentIssues.entries()) {
    if (now - value.timestamp > CACHE_TTL) {
      recentIssues.delete(key);
    }
  }
}, 300000); // Clean every 5 minutes

/**
 * Health check endpoint
 */
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

/**
 * Report telemetry endpoint
 */
app.post('/api/telemetry/report', async (req, res) => {
  try {
    const { error, system_info, device_id, timestamp } = req.body;

    if (!error || !error.message) {
      return res.status(400).json({ error: 'Missing error information' });
    }

    // Generate issue hash for deduplication
    const issueHash = generateIssueHash(error.message, error.stack);

    // Check if similar issue was recently reported
    if (recentIssues.has(issueHash)) {
      const existing = recentIssues.get(issueHash);
      console.log(`📝 Duplicate issue detected: #${existing.issueNumber}`);

      // Add comment to existing issue
      await addDeviceComment(existing.issueNumber, device_id, system_info);

      return res.json({
        status: 'duplicate',
        issueNumber: existing.issueNumber,
        message: 'Added to existing issue'
      });
    }

    // Create new GitHub issue
    if (!octokit) {
      return res.status(503).json({ error: 'GitHub integration not configured' });
    }
    const issueNumber = await createGitHubIssue(error, system_info, device_id, timestamp);

    // Cache the issue
    recentIssues.set(issueHash, {
      issueNumber,
      timestamp: Date.now()
    });

    console.log(`✓ Created issue #${issueNumber}`);

    res.json({
      status: 'created',
      issueNumber,
      message: 'Issue created successfully'
    });

  } catch (err) {
    console.error('❌ Error processing telemetry:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * Generate hash for issue deduplication
 */
function generateIssueHash(message, stack) {
  const content = `${message}${stack || ''}`;
  return crypto.createHash('sha256').update(content).digest('hex').substring(0, 16);
}

/**
 * Create GitHub issue
 */
async function createGitHubIssue(error, systemInfo, deviceId, timestamp) {
  const title = `[Auto] ${error.message}`;

  const body = `
## Error Report

**Message:** ${error.message}

**Severity:** ${error.severity || 'unknown'}

**Device ID:** \`${deviceId || 'unknown'}\`

**Timestamp:** ${timestamp || new Date().toISOString()}

### Stack Trace

\`\`\`
${error.stack || 'No stack trace available'}
\`\`\`

### System Information

- **Platform:** ${systemInfo?.platform || 'unknown'}
- **OS Version:** ${systemInfo?.osVersion || 'unknown'}
- **App Version:** ${systemInfo?.appVersion || 'unknown'}
- **Dart Version:** ${systemInfo?.dartVersion || 'unknown'}

### Context

${error.context ? '```json\n' + JSON.stringify(error.context, null, 2) + '\n```' : 'No context available'}

---
*This issue was automatically created by OpenCLI telemetry system.*
`;

  const response = await octokit.issues.create({
    owner: GITHUB_OWNER,
    repo: GITHUB_REPO,
    title,
    body,
    labels: ['auto-reported', 'bug', 'needs-triage']
  });

  return response.data.number;
}

/**
 * Add device comment to existing issue
 */
async function addDeviceComment(issueNumber, deviceId, systemInfo) {
  const comment = `
### Additional Report

**Device ID:** \`${deviceId || 'unknown'}\`
**Platform:** ${systemInfo?.platform || 'unknown'}
**Timestamp:** ${new Date().toISOString()}

Same error reported from another device.
`;

  await octokit.issues.createComment({
    owner: GITHUB_OWNER,
    repo: GITHUB_REPO,
    issue_number: issueNumber,
    body: comment
  });
}

// Start server
app.listen(PORT, () => {
  console.log(`✓ Telemetry API listening on port ${PORT}`);
  console.log(`  GitHub: ${GITHUB_OWNER}/${GITHUB_REPO}`);
  console.log(`  Health: http://localhost:${PORT}/health`);
});
