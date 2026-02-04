#!/bin/bash
# Test-Backend-03: WebSocket连接测试
# 验证客户端可以建立连接并收到欢迎消息

set -e

echo "=========================================="
echo "Test-Backend-03: WebSocket连接测试"
echo "=========================================="
echo ""

# 确保 Daemon 运行
if ! lsof -i :9875 > /dev/null 2>&1; then
    echo "❌ FAILED: Daemon未运行，请先运行 test_daemon_startup.sh"
    exit 1
fi

# 使用 Dart 客户端测试
echo "1️⃣  使用WebSocket客户端测试..."
cd "$(dirname "$0")/../../daemon"

# 运行示例客户端并捕获输出
timeout 10s dart test/websocket_client_example.dart > /tmp/opencli-ws-test.log 2>&1 &
WS_PID=$!

echo "   等待连接建立..."
sleep 3

# 检查连接日志
echo ""
echo "2️⃣  验证连接状态..."
if grep -q "Connected to ws://localhost:9875/ws" /tmp/opencli-ws-test.log; then
    echo "   ✅ WebSocket连接成功"
else
    echo "   ❌ FAILED: 未能建立WebSocket连接"
    cat /tmp/opencli-ws-test.log
    exit 1
fi

# 验证欢迎消息
echo ""
echo "3️⃣  验证欢迎消息..."
if grep -q "Client ID:" /tmp/opencli-ws-test.log; then
    CLIENT_ID=$(grep "Client ID:" /tmp/opencli-ws-test.log | head -1)
    echo "   ✅ 收到客户端ID: $CLIENT_ID"
else
    echo "   ❌ FAILED: 未收到客户端ID"
    exit 1
fi

if grep -q "Version:" /tmp/opencli-ws-test.log; then
    VERSION=$(grep "Version:" /tmp/opencli-ws-test.log | head -1)
    echo "   ✅ 收到版本信息: $VERSION"
else
    echo "   ❌ FAILED: 未收到版本信息"
    exit 1
fi

# 验证消息格式
echo ""
echo "4️⃣  验证消息格式..."
if grep -q '"type":"notification"' /tmp/opencli-ws-test.log; then
    echo "   ✅ 消息type字段正确"
else
    echo "   ⚠️  WARNING: 未找到notification类型消息"
fi

if grep -q '"event":"connected"' /tmp/opencli-ws-test.log; then
    echo "   ✅ 欢迎事件正确"
else
    echo "   ⚠️  WARNING: 未找到connected事件"
fi

# 清理
kill $WS_PID 2>/dev/null || true

# 最终结果
echo ""
echo "=========================================="
echo "✅ Test-Backend-03: PASSED"
echo "=========================================="
exit 0
