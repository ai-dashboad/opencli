# 创建必要的发布仓库 - 详细指南

本指南将帮助您创建 OpenCLI 自动化发版系统所需的仓库。

---

## 📦 需要创建的仓库

### 1. homebrew-tap

**仓库名称**: `homebrew-tap`
**完整路径**: `https://github.com/ai-dashboad/homebrew-tap`
**用途**: 存储 Homebrew formula，用于 macOS/Linux 用户通过 `brew install` 安装

### 2. scoop-bucket

**仓库名称**: `scoop-bucket`
**完整路径**: `https://github.com/ai-dashboad/scoop-bucket`
**用途**: 存储 Scoop manifest，用于 Windows 用户通过 `scoop install` 安装

---

## 🚀 创建步骤

### 方法 1: 通过 GitHub Web 界面（推荐）

#### 创建 homebrew-tap 仓库

1. **访问**: https://github.com/new

2. **填写信息**:
   - Repository name: `homebrew-tap`
   - Description: `Homebrew formula for OpenCLI`
   - Visibility: ✅ Public（必须是 Public）
   - ❌ 不要勾选 "Add a README file"
   - ❌ 不要添加 .gitignore
   - ❌ 不要选择 License

3. **点击**: Create repository

4. **初始化仓库**（在本地执行）:

```bash
# 创建临时目录
mkdir -p /tmp/homebrew-tap
cd /tmp/homebrew-tap

# 初始化 Git 仓库
git init
git branch -M main

# 创建 README
cat > README.md << 'EOF'
# Homebrew Tap for OpenCLI

Official Homebrew tap for [OpenCLI](https://github.com/ai-dashboad/opencli).

## Installation

```bash
brew tap ai-dashboad/tap
brew install opencli
```

## Updating

```bash
brew update
brew upgrade opencli
```

## Uninstall

```bash
brew uninstall opencli
brew untap ai-dashboad/tap
```

## Formula

The formula will be automatically updated by GitHub Actions when new versions are released.
EOF

# 创建 Formula 目录
mkdir -p Formula

# 创建占位符 formula（将被自动更新）
cat > Formula/opencli.rb << 'EOF'
class Opencli < Formula
  desc "Universal AI Development Platform"
  homepage "https://opencli.ai"
  version "0.1.0"
  license "MIT"

  # This formula will be automatically updated by GitHub Actions
  # when new releases are published

  def install
    raise "This formula is not yet populated. Please wait for the first release."
  end
end
EOF

# 提交并推送
git add .
git commit -m "Initial commit for homebrew-tap"
git remote add origin https://github.com/ai-dashboad/homebrew-tap.git
git push -u origin main
```

---

#### 创建 scoop-bucket 仓库

1. **访问**: https://github.com/new

2. **填写信息**:
   - Repository name: `scoop-bucket`
   - Description: `Scoop bucket for OpenCLI`
   - Visibility: ✅ Public（必须是 Public）
   - ❌ 不要勾选 "Add a README file"
   - ❌ 不要添加 .gitignore
   - ❌ 不要选择 License

3. **点击**: Create repository

4. **初始化仓库**（在本地执行）:

```bash
# 创建临时目录
mkdir -p /tmp/scoop-bucket
cd /tmp/scoop-bucket

# 初始化 Git 仓库
git init
git branch -M main

# 创建 README
cat > README.md << 'EOF'
# Scoop Bucket for OpenCLI

Official Scoop bucket for [OpenCLI](https://github.com/ai-dashboad/opencli).

## Installation

```powershell
scoop bucket add opencli https://github.com/ai-dashboad/scoop-bucket
scoop install opencli
```

## Updating

```powershell
scoop update opencli
```

## Uninstall

```powershell
scoop uninstall opencli
```

## Manifest

The manifest will be automatically updated by GitHub Actions when new versions are released.
EOF

# 创建占位符 manifest（将被自动更新）
cat > opencli.json << 'EOF'
{
  "version": "0.1.0",
  "description": "Universal AI Development Platform",
  "homepage": "https://opencli.ai",
  "license": "MIT",
  "architecture": {
    "64bit": {
      "url": "https://github.com/ai-dashboad/opencli/releases/download/v0.1.0/opencli-windows-x86_64.exe",
      "hash": ""
    }
  },
  "bin": [["opencli-windows-x86_64.exe", "opencli"]],
  "checkver": {
    "github": "https://github.com/ai-dashboad/opencli"
  },
  "autoupdate": {
    "architecture": {
      "64bit": {
        "url": "https://github.com/ai-dashboad/opencli/releases/download/v$version/opencli-windows-x86_64.exe"
      }
    }
  }
}
EOF

# 提交并推送
git add .
git commit -m "Initial commit for scoop-bucket"
git remote add origin https://github.com/ai-dashboad/scoop-bucket.git
git push -u origin main
```

---

### 方法 2: 通过 GitHub CLI（更快）

```bash
# 确保已安装 gh CLI
gh --version

# 登录 GitHub
gh auth login

# 创建 homebrew-tap 仓库
gh repo create ai-dashboad/homebrew-tap \
  --public \
  --description "Homebrew formula for OpenCLI" \
  --clone

cd homebrew-tap
# 创建 README 和 Formula 目录（参考方法 1 的命令）
mkdir -p Formula
# ... 复制方法 1 中的文件创建命令 ...
git add .
git commit -m "Initial commit"
git push origin main

# 创建 scoop-bucket 仓库
cd ..
gh repo create ai-dashboad/scoop-bucket \
  --public \
  --description "Scoop bucket for OpenCLI" \
  --clone

cd scoop-bucket
# 创建 README 和 manifest（参考方法 1 的命令）
# ... 复制方法 1 中的文件创建命令 ...
git add .
git commit -m "Initial commit"
git push origin main
```

---

## 🔑 配置 GitHub Secrets

创建仓库后，需要配置 GitHub Personal Access Tokens：

### 步骤 1: 创建 Personal Access Token

1. **访问**: https://github.com/settings/tokens/new

2. **填写信息**:
   - Note: `OpenCLI Release Automation`
   - Expiration: `No expiration`（或选择较长期限）
   - Scopes（权限）:
     - ✅ `repo`（完整仓库访问权限）
       - ✅ repo:status
       - ✅ repo_deployment
       - ✅ public_repo
       - ✅ repo:invite
       - ✅ security_events

3. **点击**: Generate token

4. **复制 token**（⚠️ 只显示一次，请立即保存！）

### 步骤 2: 添加 Secrets 到主仓库

1. **访问**: https://github.com/ai-dashboad/opencli/settings/secrets/actions

2. **点击**: New repository secret

3. **添加 HOMEBREW_TAP_TOKEN**:
   - Name: `HOMEBREW_TAP_TOKEN`
   - Secret: 粘贴刚才复制的 token
   - 点击 Add secret

4. **添加 SCOOP_BUCKET_TOKEN**:
   - Name: `SCOOP_BUCKET_TOKEN`
   - Secret: 粘贴同一个 token（可以复用）
   - 点击 Add secret

---

## ✅ 验证配置

创建仓库和配置 Secrets 后，验证一切正常：

### 验证 1: 仓库可访问

```bash
# 验证 homebrew-tap
curl -I https://github.com/ai-dashboad/homebrew-tap
# 应返回 HTTP/2 200

# 验证 scoop-bucket
curl -I https://github.com/ai-dashboad/scoop-bucket
# 应返回 HTTP/2 200
```

### 验证 2: Token 权限

```bash
# 测试 token 是否有推送权限
gh auth status

# 或使用 API 测试
curl -H "Authorization: token YOUR_TOKEN" \
  https://api.github.com/repos/ai-dashboad/homebrew-tap
```

### 验证 3: Secrets 配置

1. 访问: https://github.com/ai-dashboad/opencli/settings/secrets/actions
2. 确认看到:
   - ✅ HOMEBREW_TAP_TOKEN
   - ✅ SCOOP_BUCKET_TOKEN

---

## 📝 完成检查清单

- [ ] 创建 `homebrew-tap` 仓库
- [ ] 初始化 `homebrew-tap` 仓库（README + Formula/）
- [ ] 创建 `scoop-bucket` 仓库
- [ ] 初始化 `scoop-bucket` 仓库（README + manifest）
- [ ] 创建 GitHub Personal Access Token
- [ ] 添加 `HOMEBREW_TAP_TOKEN` secret
- [ ] 添加 `SCOOP_BUCKET_TOKEN` secret
- [ ] 验证仓库可访问
- [ ] 验证 Secrets 已配置

---

## 🎯 下一步

完成以上步骤后，您可以：

1. ✅ 删除失败的 v0.1.1-beta.1 tag
2. ✅ 推送修复后的代码
3. ✅ 发布 v0.1.1-beta.2 进行测试
4. ✅ 验证 Homebrew 和 Scoop 自动更新是否工作

---

## 🆘 故障排除

### 问题: 推送到仓库时提示权限不足

**解决**:
- 确认 token 有 `repo` 权限
- 重新生成 token 并更新 Secrets

### 问题: GitHub Actions 无法访问仓库

**解决**:
- 确认仓库是 Public
- 检查 Secret 名称是否正确
- 查看 Actions 日志获取详细错误

### 问题: 仓库初始化失败

**解决**:
```bash
# 如果远程已有内容，先拉取
git pull origin main --rebase

# 如果需要强制推送（仅第一次）
git push -u origin main --force
```

---

**创建时间**: 2026-01-31
**状态**: 准备就绪
**预计时间**: 10-15 分钟
