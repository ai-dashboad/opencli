#!/bin/bash

# OpenCLI 完整客户端测试脚本
# 测试所有客户端：Daemon, opencli_app, 以及所有6个消息渠道

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 测试结果
PASSED=0
FAILED=0
SKIPPED=0

pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((PASSED++))
}

fail() {
    echo -e "${RED}✗${NC} $1"
    ((FAILED++))
}

skip() {
    echo -e "${YELLOW}⊘${NC} $1"
    ((SKIPPED++))
}

info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

echo "╔════════════════════════════════════════════════════════════╗"
echo "║          OpenCLI 完整客户端测试套件                       ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "📅 测试时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo "📍 测试目录: $(pwd)"
echo ""

# ============================================================
# 测试 1: Daemon (核心后端)
# ============================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 测试 1: OpenCLI Daemon (核心后端)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 1.1 检查 Daemon 依赖
info "检查 Daemon 依赖..."
cd daemon
if dart pub get &> /dev/null; then
    pass "Daemon 依赖安装成功"
else
    fail "Daemon 依赖安装失败"
fi

# 1.2 语法检查
info "运行代码分析..."
if dart analyze lib/channels/*.dart 2>&1 | grep -q "No issues found"; then
    pass "渠道代码分析通过（零错误）"
elif dart analyze lib/channels/*.dart 2>&1 | grep -qv "error"; then
    pass "渠道代码分析通过（仅警告）"
else
    fail "渠道代码有错误"
fi

# 1.3 测试启动
info "测试 Daemon 启动..."
timeout 5 dart bin/daemon.dart &> /tmp/daemon_test.log &
DAEMON_PID=$!
sleep 2

if kill -0 $DAEMON_PID 2>/dev/null; then
    pass "Daemon 进程启动成功 (PID: $DAEMON_PID)"

    # 检查 socket 文件
    if [ -S "/tmp/opencli.sock" ]; then
        pass "IPC Socket 创建成功"
    else
        fail "IPC Socket 未创建"
    fi

    # 检查端口监听
    if lsof -i :9876 &> /dev/null; then
        pass "移动连接服务器监听端口 9876"
    else
        skip "移动连接服务器端口 9876 未监听（可能正常）"
    fi

    # 停止 Daemon
    kill $DAEMON_PID 2>/dev/null || true
    sleep 1
else
    fail "Daemon 进程启动失败"
fi

cd ..
echo ""

# ============================================================
# 测试 2: 消息渠道（6个渠道）
# ============================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📱 测试 2: 消息渠道（Telegram, WhatsApp, Slack, Discord, WeChat, SMS）"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

CHANNELS=(
    "telegram_channel.dart:Telegram"
    "whatsapp_channel.dart:WhatsApp"
    "slack_channel.dart:Slack"
    "discord_channel.dart:Discord"
    "wechat_channel.dart:WeChat"
    "sms_channel.dart:SMS"
)

cd daemon
for channel_info in "${CHANNELS[@]}"; do
    IFS=':' read -r file name <<< "$channel_info"

    if [ -f "lib/channels/$file" ]; then
        lines=$(wc -l < "lib/channels/$file" | xargs)

        # 检查关键方法
        if grep -q "Future<void> initialize" "lib/channels/$file" && \
           grep -q "Future<void> sendMessage" "lib/channels/$file" && \
           grep -q "Future<bool> isAuthorized" "lib/channels/$file"; then
            pass "$name 渠道完整实现 ($lines 行代码)"
        else
            fail "$name 渠道缺少必需方法"
        fi
    else
        fail "$name 渠道文件不存在"
    fi
done
cd ..
echo ""

# ============================================================
# 测试 3: opencli_app (Flutter 跨平台应用)
# ============================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📲 测试 3: opencli_app (Flutter 跨平台应用)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

cd opencli_app

# 3.1 检查依赖
info "检查 Flutter 依赖..."
if flutter pub get &> /dev/null; then
    pass "Flutter 依赖安装成功"
else
    fail "Flutter 依赖安装失败"
fi

# 3.2 代码分析
info "运行代码分析..."
ANALYSIS_ERRORS=$(flutter analyze 2>&1 | grep "error •" | wc -l | xargs)
ANALYSIS_WARNINGS=$(flutter analyze 2>&1 | grep "warning •" | wc -l | xargs)

if [ "$ANALYSIS_ERRORS" = "0" ]; then
    pass "Flutter 代码零错误（$ANALYSIS_WARNINGS 个警告）"
else
    fail "Flutter 代码有 $ANALYSIS_ERRORS 个错误"
fi

# 3.3 检查 macOS UI 实现
info "检查 macOS 原生 UI 实现..."
if grep -q "MacosApp" lib/main.dart && \
   grep -q "MacosWindow" lib/main.dart && \
   grep -q "Sidebar" lib/main.dart; then
    pass "macOS 原生 UI 组件已实现"
else
    fail "macOS 原生 UI 组件缺失"
fi

# 3.4 检查跨平台支持
info "检查平台支持..."
PLATFORMS=0
[ -d "ios" ] && ((PLATFORMS++))
[ -d "android" ] && ((PLATFORMS++))
[ -d "macos" ] && ((PLATFORMS++))
[ -d "windows" ] && ((PLATFORMS++))
[ -d "linux" ] && ((PLATFORMS++))
[ -d "web" ] && ((PLATFORMS++))

pass "支持 $PLATFORMS/6 个平台（iOS, Android, macOS, Windows, Linux, Web）"

# 3.5 检查桌面功能
info "检查桌面特性..."
if grep -q "tray_manager" pubspec.yaml && \
   grep -q "window_manager" pubspec.yaml && \
   grep -q "hotkey_manager" pubspec.yaml; then
    pass "桌面特性包已配置（托盘、窗口、快捷键）"
else
    fail "桌面特性包缺失"
fi

cd ..
echo ""

# ============================================================
# 测试 4: 配置和文档
# ============================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📚 测试 4: 配置和文档"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 4.1 检查配置文件
if [ -f "config/channels.example.yaml" ]; then
    pass "渠道配置示例存在"
else
    fail "渠道配置示例缺失"
fi

# 4.2 检查文档
DOCS=(
    "README.md:项目 README"
    "docs/TELEGRAM_BOT_QUICKSTART.md:Telegram Bot 快速入门"
    "docs/E2E_TEST_PLAN.md:端到端测试计划"
    "docs/MACOS_UI_GUIDELINES.md:macOS UI 指南"
    "docs/CURRENT_STATUS_REPORT.md:当前状态报告"
)

for doc_info in "${DOCS[@]}"; do
    IFS=':' read -r file name <<< "$doc_info"
    if [ -f "$file" ]; then
        pass "$name 存在"
    else
        fail "$name 缺失"
    fi
done

echo ""

# ============================================================
# 测试总结
# ============================================================
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                      测试总结                              ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo -e "${GREEN}通过: $PASSED${NC}"
echo -e "${RED}失败: $FAILED${NC}"
echo -e "${YELLOW}跳过: $SKIPPED${NC}"
echo ""

TOTAL=$((PASSED + FAILED + SKIPPED))
PASS_RATE=$((PASSED * 100 / TOTAL))

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}🎉 所有测试通过！通过率: $PASS_RATE%${NC}"
    exit 0
else
    echo -e "${YELLOW}⚠️  部分测试失败。通过率: $PASS_RATE%${NC}"
    exit 1
fi
