#!/bin/bash
# Test-Frontend-01: macOS Menubar应用测试
# 验证菜单栏应用启动、状态显示、菜单项功能

set -e

echo "=========================================="
echo "Test-Frontend-01: macOS Menubar应用测试"
echo "=========================================="
echo ""

# 确保 Daemon 运行
if ! lsof -i :9875 > /dev/null 2>&1; then
    echo "❌ FAILED: Daemon未运行，请先启动daemon"
    exit 1
fi

echo "⚠️  这是一个半自动测试，需要手动验证UI"
echo ""

# 清理旧进程
echo "1️⃣  清理旧Menubar进程..."
pkill -f "opencli_app.app/Contents/MacOS/opencli_app" || true
sleep 2

# 启动 Menubar App
echo "2️⃣  启动Menubar应用..."
cd "$(dirname "$0")/../../opencli_app"
nohup flutter run -d macos > /tmp/opencli-menubar-test.log 2>&1 &
MENUBAR_PID=$!
echo "   进程PID: $MENUBAR_PID"

echo ""
echo "3️⃣  等待应用启动 (15秒)..."
sleep 15

# 检查进程
if ps -p $MENUBAR_PID > /dev/null; then
    echo "   ✅ Menubar进程运行中"
else
    echo "   ❌ FAILED: Menubar进程未运行"
    tail -30 /tmp/opencli-menubar-test.log
    exit 1
fi

# 检查日志
echo ""
echo "4️⃣  检查启动日志..."
if grep -q "Initializing system tray" /tmp/opencli-menubar-test.log; then
    echo "   ✅ 托盘初始化日志正常"
else
    echo "   ⚠️  WARNING: 未找到托盘初始化日志"
fi

if grep -q "Connected to daemon" /tmp/opencli-menubar-test.log || grep -q "Fetching daemon status" /tmp/opencli-menubar-test.log; then
    echo "   ✅ Daemon连接日志正常"
else
    echo "   ⚠️  WARNING: 未找到daemon连接日志"
fi

# 手动测试提示
echo ""
echo "=========================================="
echo "📋 请手动验证以下项目:"
echo "=========================================="
echo ""
echo "A. 应用启动 (3项):"
echo "   ☐ 1. menubar图标显示"
echo "   ☐ 2. 图标可点击"
echo "   ☐ 3. 菜单正常弹出"
echo ""
echo "B. 状态显示 (4项):"
echo "   ☐ 4. 显示运行状态 (Running/Offline)"
echo "   ☐ 5. 显示版本号 (v0.x.x)"
echo "   ☐ 6. 显示运行时间 (Xh Xm)"
echo "   ☐ 7. 显示客户端数量 (X clients)"
echo ""
echo "C. 菜单项功能 (6项):"
echo "   ☐ 8. AI Models - 主窗口打开"
echo "   ☐ 9. Dashboard - 浏览器打开 localhost:3000/dashboard"
echo "   ☐ 10. Web UI - 浏览器打开 localhost:3000"
echo "   ☐ 11. Settings - 设置窗口打开"
echo "   ☐ 12. Refresh Status - 状态数据更新"
echo "   ☐ 13. Quit - 应用退出，图标消失"
echo ""
echo "=========================================="
echo "提示: 如果菜单项无法点击，运行:"
echo "  ./scripts/restart_menubar.sh"
echo "=========================================="
echo ""

# 等待用户确认
read -p "按Enter键继续验证，或Ctrl+C退出..."

# 检查最新日志
echo ""
echo "5️⃣  检查运行时日志..."
echo "   最近10条日志:"
tail -10 /tmp/opencli-menubar-test.log | grep -v "^$" || echo "   (无新日志)"

# 询问测试结果
echo ""
read -p "所有手动测试是否通过? (y/n): " MANUAL_RESULT

if [ "$MANUAL_RESULT" = "y" ] || [ "$MANUAL_RESULT" = "Y" ]; then
    echo ""
    echo "=========================================="
    echo "✅ Test-Frontend-01: PASSED"
    echo "=========================================="
    exit 0
else
    echo ""
    echo "=========================================="
    echo "❌ Test-Frontend-01: FAILED (手动测试未通过)"
    echo "=========================================="
    exit 1
fi
