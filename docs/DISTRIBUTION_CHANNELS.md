# OpenCLI 发布渠道完整指南

本文档详细说明 OpenCLI 所有客户端的发布渠道和使用方式。

## 📦 客户端总览

OpenCLI 项目包含以下客户端组件：

| 客户端 | 语言 | 状态 | 发布渠道数 |
|--------|------|------|-----------|
| CLI Client | Rust | ✅ 已实现 | 8 个 |
| Daemon | Dart | ✅ 已实现 | 与 CLI 捆绑 |
| VSCode Extension | TypeScript | ✅ 已实现 | 2 个 |
| npm Package | Node.js | ✅ 已实现 | 1 个 |
| Web UI | React | ⚠️ 可选 | 多种方式 |
| Mobile Apps | Flutter | ⏳ 待开发 | - |

---

## 1️⃣ CLI Client + Daemon

### 发布渠道（8 个）

#### ✅ GitHub Releases (主渠道)
**状态**: 完全自动化

**内容**:
- 5 个 CLI 二进制文件（macOS ARM64/x64, Linux x64/ARM64, Windows x64）
- 3 个 Daemon 二进制文件（macOS, Linux, Windows）
- SHA256 checksums
- 自动生成的 Release Notes

**用户使用**:
```bash
# 下载对应平台的二进制
curl -LO https://github.com/opencli/opencli/releases/latest/download/opencli-macos-arm64

# 验证 checksum
sha256sum -c SHA256SUMS.txt

# 安装
chmod +x opencli-macos-arm64
sudo mv opencli-macos-arm64 /usr/local/bin/opencli
```

**触发**: Git 标签推送（`v*`）

---

#### ✅ Homebrew (macOS/Linux)
**状态**: 完全自动化

**特点**:
- 独立 tap 仓库：`opencli/homebrew-tap`
- 支持 macOS (ARM64 + x86_64) 和 Linux
- 自动更新 formula 和 checksums

**用户使用**:
```bash
brew tap opencli/tap
brew install opencli

# 更新
brew update
brew upgrade opencli

# 卸载
brew uninstall opencli
```

**工作流**: `.github/workflows/publish-homebrew.yml`

---

#### ✅ Scoop (Windows)
**状态**: 完全自动化

**特点**:
- 独立 bucket 仓库：`opencli/scoop-bucket`
- 支持 autoupdate 机制
- 自动安装后提示

**用户使用**:
```powershell
scoop bucket add opencli https://github.com/opencli/scoop-bucket
scoop install opencli

# 更新
scoop update opencli

# 卸载
scoop uninstall opencli
```

**工作流**: `.github/workflows/publish-scoop.yml`

---

#### ✅ Winget (Windows Package Manager)
**状态**: 半自动（需手动 PR）

**特点**:
- 自动生成完整 manifest 套件
- 上传为 workflow artifacts
- 需要手动 PR 到 `microsoft/winget-pkgs`

**用户使用**:
```powershell
winget install OpenCLI.OpenCLI

# 更新
winget upgrade OpenCLI.OpenCLI

# 卸载
winget uninstall OpenCLI.OpenCLI
```

**发布流程**:
1. GitHub Actions 自动生成 manifest
2. 下载 artifacts
3. Fork `microsoft/winget-pkgs`
4. 提交 PR

**工作流**: `.github/workflows/publish-winget.yml`

---

#### ✅ npm (跨平台)
**状态**: 完全自动化

**特点**:
- 包名：`@opencli/cli`
- 自动下载对应平台的原生二进制
- 缓存到 `~/.opencli/bin/`
- 支持编程式调用

**用户使用**:
```bash
# 全局安装
npm install -g @opencli/cli

# 项目中使用
npm install @opencli/cli --save-dev
npx opencli --help

# 编程式使用
const opencli = require('@opencli/cli');
console.log(opencli.version());
opencli.exec(['daemon', 'start']);
```

**工作流**: `.github/workflows/publish-npm.yml`

---

#### ✅ Docker / GHCR
**状态**: 完全自动化

**特点**:
- 多架构支持（amd64, arm64）
- 语义化标签（latest, version, major.minor, major）
- 优化的多阶段构建
- 非 root 用户运行

**用户使用**:
```bash
# 拉取镜像
docker pull ghcr.io/opencli/opencli:latest

# 运行
docker run -it ghcr.io/opencli/opencli:latest opencli --help

# 后台运行 daemon
docker run -d \
  --name opencli-daemon \
  -v ~/.opencli:/home/opencli/.opencli \
  ghcr.io/opencli/opencli:latest \
  opencli daemon start

# 使用 docker-compose
version: '3.8'
services:
  opencli:
    image: ghcr.io/opencli/opencli:latest
    command: opencli daemon start
    volumes:
      - ~/.opencli:/home/opencli/.opencli
    restart: unless-stopped
```

**可用标签**:
- `latest` - 最新稳定版
- `1.0.0` - 特定版本
- `1.0` - 最新 1.0.x 版本
- `1` - 最新 1.x.x 版本

**工作流**: `.github/workflows/docker.yml`

---

#### ✅ Snap (Linux)
**状态**: 完全自动化（需配置 token）

**特点**:
- 支持 amd64 和 arm64
- 自动根据版本选择 channel
- 包含 CLI 和 daemon

**用户使用**:
```bash
# 安装
sudo snap install opencli

# 从特定 channel 安装
sudo snap install opencli --channel=beta

# 更新
sudo snap refresh opencli

# 卸载
sudo snap remove opencli
```

**Channel 映射**:
- `x.x.x` → `stable`
- `x.x.x-rc.x` → `candidate`
- `x.x.x-beta.x` → `beta`
- `x.x.x-alpha.x` → `edge`

**工作流**: `.github/workflows/publish-snap.yml`

---

#### ✅ 直接下载（Install Script）
**状态**: 待实现

**计划实现**:
```bash
# 自动检测平台并安装
curl -sSL https://opencli.ai/install.sh | sh

# 或 PowerShell (Windows)
irm https://opencli.ai/install.ps1 | iex
```

**脚本功能**:
- 自动检测操作系统和架构
- 下载对应的二进制
- 验证 checksum
- 安装到系统 PATH
- 配置自动补全

---

## 2️⃣ VSCode Extension

### 发布渠道（2 个）

#### ✅ VSCode Marketplace
**状态**: 完全自动化（需配置 token）

**特点**:
- 扩展 ID: `opencli.opencli-vscode`
- 自动编译和打包
- 支持 VSCode 1.80.0+

**用户使用**:
```bash
# 命令行安装
code --install-extension opencli.opencli-vscode

# 或在 VSCode 中搜索 "OpenCLI"
```

**发布需求**:
- `VSCE_TOKEN` secret（从 https://marketplace.visualstudio.com 获取）

**工作流**: `.github/workflows/publish-vscode.yml`

---

#### ✅ Open VSX Registry
**状态**: 完全自动化（需配置 token）

**特点**:
- 开源的扩展市场
- 支持 VSCodium, Gitpod, Theia 等

**用户使用**:
- 在兼容编辑器的扩展市场搜索 "OpenCLI"

**发布需求**:
- `OVSX_TOKEN` secret（从 https://open-vsx.org 获取）

**工作流**: 与 VSCode Marketplace 共享

---

## 3️⃣ Web UI

### 部署方式（多选）

#### 选项 A: 内嵌到 Daemon
**状态**: 推荐

**实现**:
- 编译 Web UI 为静态文件
- 打包到 daemon 二进制
- Daemon 启动时提供 Web 服务

**优点**:
- 无需额外部署
- 用户体验统一
- 资源占用少

**访问**:
```
http://localhost:8080/dashboard
```

---

#### 选项 B: GitHub Pages
**状态**: 可选

**实现**:
```yaml
# .github/workflows/deploy-web-ui.yml
- name: Build and Deploy
  uses: peaceiris/actions-gh-pages@v3
  with:
    github_token: ${{ secrets.GITHUB_TOKEN }}
    publish_dir: ./web-ui/dist
```

**访问**:
```
https://opencli.github.io/opencli
```

---

#### 选项 C: Vercel/Netlify
**状态**: 可选

**实现**:
- 连接 GitHub 仓库
- 自动部署 `web-ui/` 目录
- 支持预览环境

**访问**:
```
https://opencli.vercel.app
```

---

#### 选项 D: Docker 镜像包含
**状态**: 已实现

**特点**:
- 已在 Dockerfile 中包含
- 访问容器的 Web 端口

**使用**:
```bash
docker run -p 8080:8080 ghcr.io/opencli/opencli:latest
# 访问 http://localhost:8080
```

---

## 4️⃣ Mobile Apps (待开发)

### 计划发布渠道

#### iOS
- **App Store** - Apple 官方应用商店
- **TestFlight** - Beta 测试分发

#### Android
- **Google Play Store** - 官方应用商店
- **F-Droid** - 开源应用商店
- **GitHub Releases** - APK 直接下载

**状态**: 📅 Roadmap

---

## 🎯 发布渠道优先级

### 必须（Tier 1）
✅ 已实现且稳定运行：

1. **GitHub Releases** - 所有平台的源
2. **Homebrew** - macOS/Linux 主流安装方式
3. **Docker/GHCR** - 容器化部署

### 推荐（Tier 2）
✅ 已实现，需配置 secrets：

4. **npm** - Node.js 生态用户
5. **Scoop** - Windows 开发者首选
6. **VSCode Marketplace** - IDE 集成

### 可选（Tier 3）
✅ 已实现，提升覆盖率：

7. **Winget** - Windows 官方包管理器
8. **Snap** - Linux 跨发行版方案
9. **Open VSX** - 开源编辑器支持

### 未来（Tier 4）
⏳ 计划中：

10. **Install Scripts** - 简化安装体验
11. **Mobile App Stores** - 移动端支持
12. **Chocolatey** - Windows 另一选择
13. **AUR (Arch User Repository)** - Arch Linux

---

## 📊 渠道覆盖矩阵

| 平台 | GitHub | Homebrew | Scoop | Winget | npm | Docker | Snap |
|------|--------|----------|-------|--------|-----|--------|------|
| macOS ARM64 | ✅ | ✅ | - | - | ✅ | ✅ | - |
| macOS x64 | ✅ | ✅ | - | - | ✅ | ✅ | - |
| Linux x64 | ✅ | ✅ | - | - | ✅ | ✅ | ✅ |
| Linux ARM64 | ✅ | - | - | - | ✅ | ✅ | ✅ |
| Windows x64 | ✅ | - | ✅ | ✅ | ✅ | - | - |

---

## 🔧 发布配置清单

### GitHub Secrets 配置

```bash
# 必须（用于主要渠道）
HOMEBREW_TAP_TOKEN      # Homebrew formula 推送
SCOOP_BUCKET_TOKEN      # Scoop manifest 推送

# 推荐（扩展覆盖率）
NPM_TOKEN               # npm 发布
VSCE_TOKEN              # VSCode Marketplace
OVSX_TOKEN              # Open VSX Registry
SNAPCRAFT_TOKEN         # Snap Store

# 可选（手动处理）
# Winget 无需 token，手动 PR
```

### 仓库创建清单

```bash
# 必须创建的仓库
<org>/homebrew-tap      # Homebrew formulas
<org>/scoop-bucket      # Scoop manifests

# 可选（使用时创建）
<org>/opencli-website   # 官方网站
<org>/opencli-docs      # 文档站点
```

---

## 📈 发布流程图

```
开发者执行 ./scripts/release.sh 1.0.0
           |
           v
    [Git Tag v1.0.0]
           |
           v
   GitHub Actions 触发
           |
    ┌──────┴──────────────────────────┐
    v                                   v
[build-cli]                      [build-daemon]
5 个平台                          3 个平台
    |                                   |
    └──────┬──────────────────────────┘
           v
   [create-release]
           |
    ┌──────┴──────────┬──────────┬──────────┬──────────┬──────────┐
    v                 v          v          v          v          v
[Homebrew]      [Scoop]    [Winget]    [npm]    [Docker]    [Snap]
自动推送         自动推送    生成文件     自动发布   自动构建     自动发布
    |                 |          |          |          |          |
    v                 v          v          v          v          v
[VSCode]                                   用户可通过 8+ 个渠道安装
自动发布
    |
    v
✅ 发布完成
```

---

## 🎉 总结

OpenCLI 实现了业界领先的多渠道自动化发布系统：

- **8 个主要发布渠道**（CLI + Daemon）
- **2 个 IDE 扩展渠道**（VSCode）
- **1 个 npm 包渠道**（跨平台）
- **4 种 Web UI 部署方式**（可选）

**一键发版，覆盖所有主流平台！** 🚀

用户可以通过**最适合自己的方式**安装 OpenCLI，无论是：
- 包管理器（Homebrew, Scoop, Winget, npm, Snap）
- 容器化（Docker）
- IDE 集成（VSCode）
- 直接下载（GitHub Releases）

这确保了 OpenCLI 能够触达最广泛的用户群体！
