# OpenCLI 端到端测试计划

## 🎯 测试目标

验证所有组件之间的完整交互流程，确保从任何客户端发送的消息都能正确执行并返回结果。

## 📋 测试环境

### 必需组件
- ✅ OpenCLI Daemon (Dart)
- ✅ opencli_app (Flutter - macOS/Windows/Linux)
- ✅ Telegram Bot
- ✅ Web UI (可选)

### 准备工作
```bash
# 1. 启动 Daemon
cd daemon
dart bin/daemon.dart

# 2. 启动 opencli_app
cd opencli_app
flutter run -d macos

# 3. 配置 Telegram Bot
export TELEGRAM_BOT_TOKEN="your-token"
```

---

## 🧪 测试场景

### 场景 1: Daemon 基础功能
**目标**: 验证 Daemon 可以正常启动并监听连接

**测试步骤**:
1. 启动 Daemon
   ```bash
   cd daemon
   dart bin/daemon.dart
   ```

**预期结果**:
```
OpenCLI Daemon v0.1.0
Starting daemon...
✓ Daemon started successfully
  Socket: /tmp/opencli.sock
  PID: 12345
```

**验证点**:
- [ ] Daemon 进程正常启动
- [ ] Socket 文件创建成功
- [ ] 无错误日志
- [ ] PID 文件生成

---

### 场景 2: opencli_app 连接 Daemon
**目标**: 验证 Flutter 应用可以通过 WebSocket 连接到 Daemon

**测试步骤**:
1. 确保 Daemon 运行中
2. 启动 opencli_app
   ```bash
   cd opencli_app
   flutter run -d macos
   ```
3. 观察连接状态

**预期结果**:
- App 显示 "Connected to OpenCLI Daemon"
- 状态指示器显示绿色
- 可以看到 WebSocket 连接日志

**验证点**:
- [ ] WebSocket 连接成功
- [ ] 心跳保持连接
- [ ] 重连机制工作
- [ ] 状态实时更新

---

### 场景 3: 系统托盘功能
**目标**: 验证系统托盘集成和全局快捷键

**测试步骤**:
1. 启动 opencli_app
2. 观察系统托盘图标
3. 测试快捷键 Cmd+Shift+O
4. 右键点击托盘图标

**预期结果**:
- macOS 菜单栏显示 OpenCLI 图标
- Cmd+Shift+O 可以显示/隐藏窗口
- 右键菜单显示选项
- 关闭窗口后应用继续在托盘运行

**验证点**:
- [ ] 托盘图标显示
- [ ] 全局快捷键工作
- [ ] 托盘菜单功能
- [ ] 最小化到托盘
- [ ] 开机自启动设置

---

### 场景 4: 聊天界面基础功能
**目标**: 验证聊天界面可以发送和接收消息

**测试步骤**:
1. 在 opencli_app 中输入命令: "系统信息"
2. 观察响应
3. 测试语音输入（可选）
4. 测试文件上传（可选）

**预期结果**:
- 消息发送成功
- 收到 Daemon 响应
- 界面显示对话历史
- AI 识别意图正确

**验证点**:
- [ ] 文本输入正常
- [ ] 消息发送成功
- [ ] 响应及时返回
- [ ] 错误处理正确
- [ ] 对话历史保存

---

### 场景 5: Telegram Bot 集成
**目标**: 验证 Telegram Bot 可以接收消息并控制电脑

**前置条件**:
```yaml
# config/channels.yaml
channels:
  telegram:
    enabled: true
    config:
      token: "${TELEGRAM_BOT_TOKEN}"
    allowed_users:
      - "YOUR_USER_ID"
```

**测试步骤**:
1. 配置 Telegram Bot
2. 重启 Daemon
3. 在 Telegram 发送消息: "/start"
4. 发送命令: "截图"
5. 发送命令: "系统状态"

**预期结果**:
```
用户: /start
Bot:  欢迎使用 OpenCLI! 我可以帮你控制电脑。

用户: 截图
Bot:  🖼️ 正在截图...
Bot:  [图片] 已完成！

用户: 系统状态
Bot:  💻 系统状态：
      CPU: 45%
      内存: 8.2/16 GB
```

**验证点**:
- [ ] Bot 接收消息
- [ ] 用户认证工作
- [ ] 意图识别正确
- [ ] 任务执行成功
- [ ] 结果返回 Telegram

---

### 场景 6: 跨平台消息流转
**目标**: 验证消息可以从任何平台发起并正确路由

**测试步骤**:
1. 从 Telegram 发送: "打开 Chrome"
2. 在 opencli_app 查看任务状态
3. 从 opencli_app 发送: "关闭 Chrome"
4. 在 Telegram 接收确认消息

**预期流程**:
```
Telegram → Daemon → 执行任务 → 返回 Telegram
opencli_app → Daemon → 执行任务 → 返回 opencli_app
```

**验证点**:
- [ ] 多渠道同时工作
- [ ] 消息不会串台
- [ ] 用户隔离正确
- [ ] 响应返回原渠道

---

### 场景 7: AI 意图识别
**目标**: 验证 AI 可以理解自然语言并执行正确操作

**测试命令**:
```
1. "帮我截个屏"           → screenshot
2. "打开浏览器"           → open chrome
3. "创建一个文件"         → create file
4. "查看系统信息"         → system info
5. "搜索 Flutter 教程"    → web search
```

**预期结果**:
- 每个命令都被正确识别
- 执行对应的任务类型
- 返回执行结果

**验证点**:
- [ ] 自然语言理解
- [ ] 意图映射正确
- [ ] 参数提取准确
- [ ] 错误提示友好

---

### 场景 8: 错误处理和恢复
**目标**: 验证系统在异常情况下的表现

**测试步骤**:
1. **Daemon 断开**: 关闭 Daemon，观察客户端反应
2. **网络中断**: 断开网络，测试重连
3. **无效命令**: 发送无法识别的命令
4. **权限不足**: 尝试执行需要权限的操作

**预期结果**:
- 显示清晰的错误信息
- 自动重连机制工作
- 用户体验友好
- 不会崩溃

**验证点**:
- [ ] 断线检测
- [ ] 自动重连
- [ ] 错误提示
- [ ] 日志记录
- [ ] 优雅降级

---

### 场景 9: 性能测试
**目标**: 验证系统在负载下的表现

**测试步骤**:
1. 快速连续发送 10 条消息
2. 同时从多个渠道发送消息
3. 发送大文件
4. 长时间运行观察内存

**预期结果**:
- 响应时间 < 2 秒
- 内存占用稳定
- 无内存泄漏
- 并发处理正确

**验证点**:
- [ ] 响应时间合理
- [ ] 消息队列正常
- [ ] 资源占用稳定
- [ ] 无死锁
- [ ] 无崩溃

---

### 场景 10: 端到端完整流程
**目标**: 验证真实使用场景

**用户故事**:
```
早上 8:00 - 在床上用 Telegram 控制电脑
1. "开机" → 如果支持 WOL
2. "截图" → 查看桌面状态
3. "打开 Chrome" → 启动浏览器
4. "搜索今日新闻" → 自动搜索
5. "关闭 Chrome" → 清理
```

**测试执行**:
1. 按顺序发送所有命令
2. 每个命令等待完成后再发送下一个
3. 记录每步耗时
4. 记录任何错误

**验证点**:
- [ ] 所有命令执行成功
- [ ] 总耗时 < 1 分钟
- [ ] 无需人工干预
- [ ] 体验流畅

---

## 🐛 已知问题记录

| ID | 问题描述 | 严重程度 | 状态 | 解决方案 |
|----|----------|----------|------|----------|
| 1  | 示例问题 | 低 | 待修复 | 待定 |

---

## ✅ 测试检查清单

### 基础功能
- [ ] Daemon 启动
- [ ] WebSocket 连接
- [ ] 消息发送/接收
- [ ] AI 意图识别

### 桌面客户端
- [ ] 系统托盘
- [ ] 全局快捷键
- [ ] 窗口管理
- [ ] 开机自启

### 多渠道
- [ ] Telegram Bot
- [ ] WhatsApp (可选)
- [ ] Slack (可选)
- [ ] Discord (可选)

### 集成测试
- [ ] 跨平台消息
- [ ] 并发处理
- [ ] 错误恢复
- [ ] 性能稳定

### UI/UX
- [ ] 原生 Mac 风格
- [ ] 响应式设计
- [ ] 加载状态
- [ ] 错误提示

---

## 📊 测试报告模板

```markdown
## 测试报告 - [日期]

### 测试环境
- OS: macOS 14.0
- Flutter: 3.x.x
- Dart: 3.x.x

### 测试结果
- 总场景: 10
- 通过: X
- 失败: Y
- 跳过: Z

### 发现的问题
1. [问题描述]
2. [问题描述]

### 建议
1. [改进建议]
2. [改进建议]
```

---

## 🔄 持续测试

### 自动化测试脚本
```bash
#!/bin/bash
# test-all.sh

echo "🧪 OpenCLI 端到端测试"

# 1. 启动 Daemon
echo "启动 Daemon..."
cd daemon && dart bin/daemon.dart &
DAEMON_PID=$!
sleep 5

# 2. 运行集成测试
echo "运行集成测试..."
cd ../tests/integration
dart test

# 3. 清理
echo "清理..."
kill $DAEMON_PID

echo "✅ 测试完成"
```

### CI/CD 集成
- 每次提交自动运行测试
- 生成测试报告
- 性能基准对比

---

**测试负责人**: [姓名]
**最后更新**: 2026-02-02
**下次测试**: 每周一
