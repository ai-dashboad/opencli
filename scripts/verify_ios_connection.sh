#!/bin/bash
# 验证 iOS 与 Daemon 的连接状态

echo "🔍 iOS <-> Daemon 连接验证"
echo "======================================"
echo ""

# 1. 检查 Daemon 进程
echo "1️⃣  检查 Daemon 进程..."
if pgrep -f "daemon.dart" > /dev/null; then
    echo "   ✅ Daemon 正在运行"
    DAEMON_PID=$(pgrep -f "daemon.dart")
    echo "   📍 PID: $DAEMON_PID"
else
    echo "   ❌ Daemon 未运行"
    exit 1
fi
echo ""

# 2. 检查端口监听
echo "2️⃣  检查端口监听..."
if lsof -iTCP:9875 -sTCP:LISTEN > /dev/null 2>&1; then
    echo "   ✅ HTTP API (9875) 正在监听"
else
    echo "   ❌ HTTP API 端口未监听"
fi

if lsof -iTCP:9876 -sTCP:LISTEN > /dev/null 2>&1; then
    echo "   ✅ WebSocket (9876) 正在监听"
else
    echo "   ❌ WebSocket 端口未监听"
fi
echo ""

# 3. 检查 API 响应
echo "3️⃣  检查 API 响应..."
STATUS=$(curl -s http://localhost:9875/status)
if [ $? -eq 0 ]; then
    echo "   ✅ API 响应正常"

    VERSION=$(echo $STATUS | jq -r '.daemon.version')
    UPTIME=$(echo $STATUS | jq -r '.daemon.uptime_seconds')
    CLIENTS=$(echo $STATUS | jq -r '.mobile.connected_clients')

    echo "   📊 版本: $VERSION"
    echo "   ⏱️  运行时间: $UPTIME 秒"
    echo "   📱 连接客户端: $CLIENTS"

    if [ "$CLIENTS" -gt 0 ]; then
        echo "   ✅ iOS 应用已连接！"
        CLIENT_IDS=$(echo $STATUS | jq -r '.mobile.client_ids[]')
        echo "   🆔 客户端 ID: $CLIENT_IDS"
    else
        echo "   ⚠️  无客户端连接"
    fi
else
    echo "   ❌ API 无响应"
fi
echo ""

# 4. 检查模拟器
echo "4️⃣  检查 iOS 模拟器..."
BOOTED=$(xcrun simctl list devices | grep Booted)
if [ -n "$BOOTED" ]; then
    echo "   ✅ 模拟器正在运行"
    echo "   📱 $BOOTED"
else
    echo "   ⚠️  模拟器未运行"
fi
echo ""

# 5. 测试 WebSocket 连接
echo "5️⃣  测试 WebSocket 连接..."
timeout 2 nc -zv localhost 9876 2>&1 | grep -q succeeded
if [ $? -eq 0 ]; then
    echo "   ✅ WebSocket 端口可访问"
else
    echo "   ⚠️  WebSocket 端口连接超时"
fi
echo ""

echo "======================================"
echo "✅ 验证完成"
