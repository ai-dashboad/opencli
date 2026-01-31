# 首次测试发布 - 问题记录和解决方案

## 发布信息

- **版本**: v0.1.1-beta.1
- **时间**: 2026-01-31 10:25:23Z
- **状态**: ❌ 失败
- **总耗时**: 1分17秒

---

## 🐛 发现的问题

### 问题 1: Linux ARM64 交叉编译失败 ❌ 严重

**影响范围**: `build-cli` job - `aarch64-unknown-linux-musl` target

**错误信息**:
```
error: linking with `cc` failed: exit status: 1
/usr/bin/ld: error adding symbols: file in wrong format
```

**根本原因**:
- 在 x86_64 主机上交叉编译 ARM64 目标时缺少交叉编译工具链
- 没有安装 `gcc-aarch64-linux-gnu` 交叉编译器
- release.yml 中的 Linux ARM64 配置不完整

**解决方案**:
```yaml
# .github/workflows/release.yml

- name: Install musl tools (Linux)
  if: contains(matrix.target, 'linux-musl')
  run: |
    sudo apt-get update
    sudo apt-get install -y musl-tools
    # 添加 ARM64 交叉编译工具
    if [[ "${{ matrix.target }}" == "aarch64-unknown-linux-musl" ]]; then
      sudo apt-get install -y gcc-aarch64-linux-gnu
      # 设置链接器
      echo "CARGO_TARGET_AARCH64_UNKNOWN_LINUX_MUSL_LINKER=aarch64-linux-gnu-gcc" >> $GITHUB_ENV
    fi
```

**优先级**: 🔴 高（影响 Linux ARM64 用户）

**临时方案**: 暂时移除 Linux ARM64 构建目标，等修复后再添加

---

### 问题 2: Dart daemon 依赖版本错误 ❌ 严重

**影响范围**: `build-daemon` job - 所有平台

**错误信息**:
```
Because opencli_daemon depends on msgpack_dart ^2.0.0 which doesn't match any versions, version solving failed.
```

**根本原因**:
- `daemon/pubspec.yaml` 中指定的 `msgpack_dart: ^2.0.0` 不存在
- pub.dev 上最新版本是 `1.0.1`

**解决方案**:
```yaml
# daemon/pubspec.yaml
dependencies:
  # 修改前:
  # msgpack_dart: ^2.0.0

  # 修改后:
  msgpack_dart: ^1.0.1
```

**优先级**: 🔴 高（阻塞所有 daemon 构建）

---

### 问题 3: 缺少 Homebrew tap 仓库 ⚠️ 预期

**影响范围**: `publish-homebrew` workflow

**状态**: 未运行（因为主 release 失败）

**原因**: 仓库 `ai-dashboad/homebrew-tap` 不存在

**解决方案**: 创建仓库（见下文）

**优先级**: 🟡 中（非阻塞，可稍后创建）

---

### 问题 4: 缺少 Scoop bucket 仓库 ⚠️ 预期

**影响范围**: `publish-scoop` workflow

**状态**: 未运行（因为主 release 失败）

**原因**: 仓库 `ai-dashboad/scoop-bucket` 不存在

**解决方案**: 创建仓库（见下文）

**优先级**: 🟡 中（非阻塞，可稍后创建）

---

### 问题 5: 缺少发布渠道 tokens ⚠️ 预期

**影响范围**: npm, VSCode, Snap 等可选渠道

**状态**: 未运行（因为主 release 失败）

**原因**: GitHub Secrets 未配置

**需要配置的 Secrets**:
- `HOMEBREW_TAP_TOKEN` - Homebrew formula 推送
- `SCOOP_BUCKET_TOKEN` - Scoop manifest 推送
- `NPM_TOKEN` - npm 包发布
- `VSCE_TOKEN` - VSCode Marketplace
- `OVSX_TOKEN` - Open VSX Registry
- `SNAPCRAFT_TOKEN` - Snap Store

**解决方案**: 在 GitHub Settings → Secrets 中添加

**优先级**: 🟢 低（可选渠道，稍后配置）

---

## ✅ 成功的部分

虽然发布失败，但以下部分工作正常：

1. ✅ **版本号同步脚本** - 所有文件版本号正确更新
2. ✅ **CHANGELOG 更新** - 新版本条目正确生成
3. ✅ **文档同步** - README 正确分发到各渠道
4. ✅ **Git 操作** - Commit, tag, push 都成功
5. ✅ **GitHub Actions 触发** - Workflows 正确启动
6. ✅ **部分平台构建开始** - macOS, Windows, Linux x64 构建已开始

---

## 🔧 立即修复方案

### 修复 1: 修正 Dart 依赖版本

```bash
# 1. 修改 daemon/pubspec.yaml
cd daemon
# 将 msgpack_dart: ^2.0.0 改为 msgpack_dart: ^1.0.1

# 2. 测试本地构建
dart pub get
dart compile exe bin/daemon.dart -o test-daemon

# 3. 提交修复
git add daemon/pubspec.yaml
git commit -m "fix: Update msgpack_dart dependency to correct version"
git push
```

### 修复 2: 临时移除 Linux ARM64 构建

```yaml
# .github/workflows/release.yml
# 注释掉或删除 Linux ARM64 配置
strategy:
  matrix:
    include:
      # ... 保留其他平台 ...

      # 暂时移除，等交叉编译配置完成后再添加
      # - os: ubuntu-latest
      #   target: aarch64-unknown-linux-musl
      #   artifact_name: opencli
      #   asset_name: opencli-linux-arm64
```

### 修复 3: 创建必要仓库

见下一节的详细步骤。

---

## 📋 修复后的测试计划

### 阶段 1: 核心修复（今天）

1. ✅ 修复 Dart 依赖版本
2. ✅ 临时移除 Linux ARM64
3. ✅ 创建 homebrew-tap 仓库
4. ✅ 创建 scoop-bucket 仓库
5. ✅ 配置基本 Secrets（HOMEBREW_TAP_TOKEN, SCOOP_BUCKET_TOKEN）
6. 🔄 重新发布 v0.1.1-beta.2

### 阶段 2: 完善配置（本周）

1. 配置 NPM_TOKEN
2. 配置 VSCE_TOKEN
3. 配置 SNAPCRAFT_TOKEN
4. 修复 Linux ARM64 交叉编译
5. 测试所有渠道

### 阶段 3: 正式发布（下周）

1. 发布 v1.0.0 正式版
2. 验证所有渠道可用
3. 发布公告

---

## 📊 问题统计

| 类型 | 数量 | 严重性 |
|------|------|--------|
| 严重问题 | 2 | 🔴 阻塞发布 |
| 预期问题 | 3 | 🟡 可延后处理 |
| 成功部分 | 6 | ✅ 正常工作 |

**总体评估**:
- 🎯 核心自动化系统工作正常
- 🐛 2 个严重问题需要立即修复
- 📈 修复后预计 90% 功能可用

---

## 🎓 经验教训

### 1. 依赖版本管理

**问题**: 依赖版本号写错导致构建失败

**教训**:
- 在发布前本地测试所有组件的构建
- 验证依赖版本在 pub.dev/crates.io 上确实存在

**改进**:
```bash
# 添加到发布前检查脚本
dart pub get --dry-run  # 验证依赖可解析
cargo check             # 验证 Rust 代码可编译
```

### 2. 交叉编译配置

**问题**: Linux ARM64 交叉编译缺少工具链

**教训**:
- 交叉编译需要额外的工具链配置
- 不是所有目标都能在 GitHub Actions 默认环境编译

**改进**:
- 使用 Docker 进行交叉编译（更可靠）
- 或使用 GitHub Actions 的原生 ARM64 runner（成本更高）

### 3. 发布前验证

**问题**: 没有完整的本地构建测试

**教训**:
- 自动化系统再完善，本地测试仍然重要
- 第一次发布应该更谨慎

**改进**:
- 创建发布前检查脚本
- 添加到 `scripts/pre-release-check.sh`

---

## 📝 后续行动项

### 立即（今天）

- [ ] 修复 daemon/pubspec.yaml 依赖版本
- [ ] 临时移除 Linux ARM64 构建
- [ ] 创建 homebrew-tap 仓库
- [ ] 创建 scoop-bucket 仓库
- [ ] 配置 HOMEBREW_TAP_TOKEN 和 SCOOP_BUCKET_TOKEN
- [ ] 删除失败的 v0.1.1-beta.1 tag
- [ ] 重新发布 v0.1.1-beta.2

### 本周

- [ ] 研究 Linux ARM64 交叉编译方案
- [ ] 配置其他可选渠道的 tokens
- [ ] 创建发布前检查脚本
- [ ] 测试所有发布渠道

### 下周

- [ ] 添加回 Linux ARM64 支持
- [ ] 发布 v1.0.0 正式版
- [ ] 编写发布后验证文档

---

**记录时间**: 2026-01-31
**状态**: 问题已识别，修复方案已制定
**下一步**: 执行修复并重新测试
