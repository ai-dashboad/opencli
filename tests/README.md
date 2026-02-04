# OpenCLI 测试套件

完整的自动化和半自动测试框架，用于验证 OpenCLI 系统的所有组件。

## 📁 目录结构

```
tests/
├── README.md                      # 本文件
├── run_all_tests.sh              # 主测试运行器
├── MANUAL_TEST_CHECKLIST.md      # 71项手动测试清单
│
├── backend/                      # Backend自动化测试
│   ├── test_daemon_startup.sh    # Test-Backend-01: Daemon启动
│   ├── test_health_endpoint.sh   # Test-Backend-02: 健康检查
│   └── test_websocket_connection.sh # Test-Backend-03: WebSocket连接
│
├── frontend/                     # Frontend半自动测试
│   ├── test_menubar.sh          # Test-Frontend-01: macOS Menubar
│   ├── test_android.sh          # Test-Frontend-02: Android应用
│   ├── test_ios.sh              # Test-Frontend-03: iOS应用
│   └── test_webui.sh            # Test-Frontend-04: WebUI
│
├── e2e/                         # E2E自动化测试
│   ├── mobile_to_ai_flow_test.dart
│   ├── task_submission_test.dart
│   ├── multi_client_sync_test.dart
│   ├── error_handling_test.dart
│   ├── performance_test.dart
│   └── helpers/
│       └── test_helpers.dart
│
└── test-results/                # 测试报告输出
    ├── REAL_ENVIRONMENT_TEST_REPORT.md
    ├── FINAL_REAL_ENVIRONMENT_TEST_REPORT.md
    └── test_run_YYYYMMDD_HHMMSS.md
```

## 🚀 快速开始

### 运行所有测试

```bash
cd tests
./run_all_tests.sh
```

这将按顺序运行:
1. Backend自动化测试 (3项)
2. Frontend半自动测试 (4项，需要手动验证UI)
3. E2E自动化测试 (5项)
4. 性能测试 (待实现)

### 运行单个测试

**Backend测试:**
```bash
# Daemon启动测试
./backend/test_daemon_startup.sh

# 健康检查测试
./backend/test_health_endpoint.sh

# WebSocket连接测试
./backend/test_websocket_connection.sh
```

**Frontend测试:**
```bash
# macOS Menubar测试
./frontend/test_menubar.sh

# Android应用测试
./frontend/test_android.sh

# iOS应用测试
./frontend/test_ios.sh

# WebUI测试
./frontend/test_webui.sh
```

**E2E测试:**
```bash
cd e2e
dart test mobile_to_ai_flow_test.dart
dart test task_submission_test.dart
# ... 等等
```

## 📋 测试类型

### 1. Backend自动化测试 (100% 自动化)

| 测试 | 脚本 | 验证内容 |
|------|------|----------|
| Test-Backend-01 | test_daemon_startup.sh | Daemon启动、端口监听、进程稳定性 |
| Test-Backend-02 | test_health_endpoint.sh | /health、/status端点响应 |
| Test-Backend-03 | test_websocket_connection.sh | WebSocket连接、欢迎消息 |

### 2. Frontend半自动测试 (需要手动验证UI)

| 测试 | 脚本 | 验证内容 | 测试项数 |
|------|------|----------|----------|
| Test-Frontend-01 | test_menubar.sh | Menubar启动、菜单点击 | 13项 |
| Test-Frontend-02 | test_android.sh | Android连接、消息发送 | 20项 |
| Test-Frontend-03 | test_ios.sh | iOS连接、消息发送 | 20项 |
| Test-Frontend-04 | test_webui.sh | WebUI连接、按钮功能 | 18项 |

**为什么是半自动?**
- 脚本自动启动应用和检查日志
- 但UI交互（点击、输入）需要人工验证
- 这是因为Flutter UI自动化测试需要额外配置

### 3. E2E自动化测试 (需要修复)

| 测试文件 | 测试项数 | 状态 |
|----------|----------|------|
| mobile_to_ai_flow_test.dart | 5 | ⚠️ 协议不匹配 |
| task_submission_test.dart | 6 | ⚠️ 协议不匹配 |
| multi_client_sync_test.dart | 5 | ⚠️ 协议不匹配 |
| error_handling_test.dart | 10 | ⚠️ 协议不匹配 |
| performance_test.dart | 9 | ⚠️ 协议不匹配 |

**已知问题**: E2E测试使用简化消息格式，但Daemon要求完整的 `OpenCLIMessage` 格式。

**修复方法**: 更新 `e2e/helpers/test_helpers.dart` 使用正确的协议。

## 🎯 测试前提条件

### 必需条件

1. **Dart SDK**: 3.10.8+
2. **Flutter SDK**: 3.41.0+ (beta)
3. **依赖安装**:
   ```bash
   cd daemon && dart pub get
   cd opencli_app && flutter pub get
   cd tests/e2e && dart pub get
   ```

### 可选条件 (根据测试类型)

**Android测试**:
- Android模拟器或真机
- 运行: `flutter devices` 确认设备可用

**iOS测试**:
- macOS系统
- Xcode已安装
- iOS模拟器: `open -a Simulator`

**macOS Menubar测试**:
- macOS系统
- Flutter macOS桌面支持

## 📊 测试报告

### 自动生成的报告

运行 `./run_all_tests.sh` 后，报告保存在:
```
tests/test-results/test_run_YYYYMMDD_HHMMSS.md
```

报告包含:
- 每个测试的通过/失败状态
- 总体统计和成功率
- 详细的失败原因
- 最终结论和建议

### 手动测试清单

使用 [MANUAL_TEST_CHECKLIST.md](MANUAL_TEST_CHECKLIST.md) 进行完整的手动测试:

```bash
# 打开清单文件
open MANUAL_TEST_CHECKLIST.md

# 或打印出来使用
```

清单包含 **71项测试**，覆盖:
- Menubar: 13项
- Android: 20项
- iOS: 20项
- WebUI: 18项

## 🔧 故障排查

### Daemon无法启动

```bash
# 检查端口占用
lsof -i :9875
lsof -i :9876

# 清理旧进程
pkill -f "dart.*daemon/bin/main.dart"

# 重新启动
cd daemon
dart bin/main.dart
```

### Menubar菜单项无法点击

```bash
# 使用重启脚本
./scripts/restart_menubar.sh
```

**原因**: macOS频繁调用 `setContextMenu` 会导致点击事件失效。

### Android连接被拒绝

**症状**: "Connection refused (errno = 61)"

**原因**: Android模拟器上 `localhost` 指向自己，不是宿主机。

**解决**: 已在代码中修复，使用 `10.0.2.2` 代替 `localhost`。

验证修复:
```bash
# 检查代码
grep -A 5 "_getDefaultHost" opencli_app/lib/services/daemon_service.dart
```

应看到:
```dart
static String _getDefaultHost() {
  if (Platform.isAndroid) {
    return '10.0.2.2';  // ✅ 正确
  }
  return 'localhost';
}
```

### E2E测试超时

**症状**: `TimeoutException: Message not received`

**原因**: 测试使用简化消息格式，daemon需要 `OpenCLIMessage` 格式。

**临时解决**: 使用 `daemon/test/websocket_client_example.dart` 进行手动测试。

**永久解决**: 更新 `e2e/helpers/test_helpers.dart`，导入并使用:
```dart
import 'package:opencli_shared/protocol/message.dart';
```

## 📖 测试规范

完整的测试规范和标准见:
- [docs/TESTING_SPECIFICATION.md](../docs/TESTING_SPECIFICATION.md)

核心原则:
1. **零假设**: 不假设任何功能正常工作
2. **完整性**: 测试所有功能路径
3. **可重复性**: 测试结果一致
4. **独立性**: 测试之间无依赖
5. **真实性**: 在真实环境和设备上测试

## 🎓 测试最佳实践

### 运行测试前

1. 确保daemon已启动:
   ```bash
   cd daemon && dart bin/main.dart
   ```

2. 确保没有旧进程占用端口:
   ```bash
   lsof -i :9875 :9876
   ```

3. 检查设备可用性:
   ```bash
   flutter devices
   ```

### 运行测试时

1. **按顺序运行**: Backend → Frontend → E2E
2. **一次只运行一个Frontend测试**: 避免端口冲突
3. **仔细阅读手动测试提示**: 不要跳过任何验证步骤
4. **如实记录结果**: 不要美化失败的测试

### 运行测试后

1. 查看生成的测试报告
2. 检查日志文件 (在 `/tmp/opencli-*.log`)
3. 清理测试进程:
   ```bash
   pkill -f "opencli"
   pkill -f "flutter run"
   ```

## 📞 获取帮助

如果测试失败:

1. 查看测试日志 (`/tmp/opencli-*.log`)
2. 查看daemon日志
3. 检查 [已知问题](#-故障排查)
4. 提交issue并附上完整日志

## 🎯 测试覆盖率目标

| 组件 | 当前覆盖率 | 目标覆盖率 |
|------|-----------|-----------|
| Backend | 100% | 100% ✅ |
| Frontend | 25%* | 90% |
| E2E | 0%** | 80% |
| 总体 | 40% | 90% |

\* Frontend有脚本但需手动验证UI
\*\* E2E有测试但协议不匹配

---

**最后更新**: 2026-02-04
**版本**: 1.0.0
