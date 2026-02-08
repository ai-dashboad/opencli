# Coolify 部署检查清单

## 准备工作 ✅

### 1. GitHub Token
- [ ] 访问 https://github.com/settings/tokens
- [ ] 点击 "Generate new token (classic)"
- [ ] 勾选权限: `repo` (Full control of private repositories)
- [ ] 复制 token (格式: `ghp_xxxxxxxxxxxx`)
- [ ] 保存到安全的地方

### 2. 验证仓库访问
- [ ] 确认仓库: https://github.com/ai-dashboad/opencli
- [ ] 确认分支: `main`
- [ ] 确认文件存在:
  - [ ] `cloud/capability-cdn/Dockerfile`
  - [ ] `cloud/telemetry-api/Dockerfile`

---

## 服务 1: Capability CDN 📦

### 在 Coolify 中创建应用

1. **访问 Coolify**
   - [ ] 打开浏览器访问: https://cicd.dtok.io
   - [ ] 登录账号

2. **创建新应用**
   - [ ] 点击 **"+ New Resource"** 或 **"+ New"**
   - [ ] 选择 **"Application"**

3. **配置源代码**
   ```
   Source Type:     [x] GitHub
   Repository:      ai-dashboad/opencli
   Branch:          main
   ```
   - [ ] 填写以上信息

4. **配置构建**
   ```
   Build Pack:           [x] Dockerfile
   Dockerfile Location:  cloud/capability-cdn/Dockerfile
   Build Directory:      /
   Docker Context:       /
   ```
   - [ ] 填写以上信息

5. **配置端口和域名**
   ```
   Port:    80
   Domain:  opencli.ai
   Path:    /api/capabilities
   ```
   - [ ] 填写以上信息
   - [ ] 如果没有域名，可以使用 Coolify 子域名

6. **配置健康检查**
   ```
   Enable Health Check:  [x] Yes
   Health Check Path:    /health
   Health Check Port:    80
   Interval:            30 seconds
   Timeout:             3 seconds
   Retries:             3
   ```
   - [ ] 填写以上信息

7. **其他设置**
   ```
   Auto Deploy:  [x] Enable
   ```
   - [ ] 勾选自动部署

8. **保存并部署**
   - [ ] 点击 **"Save"**
   - [ ] 点击 **"Deploy"**
   - [ ] 等待构建完成 (约 2-5 分钟)

9. **验证部署**
   - [ ] 打开: https://opencli.ai/health
   - [ ] 应该看到: `OK`
   - [ ] 打开: https://opencli.ai/api/capabilities/manifest.json
   - [ ] 应该看到 JSON 格式的能力包清单

---

## 服务 2: Telemetry API 🔔

### 在 Coolify 中创建应用

1. **访问 Coolify**
   - [ ] 返回 Coolify 主页
   - [ ] 点击 **"+ New Resource"**
   - [ ] 选择 **"Application"**

2. **配置源代码**
   ```
   Source Type:     [x] GitHub
   Repository:      ai-dashboad/opencli
   Branch:          main
   ```
   - [ ] 填写以上信息

3. **配置构建**
   ```
   Build Pack:           [x] Dockerfile
   Dockerfile Location:  cloud/telemetry-api/Dockerfile
   Build Directory:      /cloud/telemetry-api
   Docker Context:       /cloud/telemetry-api
   ```
   - [ ] 填写以上信息

4. **配置环境变量** ⚠️ 重要
   - [ ] 点击 **"Environment Variables"** 或 **"Secrets"** 标签
   - [ ] 添加以下变量:

   | Key | Value | Secret? |
   |-----|-------|---------|
   | `GITHUB_TOKEN` | `ghp_你的token` | ✅ Yes |
   | `GITHUB_OWNER` | `ai-dashboad` | ❌ No |
   | `GITHUB_REPO` | `opencli` | ❌ No |
   | `PORT` | `3000` | ❌ No |

   - [ ] 确保 `GITHUB_TOKEN` 标记为 Secret

5. **配置端口和域名**
   ```
   Port:    3000
   Domain:  opencli.ai
   Path:    /api/telemetry
   ```
   - [ ] 填写以上信息

6. **配置健康检查**
   ```
   Enable Health Check:  [x] Yes
   Health Check Path:    /health
   Health Check Port:    3000
   Interval:            30 seconds
   Timeout:             3 seconds
   Retries:             3
   ```
   - [ ] 填写以上信息

7. **其他设置**
   ```
   Auto Deploy:  [x] Enable
   ```
   - [ ] 勾选自动部署

8. **保存并部署**
   - [ ] 点击 **"Save"**
   - [ ] 点击 **"Deploy"**
   - [ ] 等待构建完成 (约 3-5 分钟)

9. **验证部署**
   - [ ] 打开: https://opencli.ai/api/telemetry/health
   - [ ] 应该看到: `{"status":"ok","timestamp":"..."}`

---

## 测试部署 🧪

### 1. 测试 CDN
```bash
# 健康检查
curl https://opencli.ai/health

# 获取能力包清单
curl https://opencli.ai/api/capabilities/manifest.json

# 如果有能力包文件，测试下载
curl https://opencli.ai/api/capabilities/packages/desktop.open_app.yaml
```
- [ ] CDN 健康检查通过
- [ ] 能返回 manifest.json
- [ ] 能下载能力包文件 (如果有)

### 2. 测试 API
```bash
# 健康检查
curl https://opencli.ai/api/telemetry/health

# 测试错误上报
curl -X POST https://opencli.ai/api/telemetry/report \
  -H "Content-Type: application/json" \
  -d '{
    "error": {
      "message": "Deployment verification test",
      "severity": "info",
      "stack": "test stack trace"
    },
    "system_info": {
      "platform": "test",
      "osVersion": "test",
      "appVersion": "0.2.0"
    },
    "device_id": "test-deployment-verification"
  }'
```
- [ ] API 健康检查通过
- [ ] 错误上报成功
- [ ] 检查 GitHub Issues: https://github.com/ai-dashboad/opencli/issues
- [ ] 应该看到自动创建的测试 Issue

---

## 配置域名路由 🌐

如果 Coolify 使用 Traefik 或 Nginx Proxy Manager:

### Traefik 标签 (Coolify 通常自动处理)
CDN 和 API 应该已经通过域名配置自动设置路由。

### 手动配置 (如果需要)
在 Coolify Proxy 设置中:
```nginx
# opencli.ai 主域名
server {
    listen 443 ssl http2;
    server_name opencli.ai;

    # CDN 路由
    location /api/capabilities {
        proxy_pass http://opencli-capability-cdn;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # API 路由
    location /api/telemetry {
        proxy_pass http://opencli-telemetry-api:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # 健康检查
    location /health {
        proxy_pass http://opencli-capability-cdn;
    }
}
```
- [ ] 路由配置正确
- [ ] SSL 证书已配置 (Coolify 通常自动配置 Let's Encrypt)

---

## 监控和维护 📊

### 1. 在 Coolify 中查看日志
- [ ] CDN 日志: Applications → opencli-capability-cdn → Logs
- [ ] API 日志: Applications → opencli-telemetry-api → Logs

### 2. 设置告警 (可选)
- [ ] 配置健康检查失败告警
- [ ] 配置部署失败通知

### 3. 定期检查
- [ ] 每周检查服务状态
- [ ] 查看 GitHub Issues 的自动上报
- [ ] 监控 CDN 下载统计

---

## 更新代码 🔄

由于启用了 Auto Deploy，当你推送代码到 `main` 分支时:
- [ ] Coolify 会自动检测更新
- [ ] 自动重新构建
- [ ] 自动部署新版本
- [ ] 零停机更新

手动重新部署:
- [ ] 进入应用详情页
- [ ] 点击 **"Redeploy"** 按钮

---

## 故障排查 🔧

### CDN 返回 404
```bash
# 检查容器内文件
docker exec <container-id> ls -la /usr/share/nginx/html/api/capabilities/
```
- [ ] 确认文件已复制到容器
- [ ] 检查 Dockerfile COPY 命令

### API 无法创建 Issue
```bash
# 检查环境变量
docker exec <container-id> env | grep GITHUB
```
- [ ] 确认 GITHUB_TOKEN 已设置
- [ ] 测试 token 有效性:
  ```bash
  curl -H "Authorization: token ghp_xxx" https://api.github.com/user
  ```

### 服务无法访问
- [ ] 检查 Coolify Proxy 状态
- [ ] 检查容器是否运行: `docker ps`
- [ ] 检查端口映射
- [ ] 检查防火墙规则

---

## 完成确认 ✅

部署完成后:
- [ ] CDN 可访问: https://opencli.ai/api/capabilities/manifest.json
- [ ] API 可访问: https://opencli.ai/api/telemetry/health
- [ ] 测试 Issue 已创建
- [ ] 健康检查正常
- [ ] 自动部署已启用
- [ ] 日志可查看

**恭喜！OpenCLI 云端服务已成功部署！🎉**

---

## 下一步

更新 daemon 配置以使用生产环境:

```dart
// daemon/lib/capabilities/capability_loader.dart
CapabilityLoader({
  String? cacheDirectory,
  this.repositoryUrl = 'https://opencli.ai/api/capabilities', // 更新这里
  this.manifestCacheDuration = const Duration(hours: 1),
})

// daemon/lib/telemetry/issue_reporter.dart
static const String _apiEndpoint = 'https://opencli.ai/api/telemetry/report'; // 更新这里
```

提交并发布新版本！
