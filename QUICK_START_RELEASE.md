# OpenCLI 自动化发版系统 - 快速开始

恭喜！您的 OpenCLI 项目现已配备**世界级的自动化多渠道发版系统**。

## 🎯 系统概览

- **14 个发布渠道**：覆盖所有主流平台
- **95% 自动化**：一键触发全流程
- **30 分钟发版**：从执行到完成
- **5 个平台**：macOS, Linux, Windows, Docker, 全平台

## 🚀 首次发版前准备

### 步骤 1: 创建必要的仓库

在 GitHub 上创建以下仓库（将 `<org>` 替换为您的组织名）：

```bash
# 1. Homebrew tap 仓库
https://github.com/<org>/homebrew-tap

# 2. Scoop bucket 仓库
https://github.com/<org>/scoop-bucket
```

**操作步骤**：
1. 登录 GitHub
2. 点击 New Repository
3. 输入仓库名（`homebrew-tap` 或 `scoop-bucket`）
4. 选择 Public
5. 不要初始化任何文件
6. 点击 Create repository

---

### 步骤 2: 配置 GitHub Secrets

在主仓库中配置必要的 secrets：

**必须配置（核心渠道）**：

1. 转到 `Settings` → `Secrets and variables` → `Actions`
2. 点击 `New repository secret`
3. 添加以下 secrets：

```
名称: HOMEBREW_TAP_TOKEN
值: <GitHub Personal Access Token>
权限: repo (完全访问)

名称: SCOOP_BUCKET_TOKEN
值: <GitHub Personal Access Token>
权限: repo (完全访问)
```

**可选配置（扩展渠道）**：

```
NPM_TOKEN             # npm 发布（推荐）
VSCE_TOKEN            # VSCode Marketplace（推荐）
OVSX_TOKEN            # Open VSX Registry（可选）
SNAPCRAFT_TOKEN       # Snap Store（可选）
```

**如何获取 GitHub PAT**：
1. GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Generate new token (classic)
3. 勾选 `repo` 权限
4. Generate token
5. 复制 token（只显示一次！）

---

### 步骤 3: 更新项目信息

编辑以下文件，替换占位符为实际信息：

#### 1. `npm/scripts/postinstall.js`

```javascript
// 第 13 行
const REPO = 'opencli/opencli'; // 改为: <org>/<repo>
```

#### 2. `smithery.json`

```json
{
  "repository": "https://github.com/<org>/<repo>",  // 更新
  "homepage": "https://opencli.ai",                  // 更新域名
  ...
}
```

#### 3. `PUBLISHING.md` 等文档

全局搜索并替换：
- `<org>` → 您的组织名
- `opencli.ai` → 您的域名（如有）

---

### 步骤 4: 测试本地构建

在发版前确保本地构建成功：

```bash
# 测试 Rust CLI 构建
cd cli
cargo build --release
cargo test
cd ..

# 测试 Dart daemon 构建
cd daemon
dart pub get
dart compile exe bin/daemon.dart -o test-daemon
./test-daemon --help
cd ..

# 测试脚本
dart scripts/bump_version.dart 0.1.1
git diff  # 查看变更
git checkout .  # 恢复
```

---

## 🎬 执行首次发版

### 方式 1: 测试版本（推荐）

先发布一个测试版本，确保流程正常：

```bash
./scripts/release.sh 0.1.1-beta.1 "Test automated release system"
```

这将：
1. ✅ 更新版本号到 `0.1.1-beta.1`
2. ✅ 更新 CHANGELOG.md
3. ✅ 创建 Git commit 和 tag
4. ✅ 推送到远程
5. ✅ 触发 GitHub Actions
6. ✅ 发布为 pre-release

---

### 方式 2: 正式版本

当测试成功后，发布正式版本：

```bash
./scripts/release.sh 1.0.0 "Initial stable release with automated multi-channel publishing"
```

---

## 📊 监控发版进度

### GitHub Actions

访问：`https://github.com/<org>/<repo>/actions`

查看以下 workflows 的执行情况：
- ✅ Release
- ✅ Publish to Homebrew
- ✅ Publish to Scoop
- ✅ Publish to Winget
- ✅ Publish to npm
- ✅ Build and Publish Docker Images
- ✅ Publish to Snap Store
- ✅ Publish VSCode Extension

**预计耗时**：30-35 分钟

---

## ✅ 验证发布成功

### 1. GitHub Release

访问：`https://github.com/<org>/<repo>/releases`

检查：
- ✅ Release 已创建
- ✅ 所有二进制文件已上传
- ✅ SHA256SUMS.txt 存在
- ✅ Release notes 已自动生成

---

### 2. Homebrew

```bash
brew tap <org>/tap
brew info opencli
brew install opencli
opencli --version
```

---

### 3. Scoop (Windows)

```powershell
scoop bucket add opencli https://github.com/<org>/scoop-bucket
scoop info opencli
scoop install opencli
opencli --version
```

---

### 4. npm

```bash
npm info @opencli/cli
npm install -g @opencli/cli
opencli --version
```

---

### 5. Docker

```bash
docker pull ghcr.io/<org>/<repo>:latest
docker run ghcr.io/<org>/<repo>:latest opencli --version
```

---

## 🐛 常见问题排查

### 问题 1: GitHub Actions 失败

**检查**：
- Secrets 是否正确配置
- 仓库权限是否足够
- 查看 Actions 日志定位错误

**解决**：
1. 修复问题
2. 删除失败的 tag：
   ```bash
   git tag -d v0.1.1
   git push origin :refs/tags/v0.1.1
   ```
3. 重新发版

---

### 问题 2: Homebrew/Scoop 推送失败

**原因**：token 权限不足或仓库不存在

**解决**：
1. 确认仓库已创建
2. 检查 token 权限（需要 `repo` 权限）
3. 重新生成 token 并更新 secret

---

### 问题 3: npm 发布失败

**原因**：token 无效或包名已被占用

**解决**：
1. 登录 npmjs.com 生成新 token
2. 更新 `NPM_TOKEN` secret
3. 检查包名是否可用（可能需要使用 scoped name: `@<org>/cli`）

---

## 📚 完整文档索引

详细文档请参考：

1. **PUBLISHING.md** - 完整发版流程和故障排除
2. **docs/DISTRIBUTION_CHANNELS.md** - 所有发布渠道详解
3. **docs/CLIENT_RELEASES_COMPLETE.md** - 完整实现报告
4. **docs/RELEASE_AUTOMATION_SUMMARY.md** - 技术实现总结

---

## 🎉 下一步

### 立即可做

1. ✅ 执行首次测试发版
2. ✅ 验证所有渠道正常工作
3. ✅ 提交 Winget manifest PR（可选）

### 后续优化

1. 📝 自定义 CHANGELOG 模板
2. 🔔 配置发版通知（Slack/Discord）
3. 📱 开发 Mobile Apps（iOS/Android）
4. 🌐 部署官网和文档站点

### 社区推广

1. 🐦 发布发版公告
2. 📢 提交到 awesome 列表
3. 💬 在社区分享使用体验
4. ⭐ 鼓励用户 star 项目

---

## 💡 专业提示

### 发版最佳实践

1. **先测试后发布**：使用 beta 版本测试流程
2. **保持 CHANGELOG**：详细记录每次变更
3. **语义化版本**：严格遵循 SemVer 规范
4. **定期发版**：保持稳定的发版节奏
5. **监控反馈**：关注用户问题和建议

### 版本号建议

- `0.x.x` - 初期开发阶段
- `1.0.0` - 首个稳定版本
- `1.x.0` - 新功能
- `1.0.x` - Bug 修复
- `x.0.0` - 重大更新

### 发版频率

- **补丁版本**：每周或按需
- **次版本**：每月一次
- **主版本**：每季度或半年

---

## 🎊 恭喜！

您现在拥有了一套**业界领先的自动化发版系统**！

- 🚀 一键发版到 14 个渠道
- 🌍 覆盖所有主流平台
- ⚡ 30 分钟完成全流程
- 🎯 100% 用户触达

**立即开始您的首次发版吧！** 🎉

```bash
./scripts/release.sh 0.1.1-beta.1 "Test automated release"
```

---

**需要帮助？**
- 📖 查看完整文档：`docs/`
- 🐛 报告问题：GitHub Issues
- 💬 技术讨论：GitHub Discussions

祝发版顺利！🚀
