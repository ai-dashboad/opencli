#!/bin/bash
# Test-Backend-01: Daemon启动测试
# 验证 Daemon 可以成功启动并监听正确的端口

set -e

echo "=========================================="
echo "Test-Backend-01: Daemon启动测试"
echo "=========================================="
echo ""

# 清理之前的进程
echo "1️⃣  清理旧进程..."
pkill -f "dart.*daemon/bin/main.dart" || true
sleep 2

# 启动 Daemon
echo "2️⃣  启动 Daemon..."
cd "$(dirname "$0")/../../daemon"
nohup dart bin/main.dart > /tmp/opencli-test-daemon.log 2>&1 &
DAEMON_PID=$!
echo "   Daemon PID: $DAEMON_PID"
sleep 3

# 检查进程是否运行
echo "3️⃣  验证进程状态..."
if ps -p $DAEMON_PID > /dev/null; then
    echo "   ✅ Daemon进程运行中 (PID: $DAEMON_PID)"
else
    echo "   ❌ FAILED: Daemon进程未运行"
    exit 1
fi

# 检查端口监听
echo "4️⃣  验证端口监听..."
PORTS_OK=true

if lsof -i :9875 > /dev/null 2>&1; then
    echo "   ✅ 端口 9875 (主WebSocket) 监听中"
else
    echo "   ❌ FAILED: 端口 9875 未监听"
    PORTS_OK=false
fi

if lsof -i :9876 > /dev/null 2>&1; then
    echo "   ✅ 端口 9876 (移动端) 监听中"
else
    echo "   ❌ FAILED: 端口 9876 未监听"
    PORTS_OK=false
fi

# 检查日志
echo "5️⃣  检查启动日志..."
if grep -q "Server started" /tmp/opencli-test-daemon.log 2>/dev/null; then
    echo "   ✅ 启动日志正常"
else
    echo "   ⚠️  WARNING: 未找到启动成功日志"
fi

# 等待5秒确保稳定
echo "6️⃣  稳定性测试 (5秒)..."
sleep 5

if ps -p $DAEMON_PID > /dev/null; then
    echo "   ✅ Daemon稳定运行"
else
    echo "   ❌ FAILED: Daemon意外退出"
    echo "   日志内容:"
    tail -20 /tmp/opencli-test-daemon.log
    exit 1
fi

# 最终结果
echo ""
echo "=========================================="
if [ "$PORTS_OK" = true ]; then
    echo "✅ Test-Backend-01: PASSED"
    echo "=========================================="
    exit 0
else
    echo "❌ Test-Backend-01: FAILED"
    echo "=========================================="
    exit 1
fi
