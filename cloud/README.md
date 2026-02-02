# OpenCLI Cloud Services - Coolify Deployment

This directory contains all cloud services for OpenCLI that can be deployed to Coolify.

## Services

1. **Capability CDN** (`capability-cdn/`) - Static file server for capability packages
2. **Telemetry API** (`telemetry-api/`) - Error reporting and GitHub issue creation

## Prerequisites

- Coolify instance running at `cicd.dtok.io`
- GitHub Personal Access Token with `repo` permissions
- Domain: `opencli.ai` (or your custom domain)

## Deployment to Coolify

### Option 1: Automatic Deployment (Recommended)

1. **Connect GitHub Repository to Coolify:**
   - Go to Coolify dashboard: https://cicd.dtok.io
   - Click "New Resource" → "Application"
   - Select "GitHub" source
   - Choose repository: `ai-dashboad/opencli`
   - Set branch: `main`

2. **Configure Services:**

   **For Capability CDN:**
   - Name: `opencli-capability-cdn`
   - Build Pack: `Dockerfile`
   - Dockerfile Location: `cloud/capability-cdn/Dockerfile`
   - Port: `80`
   - Domain: `opencli.ai` (or subdomain like `cdn.opencli.ai`)
   - Auto Deploy: ✅ Enabled

   **For Telemetry API:**
   - Name: `opencli-telemetry-api`
   - Build Pack: `Dockerfile`
   - Dockerfile Location: `cloud/telemetry-api/Dockerfile`
   - Port: `3000`
   - Domain: `opencli.ai` (path: `/api/telemetry`)
   - Environment Variables:
     ```
     GITHUB_TOKEN=ghp_your_token_here
     GITHUB_OWNER=ai-dashboad
     GITHUB_REPO=opencli
     PORT=3000
     ```
   - Auto Deploy: ✅ Enabled

3. **Deploy:**
   - Click "Deploy" for each service
   - Coolify will automatically build and deploy

### Option 2: Docker Compose Deployment

1. **Set Environment Variables in Coolify:**
   ```bash
   GITHUB_TOKEN=ghp_your_token_here
   ```

2. **Deploy via Coolify UI:**
   - Go to "New Resource" → "Docker Compose"
   - Paste the content of `docker-compose.yml`
   - Set environment variables
   - Click "Deploy"

### Option 3: Manual Deployment

1. **SSH to Coolify server:**
   ```bash
   ssh user@cicd.dtok.io
   ```

2. **Clone repository:**
   ```bash
   git clone https://github.com/ai-dashboad/opencli.git
   cd opencli/cloud
   ```

3. **Set environment variables:**
   ```bash
   export GITHUB_TOKEN=ghp_your_token_here
   ```

4. **Deploy with Docker Compose:**
   ```bash
   docker-compose up -d
   ```

## Environment Variables

### Required

| Variable | Description | Example |
|----------|-------------|---------|
| `GITHUB_TOKEN` | GitHub PAT with repo access | `ghp_xxxxxxxxxxxx` |

### Optional

| Variable | Description | Default |
|----------|-------------|---------|
| `GITHUB_OWNER` | GitHub repository owner | `ai-dashboad` |
| `GITHUB_REPO` | GitHub repository name | `opencli` |
| `PORT` | Telemetry API port | `3000` |

## How to Get GitHub Token

1. Go to GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Click "Generate new token (classic)"
3. Select scopes:
   - ✅ `repo` (Full control of private repositories)
4. Copy the token (starts with `ghp_`)
5. Add to Coolify environment variables

## Verification

### 1. Check Capability CDN
```bash
# Check health
curl https://opencli.ai/health

# Get manifest
curl https://opencli.ai/api/capabilities/manifest.json

# Download a capability
curl https://opencli.ai/api/capabilities/packages/desktop.open_app.yaml
```

### 2. Check Telemetry API
```bash
# Health check
curl https://opencli.ai/api/telemetry/health

# Test error report
curl -X POST https://opencli.ai/api/telemetry/report \
  -H "Content-Type: application/json" \
  -d '{
    "error": {
      "message": "Test error from deployment",
      "severity": "info",
      "stack": "test stack trace"
    },
    "system_info": {
      "platform": "macos",
      "osVersion": "14.0",
      "appVersion": "0.2.0"
    },
    "device_id": "test-device-123",
    "timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"
  }'
```

After this, check GitHub issues to see if a new issue was created.

## Domain Configuration

### Coolify Routing

Configure in Coolify dashboard:

```
opencli.ai/                        → capability-cdn (/)
opencli.ai/api/capabilities/*      → capability-cdn (/api/capabilities/*)
opencli.ai/api/telemetry/*         → telemetry-api (/api/telemetry/*)
```

### DNS Configuration

Point your domain to Coolify:

```
A    opencli.ai     → your-coolify-server-ip
A    *.opencli.ai   → your-coolify-server-ip
```

Or use Cloudflare proxy for additional security and CDN.

## Monitoring

### Logs

View logs in Coolify dashboard or via Docker:

```bash
# Capability CDN logs
docker logs -f opencli-capability-cdn

# Telemetry API logs
docker logs -f opencli-telemetry-api
```

### Health Checks

Both services have health check endpoints:

- CDN: `https://opencli.ai/health`
- API: `https://opencli.ai/api/telemetry/health`

Set up monitoring in Coolify to check these endpoints regularly.

## Updating Services

### Automatic Updates (via Git push)

If Auto Deploy is enabled in Coolify:
1. Push changes to `main` branch
2. Coolify automatically rebuilds and redeploys

### Manual Update

```bash
# In Coolify dashboard
1. Go to the service
2. Click "Redeploy"
```

Or via CLI:
```bash
cd opencli/cloud
git pull
docker-compose pull
docker-compose up -d
```

## Troubleshooting

### Issue: CDN returns 404

Check if capabilities are properly copied:
```bash
docker exec opencli-capability-cdn ls -la /usr/share/nginx/html/api/capabilities/
```

### Issue: Telemetry API can't create issues

Check GitHub token permissions:
```bash
docker exec opencli-telemetry-api node -e "
const { Octokit } = require('@octokit/rest');
const octokit = new Octokit({ auth: process.env.GITHUB_TOKEN });
octokit.users.getAuthenticated().then(r => console.log('✓ Token valid:', r.data.login));
"
```

### Issue: Container crashes

Check logs:
```bash
docker logs opencli-capability-cdn
docker logs opencli-telemetry-api
```

## Architecture

```
┌─────────────────────────────────────────────┐
│          Coolify (cicd.dtok.io)             │
│                                             │
│  ┌───────────────────────────────────────┐ │
│  │  Nginx Proxy (Traefik)                │ │
│  │  - SSL/TLS termination                │ │
│  │  - Domain routing                     │ │
│  └──────┬──────────────────┬──────────────┘ │
│         │                  │                │
│         ▼                  ▼                │
│  ┌─────────────┐    ┌──────────────────┐   │
│  │ CDN         │    │ Telemetry API    │   │
│  │ (nginx)     │    │ (Node.js)        │   │
│  │ Port: 80    │    │ Port: 3000       │   │
│  └─────────────┘    └────────┬─────────┘   │
│                              │              │
└──────────────────────────────┼──────────────┘
                               │
                               ▼
                        GitHub API
                    (Create Issues)
```

## Cost Estimate

- **Coolify Hosting:** $0 (self-hosted)
- **Bandwidth:** Depends on usage
- **GitHub API:** Free (up to 5000 requests/hour)

Total: ~$0/month for self-hosted setup

## Next Steps

After deployment:
1. Update `daemon/lib/capabilities/capability_loader.dart` to use `https://opencli.ai/api/capabilities`
2. Update `daemon/lib/telemetry/issue_reporter.dart` to use `https://opencli.ai/api/telemetry`
3. Test error reporting from the mobile app
4. Monitor GitHub issues for auto-created reports
