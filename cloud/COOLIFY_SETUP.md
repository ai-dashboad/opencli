# Coolify 快速部署指南

## 前提条件

1. Coolify 实例运行在 `cicd.dtok.io`
2. GitHub 仓库: `ai-dashboad/opencli`
3. 域名: `opencli.ai` (已配置 DNS 指向 Coolify 服务器)

## 方式一：通过 Coolify UI 部署（推荐）

### 步骤 1: 准备 GitHub Token

1. 访问 https://github.com/settings/tokens
2. 点击 "Generate new token (classic)"
3. 勾选权限: `repo` (完整控制)
4. 复制生成的 token (格式: `ghp_xxxxxxxxxxxx`)

### 步骤 2: 部署 Capability CDN

1. 登录 Coolify: https://cicd.dtok.io
2. 点击 **"+ New Resource"**
3. 选择 **"Application"**
4. 配置:
   ```
   Source: GitHub
   Repository: ai-dashboad/opencli
   Branch: main
   Build Pack: Dockerfile
   Dockerfile Location: cloud/capability-cdn/Dockerfile
   Build Directory: /

   Port: 80
   Domain: opencli.ai
   Path: /api/capabilities

   Auto Deploy: ✅ Enable
   ```
5. 点击 **"Save & Deploy"**

### 步骤 3: 部署 Telemetry API

1. 继续点击 **"+ New Resource"**
2. 选择 **"Application"**
3. 配置:
   ```
   Source: GitHub
   Repository: ai-dashboad/opencli
   Branch: main
   Build Pack: Dockerfile
   Dockerfile Location: cloud/telemetry-api/Dockerfile
   Build Directory: /cloud/telemetry-api

   Port: 3000
   Domain: opencli.ai
   Path: /api/telemetry

   Auto Deploy: ✅ Enable
   ```
4. 添加环境变量:
   ```
   GITHUB_TOKEN=ghp_your_token_here
   GITHUB_OWNER=ai-dashboad
   GITHUB_REPO=opencli
   PORT=3000
   ```
5. 点击 **"Save & Deploy"**

### 步骤 4: 配置域名路由

在 Coolify 的 Proxy 设置中配置:

```nginx
# opencli.ai 路由规则
location /api/capabilities {
    proxy_pass http://opencli-capability-cdn;
}

location /api/telemetry {
    proxy_pass http://opencli-telemetry-api;
}
```

## 方式二：使用 Docker Compose 部署

### 步骤 1: SSH 到 Coolify 服务器

```bash
ssh user@cicd.dtok.io
```

### 步骤 2: 克隆仓库

```bash
cd /opt/coolify/apps
git clone https://github.com/ai-dashboad/opencli.git
cd opencli/cloud
```

### 步骤 3: 配置环境变量

```bash
cat > .env << EOF
GITHUB_TOKEN=ghp_your_token_here
GITHUB_OWNER=ai-dashboad
GITHUB_REPO=opencli
PORT=3000
EOF
```

### 步骤 4: 部署

```bash
docker-compose up -d
```

### 步骤 5: 在 Coolify 中导入

1. 在 Coolify UI 中点击 **"+ New Resource"**
2. 选择 **"Docker Compose"**
3. 选择已存在的 compose 文件: `/opt/coolify/apps/opencli/cloud/docker-compose.yml`
4. 点击 **"Import & Deploy"**

## 方式三：GitHub Actions 自动部署

已配置 `.github/workflows/deploy-cloud.yml`，当 `cloud/` 目录有变更时自动触发部署。

需要在 GitHub 仓库设置中添加 Secret:
- `COOLIFY_WEBHOOK_URL` (可选，如果 Coolify 支持 webhook)

## 验证部署

### 1. 检查服务状态

```bash
# 检查 CDN
curl https://opencli.ai/health

# 检查 API
curl https://opencli.ai/api/telemetry/health
```

### 2. 测试能力包下载

```bash
# 获取清单
curl https://opencli.ai/api/capabilities/manifest.json

# 下载能力包
curl https://opencli.ai/api/capabilities/packages/desktop.open_app.yaml
```

### 3. 测试错误上报

```bash
curl -X POST https://opencli.ai/api/telemetry/report \
  -H "Content-Type: application/json" \
  -d '{
    "error": {
      "message": "Test deployment verification",
      "severity": "info",
      "stack": "deployment test"
    },
    "system_info": {
      "platform": "test",
      "appVersion": "0.2.0"
    },
    "device_id": "test-deployment"
  }'
```

检查 GitHub Issues 是否创建了新的 issue。

## 查看日志

### 在 Coolify UI 中

1. 进入对应的 Application
2. 点击 "Logs" 标签
3. 实时查看日志

### 使用 Docker 命令

```bash
# CDN 日志
docker logs -f opencli-capability-cdn

# API 日志
docker logs -f opencli-telemetry-api
```

## 更新服务

### 自动更新（推荐）

启用 Auto Deploy 后，每次推送到 `main` 分支，Coolify 会自动重新部署。

### 手动更新

在 Coolify UI 中:
1. 进入对应的 Application
2. 点击 **"Redeploy"** 按钮

或使用命令行:
```bash
cd /opt/coolify/apps/opencli
git pull
cd cloud
docker-compose pull
docker-compose up -d
```

## 监控和告警

### Coolify 内置监控

Coolify 自动监控:
- 容器健康状态
- CPU/内存使用
- 网络流量

### 自定义告警

可以配置:
- 健康检查失败告警
- 资源使用超限告警
- 部署失败通知

### 日志聚合

建议使用:
- Grafana Loki (日志聚合)
- Prometheus (指标收集)
- Uptime Kuma (可用性监控)

## 常见问题

### Q: 部署失败，提示找不到 Dockerfile

**A:** 检查 Dockerfile Location 路径是否正确:
- CDN: `cloud/capability-cdn/Dockerfile`
- API: `cloud/telemetry-api/Dockerfile`

确保 Build Directory 设置为项目根目录 `/`

### Q: API 无法创建 GitHub Issue

**A:** 检查环境变量:
```bash
docker exec opencli-telemetry-api env | grep GITHUB
```

确认 `GITHUB_TOKEN` 已设置且有效。

测试 token:
```bash
curl -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/user
```

### Q: 域名无法访问

**A:** 检查:
1. DNS 是否正确指向 Coolify 服务器
2. Coolify Proxy 配置是否正确
3. 服务是否正常运行 (`docker ps`)

### Q: 能力包 404

**A:** 确认能力包文件存在:
```bash
docker exec opencli-capability-cdn ls -la /usr/share/nginx/html/api/capabilities/packages/
```

如果没有文件，检查 Dockerfile 中的 COPY 命令。

## 成本估算

使用自托管 Coolify:
- 服务器成本: 已有 (cicd.dtok.io)
- 带宽: 约 1GB/月 (假设 1000 次能力包下载)
- GitHub API: 免费 (5000 请求/小时)

**总计: ~$0/月**

## 安全建议

1. ✅ 使用 HTTPS (Let's Encrypt)
2. ✅ 限制 API 速率 (Nginx rate limiting)
3. ✅ 定期更新 Docker 镜像
4. ✅ 使用 GitHub Token 最小权限
5. ✅ 启用 Coolify 的访问日志
6. ✅ 定期备份配置和数据

## 下一步

部署完成后:

1. 更新 daemon 配置指向生产环境:
   ```dart
   // daemon/lib/capabilities/capability_loader.dart
   this.repositoryUrl = 'https://opencli.ai/api/capabilities'

   // daemon/lib/telemetry/issue_reporter.dart
   final endpoint = 'https://opencli.ai/api/telemetry/report'
   ```

2. 发布新版本到客户端

3. 监控错误上报和能力包下载统计
