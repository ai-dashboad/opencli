#!/bin/bash
# Test-Frontend-04: WebUI测试
# 验证WebUI页面加载、WebSocket连接、功能按钮

set -e

echo "=========================================="
echo "Test-Frontend-04: WebUI测试"
echo "=========================================="
echo ""

# 确保 Daemon 运行
if ! lsof -i :9875 > /dev/null 2>&1; then
    echo "❌ FAILED: Daemon未运行，请先启动daemon"
    exit 1
fi

# 检查WebUI文件
WEBUI_PATH="$(dirname "$0")/../../web-ui/websocket-test.html"
if [ ! -f "$WEBUI_PATH" ]; then
    echo "❌ FAILED: WebUI测试文件不存在: $WEBUI_PATH"
    exit 1
fi

# 打开WebUI
echo "1️⃣  在浏览器中打开WebUI..."
if command -v open > /dev/null 2>&1; then
    open "$WEBUI_PATH"
    echo "   ✅ 已在默认浏览器中打开"
elif command -v xdg-open > /dev/null 2>&1; then
    xdg-open "$WEBUI_PATH"
    echo "   ✅ 已在默认浏览器中打开"
else
    echo "   ⚠️  请手动打开: file://$WEBUI_PATH"
fi

echo ""
echo "2️⃣  等待页面加载 (5秒)..."
sleep 5

# 手动测试提示
echo ""
echo "=========================================="
echo "📋 请在浏览器中手动验证以下项目:"
echo "=========================================="
echo ""
echo "A. 访问和加载 (3项):"
echo "   ☐ 1. 页面可访问"
echo "   ☐ 2. 页面完全加载 (无loading卡住)"
echo "   ☐ 3. 无控制台错误 (F12检查)"
echo ""
echo "B. WebSocket连接 (5项):"
echo "   ☐ 4. URL输入框显示: ws://localhost:9875/ws"
echo "   ☐ 5. Connect按钮可点击"
echo "   ☐ 6. 连接状态变绿色"
echo "   ☐ 7. 显示\"Connected\""
echo "   ☐ 8. 收到欢迎消息 (消息日志中)"
echo ""
echo "C. 预设功能按钮 (4项):"
echo "   ☐ 9. Get Status - 收到状态响应"
echo "   ☐ 10. Send Chat - 收到聊天响应"
echo "   ☐ 11. Submit Task - 收到任务响应"
echo "   ☐ 12. Invalid JSON - 收到错误响应"
echo ""
echo "D. 自定义消息 (3项):"
echo "   ☐ 13. 文本框可输入"
echo "   ☐ 14. Send按钮可点击"
echo "   ☐ 15. 收到响应"
echo ""
echo "E. 错误处理 (3项):"
echo "   ☐ 16. 断线后状态变红 (停止daemon测试)"
echo "   ☐ 17. 显示错误消息"
echo "   ☐ 18. 可以重新连接"
echo ""
echo "=========================================="
echo "提示:"
echo "  1. 按F12打开开发者工具查看控制台"
echo "  2. 测试完成后可以关闭浏览器标签"
echo "=========================================="
echo ""

# 等待用户确认
read -p "按Enter键继续，表示已完成所有测试验证..."

# 询问测试结果
echo ""
read -p "所有测试是否通过? (y/n): " MANUAL_RESULT

if [ "$MANUAL_RESULT" = "y" ] || [ "$MANUAL_RESULT" = "Y" ]; then
    echo ""
    echo "=========================================="
    echo "✅ Test-Frontend-04: PASSED"
    echo "=========================================="
    exit 0
else
    echo ""
    echo "=========================================="
    echo "❌ Test-Frontend-04: FAILED (手动测试未通过)"
    echo "=========================================="
    exit 1
fi
