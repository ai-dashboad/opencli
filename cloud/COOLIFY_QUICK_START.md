# Coolify 5分钟快速部署

## 前提

- ✅ 仓库: https://github.com/ai-dashboad/opencli
- ✅ Coolify: https://cicd.dtok.io
- ✅ GitHub Token (从 https://github.com/settings/tokens 获取)

---

## 🚀 步骤一：部署 CDN (2分钟)

### 1. 打开 Coolify
访问 https://cicd.dtok.io

### 2. 新建应用
点击 **`+ New Resource`** → **`Application`**

### 3. 选择源
```
Source Type: [x] Public Repository (GitHub)
Repository URL: https://github.com/ai-dashboad/opencli
Branch: main
```

### 4. 构建设置
```
Build Pack: [x] Dockerfile
Dockerfile Location: cloud/capability-cdn/Dockerfile
Base Directory: /
Docker Build Context: /
```

### 5. 网络设置
```
Port: 80
Publicly Accessible: [x] Yes
Domain: opencli.ai
Path Prefix: /api/capabilities
```

### 6. 启用自动部署
```
[x] Automatic Deployment
```
勾选后，每次推送到 main 分支时自动部署。

### 7. 点击 Deploy
等待 2-3 分钟构建完成。

### 8. 验证
访问: https://opencli.ai/health
应该显示: `OK`

---

## 🔔 步骤二：部署 API (3分钟)

### 1. 再次新建应用
点击 **`+ New Resource`** → **`Application`**

### 2. 选择源
```
Source Type: [x] Public Repository (GitHub)
Repository URL: https://github.com/ai-dashboad/opencli
Branch: main
```

### 3. 构建设置
```
Build Pack: [x] Dockerfile
Dockerfile Location: cloud/telemetry-api/Dockerfile
Base Directory: /cloud/telemetry-api
Docker Build Context: /cloud/telemetry-api
```

### 4. 环境变量（重要！）
点击 **`Environment Variables`** 标签，添加：

| Key | Value | Secret? |
|-----|-------|---------|
| `GITHUB_TOKEN` | `ghp_你的token` | ✅ |
| `GITHUB_OWNER` | `ai-dashboad` | ❌ |
| `GITHUB_REPO` | `opencli` | ❌ |
| `PORT` | `3000` | ❌ |

### 5. 网络设置
```
Port: 3000
Publicly Accessible: [x] Yes
Domain: opencli.ai
Path Prefix: /api/telemetry
```

### 6. 启用自动部署
```
[x] Automatic Deployment
```

### 7. 点击 Deploy
等待 3-5 分钟构建完成。

### 8. 验证
访问: https://opencli.ai/api/telemetry/health
应该显示: `{"status":"ok",...}`

---

## ✅ 验证部署成功

### 测试 CDN
```bash
curl https://opencli.ai/health
curl https://opencli.ai/api/capabilities/manifest.json
```

### 测试 API
```bash
# 健康检查
curl https://opencli.ai/api/telemetry/health

# 测试错误上报
curl -X POST https://opencli.ai/api/telemetry/report \
  -H "Content-Type: application/json" \
  -d '{
    "error": {"message": "Test from Coolify deployment"},
    "system_info": {"platform": "test"},
    "device_id": "test-123"
  }'
```

检查 GitHub Issues，应该会看到自动创建的 Issue。

---

## 🔄 自动部署工作流

部署完成后：

```
你推送代码到 GitHub
    ↓
GitHub 触发 webhook
    ↓
Coolify 接收通知
    ↓
自动拉取最新代码
    ↓
重新构建 Docker 镜像
    ↓
零停机部署
    ↓
完成！
```

**无需手动操作，全自动！**

---

## 📊 监控和日志

### 查看日志
在 Coolify 中:
1. 进入应用详情页
2. 点击 **`Logs`** 标签
3. 实时查看日志

### 查看状态
在应用列表中可以看到:
- ✅ 运行状态
- 📊 资源使用
- 🔄 最后部署时间

---

## 🎯 常见问题

### Q: 构建失败怎么办？
**A:** 在 Coolify 中查看构建日志，常见原因：
- Dockerfile 路径错误
- 依赖安装失败
- 端口冲突

### Q: 域名无法访问？
**A:** 检查:
1. DNS 是否指向 Coolify 服务器
2. Coolify Proxy 是否运行
3. SSL 证书是否配置

### Q: 如何手动触发重新部署？
**A:** 在应用详情页点击 **`Redeploy`** 按钮

### Q: 如何回滚到之前的版本？
**A:** Coolify 会保留历史部署，可以在部署历史中选择回滚

---

## 📝 配置参考

完整配置保存在:
- `cloud/coolify.yaml` - 配置文件
- `cloud/docker-compose.yml` - Docker Compose 配置
- `cloud/DEPLOYMENT_CHECKLIST.md` - 详细检查清单

---

## 🎉 完成！

现在你的 OpenCLI 云端服务已经部署完成，并且会自动更新！

每次你推送代码到 `main` 分支，Coolify 会自动：
1. 拉取最新代码
2. 重新构建
3. 部署新版本
4. 健康检查
5. 完成

**零人工干预，全自动化！** 🚀
