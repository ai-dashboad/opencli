# Coolify Quick Deploy (5 Minutes)

## Prerequisites

- Repository: <https://github.com/ai-dashboad/opencli>
- Coolify: <https://cicd.dtok.io>
- GitHub Token (from <https://github.com/settings/tokens>)

---

## Step 1: Deploy CDN (2 minutes)

### 1. Open Coolify

Visit <https://cicd.dtok.io>

### 2. Create New Application

Click **`+ New Resource`** -> **`Application`**

### 3. Select Source

```text
Source Type: [x] Public Repository (GitHub)
Repository URL: https://github.com/ai-dashboad/opencli
Branch: main
```

### 4. Build Settings

```text
Build Pack: [x] Dockerfile
Dockerfile Location: cloud/capability-cdn/Dockerfile
Base Directory: /
Docker Build Context: /
```

### 5. Network Settings

```text
Port: 80
Publicly Accessible: [x] Yes
Domain: opencli.ai
Path Prefix: /api/capabilities
```

### 6. Enable Auto Deploy

```text
[x] Automatic Deployment
```

Once enabled, every push to the main branch will trigger auto deployment.

### 7. Click Deploy

Wait 2-3 minutes for the build to complete.

### 8. Verify

Visit: <https://opencli.ai/health>
Should display: `OK`

---

## Step 2: Deploy API (3 minutes)

### 1. Create Another Application

Click **`+ New Resource`** -> **`Application`**

### 2. Select Source

```text
Source Type: [x] Public Repository (GitHub)
Repository URL: https://github.com/ai-dashboad/opencli
Branch: main
```

### 3. Build Settings

```text
Build Pack: [x] Dockerfile
Dockerfile Location: cloud/telemetry-api/Dockerfile
Base Directory: /cloud/telemetry-api
Docker Build Context: /cloud/telemetry-api
```

### 4. Environment Variables (Important!)

Click the **`Environment Variables`** tab and add:

| Key | Value | Secret? |
|-----|-------|---------|
| `GITHUB_TOKEN` | `ghp_your_token` | Yes |
| `GITHUB_OWNER` | `ai-dashboad` | No |
| `GITHUB_REPO` | `opencli` | No |
| `PORT` | `3000` | No |

### 5. Network Settings

```text
Port: 3000
Publicly Accessible: [x] Yes
Domain: opencli.ai
Path Prefix: /api/telemetry
```

### 6. Enable Auto Deploy

```text
[x] Automatic Deployment
```

### 7. Click Deploy

Wait 3-5 minutes for the build to complete.

### 8. Verify

Visit: <https://opencli.ai/api/telemetry/health>
Should display: `{"status":"ok",...}`

---

## Verify Deployment

### Test CDN

```bash
curl https://opencli.ai/health
curl https://opencli.ai/api/capabilities/manifest.json
```

### Test API

```bash
# Health check
curl https://opencli.ai/api/telemetry/health

# Test error reporting
curl -X POST https://opencli.ai/api/telemetry/report \
  -H "Content-Type: application/json" \
  -d '{
    "error": {"message": "Test from Coolify deployment"},
    "system_info": {"platform": "test"},
    "device_id": "test-123"
  }'
```

Check GitHub Issues - you should see an auto-created Issue.

---

## Auto Deployment Workflow

After deployment is complete:

```text
Push code to GitHub
    |
GitHub triggers webhook
    |
Coolify receives notification
    |
Auto pulls latest code
    |
Rebuilds Docker image
    |
Zero-downtime deployment
    |
Done!
```

**No manual intervention needed, fully automated!**

---

## Monitoring and Logs

### View Logs

In Coolify:

1. Go to the application detail page
2. Click the **`Logs`** tab
3. View logs in real time

### View Status

In the application list you can see:

- Running status
- Resource usage
- Last deployment time

---

## FAQ

### Q: What if the build fails?

**A:** Check the build logs in Coolify. Common causes:

- Incorrect Dockerfile path
- Dependency installation failure
- Port conflict

### Q: Domain is not accessible?

**A:** Check:

1. Is DNS pointing to the Coolify server?
2. Is Coolify Proxy running?
3. Is the SSL certificate configured?

### Q: How to manually trigger a redeployment?

**A:** Click the **`Redeploy`** button on the application detail page.

### Q: How to rollback to a previous version?

**A:** Coolify keeps deployment history. You can rollback
from the deployment history page.

---

## Configuration Reference

Full configuration is stored in:

- `cloud/coolify.yaml` - Configuration file
- `cloud/docker-compose.yml` - Docker Compose configuration
- `cloud/DEPLOYMENT_CHECKLIST.md` - Detailed checklist

---

## Done!

Your OpenCLI cloud services are now deployed and will auto-update!

Every time you push code to the `main` branch, Coolify will automatically:

1. Pull the latest code
2. Rebuild
3. Deploy the new version
4. Run health checks
5. Complete

**Zero manual intervention, fully automated!**
