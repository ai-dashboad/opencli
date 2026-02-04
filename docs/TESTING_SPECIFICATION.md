# OpenCLI 完整测试规范

**版本**: 1.0
**创建日期**: 2026-02-04
**目的**: 建立严格的测试标准，确保所有功能经过完整验证

---

## 📋 测试原则

### 核心原则

1. **零假设原则**: 假设所有功能都不可用，直到经过实际验证
2. **完整性原则**: 每个功能必须从用户视角进行端到端测试
3. **可重复性原则**: 所有测试必须可重复执行，有明确的步骤
4. **独立性原则**: 每个测试独立验证，不依赖其他测试结果
5. **真实性原则**: 使用真实环境、真实设备、真实用户操作

### 通过标准

功能只有在满足以下所有条件时才算**通过**：

1. ✅ 功能可以启动/访问
2. ✅ 用户可以正常交互（点击、输入）
3. ✅ 功能返回正确结果
4. ✅ 错误处理正常
5. ✅ 性能符合预期

### 失败标准

以下任一情况即判定为**失败**：

1. ❌ 无法启动/访问
2. ❌ UI无响应或无法点击
3. ❌ 功能返回错误结果
4. ❌ 崩溃或异常
5. ❌ 性能严重不达标

---

## 🎯 测试分类

### 1. 后端服务测试 (Backend Tests)

验证后端API和服务的可用性

### 2. 前端应用测试 (Frontend Tests)

验证用户界面的交互和功能

### 3. 集成测试 (Integration Tests)

验证端到端的完整流程

### 4. 性能测试 (Performance Tests)

验证系统性能指标

---

## 📝 详细测试规范

---

## 第一部分: 后端服务测试

### Test-Backend-01: Daemon进程启动

**测试目标**: 验证daemon可以正常启动并保持运行

**前置条件**:
- Dart SDK已安装
- daemon代码已编译

**测试步骤**:
```bash
# 1. 清理环境
pkill -f daemon.dart

# 2. 启动daemon
cd daemon
dart run bin/daemon.dart --mode personal > /tmp/daemon-test.log 2>&1 &
DAEMON_PID=$!

# 3. 等待启动
sleep 5

# 4. 验证进程存在
ps -p $DAEMON_PID
```

**验收标准**:
- ✅ 进程成功启动（exit code 0）
- ✅ 进程持续运行（ps命令返回进程信息）
- ✅ 日志中没有ERROR或FATAL
- ✅ 启动时间 < 10秒

**失败情况**:
- ❌ 进程启动失败
- ❌ 进程启动后立即退出
- ❌ 日志中有ERROR
- ❌ 启动时间 > 10秒

**测试脚本**: `tests/backend/test_daemon_startup.sh`

---

### Test-Backend-02: 健康检查端点

**测试目标**: 验证HTTP健康检查端点正常响应

**前置条件**:
- Daemon正在运行

**测试步骤**:
```bash
# 1. 发送健康检查请求
response=$(curl -s -w "\n%{http_code}" http://localhost:9875/health)
body=$(echo "$response" | head -n -1)
status=$(echo "$response" | tail -n 1)

# 2. 验证响应
echo "Status: $status"
echo "Body: $body"
```

**验收标准**:
- ✅ HTTP状态码 = 200
- ✅ 响应体包含 "status": "healthy"
- ✅ 响应时间 < 100ms
- ✅ JSON格式正确

**失败情况**:
- ❌ 无法连接（Connection refused）
- ❌ HTTP状态码 != 200
- ❌ 响应体不包含 "healthy"
- ❌ 响应时间 > 100ms

**测试脚本**: `tests/backend/test_health_endpoint.sh`

---

### Test-Backend-03: WebSocket连接

**测试目标**: 验证WebSocket端点可以建立连接

**前置条件**:
- Daemon正在运行

**测试步骤**:
```bash
# 运行WebSocket客户端示例
cd daemon
timeout 10 dart run test/websocket_client_example.dart > /tmp/ws-test.log 2>&1

# 检查输出
cat /tmp/ws-test.log
```

**验收标准**:
- ✅ 成功连接到 ws://localhost:9875/ws
- ✅ 收到欢迎消息 (type: notification, event: connected)
- ✅ 获得客户端ID
- ✅ 可以发送和接收消息
- ✅ 消息格式符合OpenCLIMessage协议

**失败情况**:
- ❌ 连接失败
- ❌ 未收到欢迎消息
- ❌ 消息格式错误
- ❌ 连接意外断开

**测试脚本**: `tests/backend/test_websocket_connection.sh`

---

### Test-Backend-04: AI模型API

**测试目标**: 验证AI模型管理API正常工作

**前置条件**:
- Daemon正在运行
- WebSocket已连接

**测试步骤**:
```bash
# 通过WebSocket客户端请求模型列表
# (使用测试脚本)
```

**验收标准**:
- ✅ 请求成功（status: success）
- ✅ 返回模型列表（至少1个模型）
- ✅ 每个模型包含 id, name, provider, available
- ✅ 响应时间 < 500ms

**失败情况**:
- ❌ 请求失败
- ❌ 返回空列表
- ❌ 数据格式不正确

**测试脚本**: `tests/backend/test_ai_models_api.sh`

---

### Test-Backend-05: 任务管理API

**测试目标**: 验证任务提交、进度、完成全流程

**前置条件**:
- Daemon正在运行
- WebSocket已连接

**测试步骤**:
```bash
# 1. 提交任务
# 2. 等待进度通知
# 3. 等待完成通知
# 4. 验证结果
```

**验收标准**:
- ✅ 任务提交成功
- ✅ 收到进度通知（至少1次）
- ✅ 收到完成通知
- ✅ 任务结果正确
- ✅ 完整流程 < 10秒

**失败情况**:
- ❌ 任务提交失败
- ❌ 未收到通知
- ❌ 任务超时
- ❌ 结果错误

**测试脚本**: `tests/backend/test_task_lifecycle.sh`

---

## 第二部分: 前端应用测试

### Test-Frontend-01: Menubar应用启动

**测试目标**: 验证menubar应用可以启动并显示图标

**前置条件**:
- macOS系统
- Flutter已安装
- Daemon正在运行

**测试步骤**:
```bash
# 1. 清理现有进程
pkill -f opencli_app.app

# 2. 启动应用
cd opencli_app
flutter run -d macos > /tmp/menubar-test.log 2>&1 &
FLUTTER_PID=$!

# 3. 等待启动
sleep 10

# 4. 验证进程
ps -p $FLUTTER_PID

# 5. 检查日志
grep -i "error\|exception" /tmp/menubar-test.log
```

**验收标准**:
- ✅ 应用成功启动
- ✅ menubar中显示图标
- ✅ 图标可点击
- ✅ 日志无ERROR

**失败情况**:
- ❌ 应用启动失败
- ❌ menubar无图标
- ❌ 图标不可点击

**手动验证**:
1. 在macOS菜单栏找到OpenCLI图标
2. 点击图标，菜单应该弹出

**测试脚本**: `tests/frontend/test_menubar_startup.sh`

---

### Test-Frontend-02: Menubar菜单交互 ⚠️ **关键测试**

**测试目标**: 验证menubar所有菜单项可以点击并执行

**前置条件**:
- Menubar应用正在运行
- Daemon正在运行

**测试步骤** (手动):

#### Step 1: 验证菜单显示
1. 点击menubar图标
2. 确认菜单弹出
3. 记录菜单项列表

#### Step 2: 测试每个菜单项

**2.1 AI Models**
```
操作: 点击 "AI Models" 菜单项
预期: 打开主窗口，显示AI模型列表
验证: □ 窗口打开
      □ 模型列表显示
      □ 无错误
```

**2.2 Dashboard**
```
操作: 点击 "Dashboard" 菜单项
预期: 在浏览器打开 http://localhost:3000/dashboard
验证: □ 浏览器打开
      □ URL正确
      □ 页面加载成功
```

**2.3 Web UI**
```
操作: 点击 "Web UI" 菜单项
预期: 在浏览器打开 http://localhost:3000
验证: □ 浏览器打开
      □ URL正确
      □ 页面加载成功
```

**2.4 Settings**
```
操作: 点击 "Settings" 菜单项
预期: 打开主窗口，显示设置页面
验证: □ 窗口打开
      □ 设置界面显示
      □ 无错误
```

**2.5 Refresh Status**
```
操作: 点击 "Refresh Status" 菜单项
预期: 状态信息立即更新
验证: □ 菜单无反应（正常，后台刷新）
      □ 3秒后再次打开菜单，数据已更新
```

**2.6 Quit**
```
操作: 点击 "Quit" 菜单项
预期: 应用退出
验证: □ 应用进程结束
      □ menubar图标消失
```

**验收标准**:
- ✅ 所有6个菜单项都可以点击
- ✅ 每个菜单项执行正确的操作
- ✅ 无崩溃或错误
- ✅ 菜单响应时间 < 500ms

**失败情况**:
- ❌ 任何菜单项无法点击
- ❌ 点击后无反应
- ❌ 点击后应用崩溃
- ❌ 执行了错误的操作

**测试检查表**: `tests/frontend/menubar_checklist.md`

---

### Test-Frontend-03: Android应用完整功能测试 ⚠️ **关键测试**

**测试目标**: 验证Android应用所有功能正常工作

**前置条件**:
- Android模拟器或真机已连接
- Daemon正在运行
- Flutter已安装

**测试步骤**:

#### Phase 1: 应用启动
```bash
# 1. 清理旧应用
adb uninstall com.opencli.mobile

# 2. 安装并启动
cd opencli_app
flutter run -d emulator-5554 > /tmp/android-test.log 2>&1 &
FLUTTER_PID=$!

# 3. 等待启动
sleep 30
```

**验证点**:
- ✅ 应用成功安装
- ✅ 应用启动无崩溃
- ✅ 日志显示 "Connected to daemon"
- ✅ 无 "Connection refused" 错误

#### Phase 2: 连接验证
```
手动操作:
1. 在Android设备上查看应用界面
2. 确认显示 "Connected" 或连接成功提示
3. 检查状态指示器（如果有）
```

**验证点**:
- ✅ UI显示连接成功
- ✅ 状态指示器为绿色/在线

#### Phase 3: 消息发送测试
```
手动操作:
1. 在聊天界面输入 "Hello test"
2. 点击发送按钮
3. 等待响应
```

**验证点**:
- ✅ 输入框可以输入
- ✅ 发送按钮可以点击
- ✅ 消息显示在界面上
- ✅ 收到AI响应（或确认消息）
- ✅ 响应时间 < 10秒

#### Phase 4: 导航测试
```
手动操作:
1. 点击所有可见的标签/按钮
2. 测试页面切换
3. 返回主页
```

**验证点**:
- ✅ 所有按钮可点击
- ✅ 页面切换流畅
- ✅ 导航正常

#### Phase 5: 任务提交测试 (如果有此功能)
```
手动操作:
1. 打开任务提交界面
2. 创建一个测试任务
3. 提交
4. 查看进度
```

**验证点**:
- ✅ 任务提交成功
- ✅ 进度显示更新
- ✅ 完成后显示结果

**验收标准**:
- ✅ 所有5个测试阶段全部通过
- ✅ 无崩溃
- ✅ 所有UI可交互
- ✅ 功能符合预期

**失败情况**:
- ❌ 任何阶段失败
- ❌ 崩溃或ANR
- ❌ UI无响应
- ❌ 功能不工作

**测试检查表**: `tests/frontend/android_checklist.md`

---

### Test-Frontend-04: iOS应用完整功能测试 ⚠️ **关键测试**

**测试目标**: 验证iOS应用所有功能正常工作

**前置条件**:
- iOS模拟器或真机已连接
- Daemon正在运行
- Flutter已安装

**测试步骤**: (与Android测试相同的5个阶段)

#### Phase 1: 应用启动
#### Phase 2: 连接验证
#### Phase 3: 消息发送测试
#### Phase 4: 导航测试
#### Phase 5: 任务提交测试

**验收标准**: (与Android相同)

**测试检查表**: `tests/frontend/ios_checklist.md`

---

### Test-Frontend-05: WebUI完整功能测试 ⚠️ **关键测试**

**测试目标**: 验证WebUI所有功能正常工作

**前置条件**:
- WebUI服务器运行在 http://localhost:3000
- Daemon正在运行

**测试步骤**:

#### Phase 1: 访问WebUI
```bash
# 启动WebUI服务器
cd web-ui
npm run dev > /tmp/webui-test.log 2>&1 &

# 等待启动
sleep 10

# 在浏览器打开
open http://localhost:3000
```

**验证点**:
- ✅ 页面加载成功
- ✅ 无控制台错误
- ✅ UI渲染正常

#### Phase 2: WebSocket连接测试
```
手动操作:
1. 打开 http://localhost:3000 或 websocket-test.html
2. 点击 "Connect" 按钮
3. 观察连接状态
```

**验证点**:
- ✅ 连接按钮可点击
- ✅ 状态变为 "Connected" (绿色)
- ✅ 收到欢迎消息
- ✅ 消息日志显示连接详情

#### Phase 3: 功能按钮测试
```
手动操作:
1. 点击 "Get Status" 按钮
2. 点击 "Send Chat Message" 按钮
3. 点击 "Submit Task" 按钮
4. 点击 "Invalid JSON Test" 按钮
```

**验证点**:
- ✅ 所有按钮可点击
- ✅ 每个按钮发送正确的消息
- ✅ 收到预期的响应
- ✅ 消息日志正确显示

#### Phase 4: 自定义消息测试
```
手动操作:
1. 在自定义消息框输入JSON
2. 点击 "Send Custom Message"
3. 查看响应
```

**验证点**:
- ✅ 可以输入JSON
- ✅ 发送按钮可点击
- ✅ 收到响应

#### Phase 5: 错误处理测试
```
手动操作:
1. 发送Invalid JSON
2. 停止daemon
3. 尝试重新连接
```

**验证点**:
- ✅ 显示错误消息
- ✅ 检测到断线
- ✅ 可以重新连接

**验收标准**:
- ✅ 所有5个测试阶段全部通过
- ✅ 所有按钮可用
- ✅ 功能符合预期
- ✅ 错误处理正确

**失败情况**:
- ❌ 任何阶段失败
- ❌ 按钮无响应
- ❌ 功能不工作

**测试检查表**: `tests/frontend/webui_checklist.md`

---

## 第三部分: 集成测试

### Test-Integration-01: 端到端聊天流程

**测试目标**: 验证从移动端发送消息到AI响应的完整流程

**测试步骤**:
1. 启动daemon
2. 启动Android/iOS app
3. 发送聊天消息
4. 验证AI响应
5. 检查消息历史

**验收标准**:
- ✅ 完整流程无中断
- ✅ 响应时间 < 30秒
- ✅ 消息正确保存

---

### Test-Integration-02: 多客户端同步

**测试目标**: 验证多个客户端之间的消息同步

**测试步骤**:
1. 同时连接Android、iOS、WebUI
2. 在Android提交任务
3. 验证iOS和WebUI收到通知

**验收标准**:
- ✅ 所有客户端收到通知
- ✅ 数据同步一致
- ✅ 延迟 < 1秒

---

## 第四部分: 性能测试

### Test-Performance-01: 响应时间

**测试目标**: 验证API响应时间符合预期

**测试指标**:
- Health endpoint: < 100ms
- WebSocket连接: < 1s
- AI响应: < 30s
- Task提交: < 500ms

---

### Test-Performance-02: 并发连接

**测试目标**: 验证系统支持多个并发连接

**测试步骤**:
1. 同时连接10个客户端
2. 每个客户端发送请求
3. 验证所有响应

**验收标准**:
- ✅ 所有连接成功
- ✅ 所有请求得到响应
- ✅ 无连接被拒绝

---

## 📊 测试报告模板

### 测试执行报告

```markdown
# OpenCLI 测试执行报告

**测试日期**: YYYY-MM-DD
**测试人员**: 姓名
**测试环境**: macOS/Android/iOS

## 后端服务测试 (5项)

| ID | 测试项 | 状态 | 备注 |
|----|--------|------|------|
| Backend-01 | Daemon启动 | ✅/❌ | |
| Backend-02 | 健康检查 | ✅/❌ | |
| Backend-03 | WebSocket | ✅/❌ | |
| Backend-04 | AI模型API | ✅/❌ | |
| Backend-05 | 任务管理API | ✅/❌ | |

**后端通过率**: X/5 (XX%)

## 前端应用测试 (5项)

| ID | 测试项 | 状态 | 备注 |
|----|--------|------|------|
| Frontend-01 | Menubar启动 | ✅/❌ | |
| Frontend-02 | Menubar交互 | ✅/❌ | |
| Frontend-03 | Android功能 | ✅/❌ | |
| Frontend-04 | iOS功能 | ✅/❌ | |
| Frontend-05 | WebUI功能 | ✅/❌ | |

**前端通过率**: X/5 (XX%)

## 集成测试 (2项)

| ID | 测试项 | 状态 | 备注 |
|----|--------|------|------|
| Integration-01 | 端到端聊天 | ✅/❌ | |
| Integration-02 | 多客户端同步 | ✅/❌ | |

**集成测试通过率**: X/2 (XX%)

## 总体统计

- **总测试项**: 12
- **通过**: X
- **失败**: X
- **未测试**: X
- **总体通过率**: XX%

## 严重问题

1. [如果有]
2. [如果有]

## 建议

[测试建议]

## 结论

系统状态: ✅ 可发布 / ⚠️ 需修复 / ❌ 不可用
```

---

## 🔧 测试工具和脚本

### 自动化测试脚本

创建 `tests/run_all_tests.sh`:

```bash
#!/bin/bash
# OpenCLI 自动化测试套件

echo "🧪 OpenCLI Automated Test Suite"
echo "================================"

# 计数器
TOTAL=0
PASSED=0
FAILED=0

# 运行测试
run_test() {
    local name=$1
    local script=$2

    TOTAL=$((TOTAL + 1))
    echo ""
    echo "[$TOTAL] Testing: $name"

    if bash "$script"; then
        echo "✅ PASSED: $name"
        PASSED=$((PASSED + 1))
    else
        echo "❌ FAILED: $name"
        FAILED=$((FAILED + 1))
    fi
}

# 后端测试
echo ""
echo "## 后端测试"
run_test "Daemon启动" "backend/test_daemon_startup.sh"
run_test "健康检查" "backend/test_health_endpoint.sh"
run_test "WebSocket连接" "backend/test_websocket_connection.sh"

# 前端测试需要手动
echo ""
echo "## 前端测试"
echo "⚠️  前端测试需要手动执行，请参考检查清单"

# 总结
echo ""
echo "================================"
echo "测试完成"
echo "总计: $TOTAL"
echo "通过: $PASSED"
echo "失败: $FAILED"
echo "通过率: $((PASSED * 100 / TOTAL))%"
echo "================================"

if [ $FAILED -eq 0 ]; then
    echo "✅ 所有自动化测试通过"
    exit 0
else
    echo "❌ 有 $FAILED 个测试失败"
    exit 1
fi
```

---

## 📋 手动测试检查清单

创建 `tests/MANUAL_TEST_CHECKLIST.md`:

```markdown
# OpenCLI 手动测试检查清单

**测试日期**: __________
**测试人员**: __________

## Menubar应用测试

### 启动
- [ ] menubar图标显示
- [ ] 图标可点击
- [ ] 菜单弹出

### 菜单项
- [ ] AI Models - 点击后打开窗口
- [ ] Dashboard - 点击后打开浏览器
- [ ] Web UI - 点击后打开浏览器
- [ ] Settings - 点击后打开窗口
- [ ] Refresh - 点击后状态更新
- [ ] Quit - 点击后应用退出

**结果**: ___/6 通过

## Android应用测试

### 启动和连接
- [ ] 应用成功启动
- [ ] 显示连接成功
- [ ] 无崩溃

### 功能
- [ ] 可以输入消息
- [ ] 发送按钮可点击
- [ ] 收到响应
- [ ] 导航正常
- [ ] 任务提交正常

**结果**: ___/8 通过

## iOS应用测试

### 启动和连接
- [ ] 应用成功启动
- [ ] 显示连接成功
- [ ] 无崩溃

### 功能
- [ ] 可以输入消息
- [ ] 发送按钮可点击
- [ ] 收到响应
- [ ] 导航正常
- [ ] 任务提交正常

**结果**: ___/8 通过

## WebUI测试

### 连接
- [ ] 页面加载成功
- [ ] Connect按钮可点击
- [ ] 连接成功（绿色）

### 功能
- [ ] Get Status可用
- [ ] Send Chat可用
- [ ] Submit Task可用
- [ ] 自定义消息可用
- [ ] 错误处理正确

**结果**: ___/8 通过

---

## 总体评估

- Menubar: ___/6
- Android: ___/8
- iOS: ___/8
- WebUI: ___/8

**总计**: ___/30 (___%)

## 通过标准

- 100%: ✅ 完全通过，可发布
- 90-99%: ⚠️ 基本可用，有小问题
- 80-89%: ⚠️ 可用但需改进
- <80%: ❌ 不可用，需修复

## 结论

系统状态: _____________
```

---

## 🎯 使用流程

### 完整测试流程

```bash
# 1. 运行自动化测试
cd tests
./run_all_tests.sh

# 2. 执行手动测试
# 使用 MANUAL_TEST_CHECKLIST.md

# 3. 生成报告
# 填写测试报告模板

# 4. 评估结果
# 根据通过率判断系统状态
```

---

## 📌 关键规则

### 1. 不做假设
- ❌ 不要假设"API返回200就是成功"
- ✅ 必须验证实际功能可用

### 2. 完整验证
- ❌ 不要只测试"连接"就算完成
- ✅ 必须测试完整的用户流程

### 3. 真实环境
- ❌ 不要只在模拟器测试
- ✅ 尽可能在真机测试

### 4. 独立测试
- ❌ 不要说"后端通过了所以前端应该也行"
- ✅ 每个部分独立验证

### 5. 诚实报告
- ❌ 不要隐藏失败的测试
- ✅ 如实报告所有问题

---

## 📅 版本历史

- **v1.0** (2026-02-04): 初始版本，建立完整测试规范

---

**重要提醒**:

> 只有完成所有测试项并且通过率达到要求，才能宣称系统"可用"或"测试通过"。
>
> **没有捷径，没有假设，只有严格的验证。**
