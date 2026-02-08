# 🧪 OpenCLI 测试快速开始

**3分钟开始实际测试**

---

## 方式1: 自动化测试脚本（推荐）

```bash
cd /Users/cw/development/opencli
./scripts/run_actual_tests.sh
```

脚本会自动执行：
- ✅ 环境检查
- ✅ 启动daemon
- ✅ 运行35+个E2E测试
- ✅ 生成测试报告

**预计时间**: 15-20分钟（包括交互式测试）

---

## 方式2: 手动逐步测试

### 步骤1: 启动Daemon (必须)

```bash
# 终端1: 启动daemon
cd daemon
dart run bin/daemon.dart --mode personal
```

**验证**: 看到 "Daemon started" 消息

### 步骤2: 运行E2E测试

```bash
# 终端2: 运行E2E测试
cd tests
./run_e2e_tests.sh -v
```

**预期**: 35/35 测试通过 ✅

### 步骤3: 测试WebUI

```bash
# 打开浏览器测试工具
open web-ui/websocket-test.html
```

**操作**:
1. 点击 "Connect"
2. 状态变绿色 ✅
3. 点击 "Get Status"
4. 收到响应消息 ✅

### 步骤4: 测试Android（验证修复）

```bash
# 终端3: 启动Android模拟器
emulator -avd Pixel_7_API_34

# 终端4: 运行Flutter app
cd opencli_app
flutter run
```

**验证**:
- ✅ App启动成功
- ✅ 显示 "Connected" (不再是 Connection refused)
- ✅ 可以发送消息

---

## 方式3: 快速验证（1分钟）

只验证核心功能是否工作：

```bash
# 1. 启动daemon
cd daemon
dart run bin/daemon.dart --mode personal &

# 2. 等待3秒
sleep 3

# 3. 测试健康检查
curl http://localhost:9875/health

# 4. 运行一个E2E测试
cd ../tests
dart test e2e/mobile_to_ai_flow_test.dart
```

**成功输出**:
```
{"status":"healthy"}
00:03 +5: All tests passed!
```

---

## 📊 查看测试结果

测试完成后：

```bash
# 查看最新测试报告
cd test-results
ls -lt | head -5
cd 最新的目录
cat FINAL_REPORT.md
```

---

## 🚨 常见问题

### Daemon无法启动
```bash
cd daemon
dart pub get
dart run bin/daemon.dart --mode personal --verbose
```

### 端口被占用
```bash
lsof -i :9875 | grep LISTEN | awk '{print $2}' | xargs kill -9
```

### 测试超时
```bash
# 检查daemon是否运行
curl http://localhost:9875/health
```

---

## 📚 详细文档

- [完整测试方案](docs/ACTUAL_TESTING_PLAN.md) - 详细测试流程
- [E2E测试文档](tests/README.md) - 测试使用指南
- [测试完成报告](docs/TASKS_COMPLETION_REPORT.md) - 任务完成情况

---

**准备好了吗？运行测试：**

```bash
./scripts/run_actual_tests.sh
```
