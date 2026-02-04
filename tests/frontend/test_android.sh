#!/bin/bash
# Test-Frontend-02: Android应用测试
# 验证Android应用启动、连接、消息发送

set -e

echo "=========================================="
echo "Test-Frontend-02: Android应用测试"
echo "=========================================="
echo ""

# 确保 Daemon 运行
if ! lsof -i :9875 > /dev/null 2>&1; then
    echo "❌ FAILED: Daemon未运行，请先启动daemon"
    exit 1
fi

# 检查Android设备
echo "1️⃣  检查Android设备/模拟器..."
DEVICES=$(flutter devices 2>/dev/null | grep -E "android|emulator" || true)

if [ -z "$DEVICES" ]; then
    echo "   ❌ FAILED: 未找到Android设备/模拟器"
    echo "   请启动模拟器或连接真机"
    exit 1
fi

echo "   找到设备:"
echo "$DEVICES"
echo ""

# 选择设备
DEVICE_ID=$(echo "$DEVICES" | head -1 | awk '{print $NF}' | tr -d '()')
echo "   使用设备: $DEVICE_ID"

# 启动应用
echo ""
echo "2️⃣  启动Android应用..."
cd "$(dirname "$0")/../../opencli_app"
nohup flutter run -d "$DEVICE_ID" > /tmp/opencli-android-test.log 2>&1 &
ANDROID_PID=$!
echo "   进程PID: $ANDROID_PID"

echo ""
echo "3️⃣  等待应用构建和启动 (可能需要2-5分钟)..."
echo "   监控日志: tail -f /tmp/opencli-android-test.log"
sleep 30

# 检查构建状态
echo ""
echo "4️⃣  检查构建状态..."
if grep -q "Built build/app/outputs/flutter-apk/app-debug.apk" /tmp/opencli-android-test.log; then
    echo "   ✅ APK构建成功"
elif grep -q "Installing" /tmp/opencli-android-test.log; then
    echo "   ✅ 正在安装..."
else
    echo "   ⚠️  构建可能仍在进行，请查看日志"
fi

# 等待更多时间
echo ""
echo "5️⃣  等待应用完全启动 (60秒)..."
sleep 60

# 检查连接日志
echo ""
echo "6️⃣  检查daemon连接..."
if grep -q "Connected to daemon at ws://10.0.2.2:9876" /tmp/opencli-android-test.log; then
    echo "   ✅ Android已连接到daemon (使用10.0.2.2)"
elif grep -q "Connection refused" /tmp/opencli-android-test.log; then
    echo "   ❌ FAILED: 连接被拒绝"
    echo "   请确认daemon正在运行"
    tail -20 /tmp/opencli-android-test.log
    exit 1
else
    echo "   ⚠️  未找到明确的连接日志，可能还在启动中"
fi

# 手动测试提示
echo ""
echo "=========================================="
echo "📋 请在Android设备上手动验证以下项目:"
echo "=========================================="
echo ""
echo "A. 应用启动 (4项):"
echo "   ☐ 1. APK安装成功"
echo "   ☐ 2. 应用启动无崩溃"
echo "   ☐ 3. UI正常渲染"
echo "   ☐ 4. 无黑屏/白屏"
echo ""
echo "B. 连接测试 (4项):"
echo "   ☐ 5. 显示连接中状态"
echo "   ☐ 6. 连接成功提示"
echo "   ☐ 7. 状态指示器显示在线"
echo "   ☐ 8. 无Connection refused错误 (检查logcat)"
echo ""
echo "C. 消息发送 (5项):"
echo "   ☐ 9. 输入框可以输入文字"
echo "   ☐ 10. 发送按钮可点击"
echo "   ☐ 11. 消息显示在界面"
echo "   ☐ 12. 收到AI响应 (30秒内)"
echo "   ☐ 13. 响应正确显示"
echo ""
echo "D. 导航测试 (4项):"
echo "   ☐ 14. 底部导航可点击"
echo "   ☐ 15. 页面切换流畅"
echo "   ☐ 16. 返回键正常"
echo "   ☐ 17. 抽屉菜单(如有)可用"
echo ""
echo "=========================================="
echo "提示: 查看完整日志:"
echo "  tail -f /tmp/opencli-android-test.log"
echo "=========================================="
echo ""

# 等待用户确认
read -p "按Enter键继续验证，或Ctrl+C退出..."

# 检查最新日志
echo ""
echo "7️⃣  检查运行时日志..."
echo "   最近15条日志:"
tail -15 /tmp/opencli-android-test.log | grep -v "^$" || echo "   (无新日志)"

# 询问测试结果
echo ""
read -p "所有手动测试是否通过? (y/n): " MANUAL_RESULT

if [ "$MANUAL_RESULT" = "y" ] || [ "$MANUAL_RESULT" = "Y" ]; then
    echo ""
    echo "=========================================="
    echo "✅ Test-Frontend-02: PASSED"
    echo "=========================================="
    exit 0
else
    echo ""
    echo "=========================================="
    echo "❌ Test-Frontend-02: FAILED (手动测试未通过)"
    echo "=========================================="
    exit 1
fi
