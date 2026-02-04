#!/bin/bash
# Test-Backend-02: 健康检查端点测试
# 验证 /health 和 /status 端点返回正确数据

set -e

echo "=========================================="
echo "Test-Backend-02: 健康检查端点测试"
echo "=========================================="
echo ""

# 确保 Daemon 运行
if ! lsof -i :9875 > /dev/null 2>&1; then
    echo "❌ FAILED: Daemon未运行，请先运行 test_daemon_startup.sh"
    exit 1
fi

# 测试 /health 端点
echo "1️⃣  测试 /health 端点..."
HEALTH_RESPONSE=$(curl -s http://localhost:9875/health)
echo "   响应: $HEALTH_RESPONSE"

if echo "$HEALTH_RESPONSE" | grep -q '"status":"healthy"'; then
    echo "   ✅ Health检查通过"
else
    echo "   ❌ FAILED: Health响应异常"
    exit 1
fi

# 验证时间戳
if echo "$HEALTH_RESPONSE" | grep -q '"timestamp"'; then
    echo "   ✅ 时间戳字段存在"
else
    echo "   ❌ FAILED: 缺少timestamp字段"
    exit 1
fi

# 测试 /status 端点
echo ""
echo "2️⃣  测试 /status 端点..."
STATUS_RESPONSE=$(curl -s http://localhost:9875/status)
echo "   响应: $STATUS_RESPONSE"

# 验证必需字段
FIELDS_OK=true

if echo "$STATUS_RESPONSE" | grep -q '"daemon"'; then
    echo "   ✅ daemon字段存在"
else
    echo "   ❌ FAILED: 缺少daemon字段"
    FIELDS_OK=false
fi

if echo "$STATUS_RESPONSE" | grep -q '"version"'; then
    echo "   ✅ version字段存在"
else
    echo "   ❌ FAILED: 缺少version字段"
    FIELDS_OK=false
fi

if echo "$STATUS_RESPONSE" | grep -q '"uptime_seconds"'; then
    echo "   ✅ uptime_seconds字段存在"
else
    echo "   ❌ FAILED: 缺少uptime_seconds字段"
    FIELDS_OK=false
fi

if echo "$STATUS_RESPONSE" | grep -q '"memory_mb"'; then
    echo "   ✅ memory_mb字段存在"
else
    echo "   ❌ FAILED: 缺少memory_mb字段"
    FIELDS_OK=false
fi

if echo "$STATUS_RESPONSE" | grep -q '"mobile"'; then
    echo "   ✅ mobile字段存在"
else
    echo "   ❌ FAILED: 缺少mobile字段"
    FIELDS_OK=false
fi

# HTTP状态码测试
echo ""
echo "3️⃣  测试HTTP状态码..."
STATUS_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9875/health)
if [ "$STATUS_CODE" = "200" ]; then
    echo "   ✅ 状态码: 200 OK"
else
    echo "   ❌ FAILED: 状态码: $STATUS_CODE (期望200)"
    FIELDS_OK=false
fi

# 响应时间测试
echo ""
echo "4️⃣  测试响应时间..."
RESPONSE_TIME=$(curl -s -o /dev/null -w "%{time_total}" http://localhost:9875/health)
RESPONSE_MS=$(echo "$RESPONSE_TIME * 1000" | bc)
echo "   响应时间: ${RESPONSE_MS}ms"

if (( $(echo "$RESPONSE_TIME < 1.0" | bc -l) )); then
    echo "   ✅ 响应时间 <1秒"
else
    echo "   ❌ FAILED: 响应时间过长"
    FIELDS_OK=false
fi

# 最终结果
echo ""
echo "=========================================="
if [ "$FIELDS_OK" = true ]; then
    echo "✅ Test-Backend-02: PASSED"
    echo "=========================================="
    exit 0
else
    echo "❌ Test-Backend-02: FAILED"
    echo "=========================================="
    exit 1
fi
