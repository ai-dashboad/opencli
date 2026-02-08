#!/bin/bash
# OpenCLI 实际测试执行脚本
# 按照测试方案逐步执行所有测试

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 项目根目录
PROJECT_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
cd "$PROJECT_ROOT"

# 测试结果目录
RESULTS_DIR="$PROJECT_ROOT/test-results/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$RESULTS_DIR"

# 日志文件
LOG_FILE="$RESULTS_DIR/test-execution.log"
DAEMON_LOG="$RESULTS_DIR/daemon.log"
DAEMON_PID=""

# 测试统计
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

# 打印带样式的标题
print_header() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# 打印步骤
print_step() {
    echo -e "${CYAN}▶ $1${NC}"
}

# 打印成功
print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# 打印错误
print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# 打印警告
print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# 打印信息
print_info() {
    echo -e "${MAGENTA}ℹ️  $1${NC}"
}

# 记录到日志文件
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# 清理函数
cleanup() {
    print_info "Cleaning up..."

    if [ -n "$DAEMON_PID" ] && ps -p $DAEMON_PID > /dev/null 2>&1; then
        print_step "Stopping daemon (PID: $DAEMON_PID)..."
        kill -TERM $DAEMON_PID 2>/dev/null || true
        sleep 2
        if ps -p $DAEMON_PID > /dev/null 2>&1; then
            kill -KILL $DAEMON_PID 2>/dev/null || true
        fi
        print_success "Daemon stopped"
    fi

    # 生成最终报告
    generate_final_report
}

# 设置陷阱
trap cleanup EXIT INT TERM

# 生成最终报告
generate_final_report() {
    local REPORT_FILE="$RESULTS_DIR/FINAL_REPORT.md"

    cat > "$REPORT_FILE" << EOF
# OpenCLI 实际测试报告

**测试日期**: $(date '+%Y-%m-%d %H:%M:%S')
**测试环境**: macOS $(sw_vers -productVersion)
**执行人**: $(whoami)

## 📊 测试统计

- **总测试数**: $TOTAL_TESTS
- **通过**: $PASSED_TESTS ✅
- **失败**: $FAILED_TESTS ❌
- **跳过**: $SKIPPED_TESTS ⏭️
- **成功率**: $(awk "BEGIN {printf \"%.1f\", ($PASSED_TESTS/$TOTAL_TESTS)*100}")%

## 📁 测试结果文件

- [执行日志](test-execution.log)
- [Daemon日志](daemon.log)
- [E2E测试结果](e2e-test-results.txt)

## 🎯 测试详情

详见各个测试阶段的日志文件。

---

**测试完成时间**: $(date '+%Y-%m-%d %H:%M:%S')
EOF

    echo ""
    print_header "测试完成"
    print_info "测试结果已保存到: $RESULTS_DIR"
    print_info "查看报告: cat $REPORT_FILE"
    echo ""

    if [ $FAILED_TESTS -eq 0 ]; then
        print_success "所有测试通过! 🎉"
    else
        print_error "$FAILED_TESTS 个测试失败"
    fi
}

# 检查命令是否存在
check_command() {
    if ! command -v $1 &> /dev/null; then
        print_error "$1 未安装"
        return 1
    fi
    return 0
}

# 检查端口是否被占用
check_port() {
    local port=$1
    if lsof -i :$port &> /dev/null; then
        print_warning "端口 $port 已被占用"
        print_step "尝试释放端口..."
        lsof -i :$port | grep LISTEN | awk '{print $2}' | xargs kill -9 2>/dev/null || true
        sleep 1
        if lsof -i :$port &> /dev/null; then
            print_error "无法释放端口 $port"
            return 1
        fi
        print_success "端口 $port 已释放"
    fi
    return 0
}

# 等待daemon启动
wait_for_daemon() {
    local max_attempts=30
    local attempt=0

    print_step "等待daemon启动..."

    while [ $attempt -lt $max_attempts ]; do
        if curl -s http://localhost:9875/health > /dev/null 2>&1; then
            print_success "Daemon已就绪"
            return 0
        fi
        attempt=$((attempt + 1))
        echo -n "."
        sleep 1
    done

    echo ""
    print_error "Daemon启动超时"
    return 1
}

#############################################
# 阶段1: 环境检查
#############################################
stage1_environment_check() {
    print_header "阶段1: 环境检查"
    TOTAL_TESTS=$((TOTAL_TESTS + 6))

    # 1.1 检查Dart
    print_step "检查 Dart SDK..."
    if check_command dart; then
        local dart_version=$(dart --version 2>&1 | head -1)
        print_success "Dart: $dart_version"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        log "PASS: Dart SDK found"
    else
        FAILED_TESTS=$((FAILED_TESTS + 1))
        log "FAIL: Dart SDK not found"
        print_error "请安装 Dart SDK: https://dart.dev/get-dart"
        return 1
    fi

    # 1.2 检查Flutter
    print_step "检查 Flutter SDK..."
    if check_command flutter; then
        local flutter_version=$(flutter --version | head -1)
        print_success "Flutter: $flutter_version"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        log "PASS: Flutter SDK found"
    else
        print_warning "Flutter SDK未安装（移动端测试需要）"
        SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
        log "SKIP: Flutter SDK not found"
    fi

    # 1.3 检查项目结构
    print_step "检查项目结构..."
    local required_files=(
        "daemon/bin/daemon.dart"
        "tests/run_e2e_tests.sh"
        "web-ui/websocket-test.html"
        "opencli_app/lib/services/daemon_service.dart"
    )

    local all_exists=true
    for file in "${required_files[@]}"; do
        if [ ! -f "$PROJECT_ROOT/$file" ]; then
            print_error "缺少文件: $file"
            all_exists=false
        fi
    done

    if $all_exists; then
        print_success "项目结构完整"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        log "PASS: Project structure valid"
    else
        FAILED_TESTS=$((FAILED_TESTS + 1))
        log "FAIL: Project structure incomplete"
        return 1
    fi

    # 1.4 检查端口
    print_step "检查端口占用..."
    if check_port 9875 && check_port 9876; then
        print_success "端口可用"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        log "PASS: Ports available"
    else
        FAILED_TESTS=$((FAILED_TESTS + 1))
        log "FAIL: Ports unavailable"
        return 1
    fi

    # 1.5 安装daemon依赖
    print_step "安装daemon依赖..."
    cd "$PROJECT_ROOT/daemon"
    if dart pub get > /dev/null 2>&1; then
        print_success "Daemon依赖已安装"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        log "PASS: Daemon dependencies installed"
    else
        FAILED_TESTS=$((FAILED_TESTS + 1))
        log "FAIL: Daemon dependencies installation failed"
        return 1
    fi

    # 1.6 安装测试依赖
    print_step "安装测试依赖..."
    cd "$PROJECT_ROOT/tests"
    if dart pub get > /dev/null 2>&1; then
        print_success "测试依赖已安装"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        log "PASS: Test dependencies installed"
    else
        FAILED_TESTS=$((FAILED_TESTS + 1))
        log "FAIL: Test dependencies installation failed"
        return 1
    fi

    cd "$PROJECT_ROOT"
    print_success "环境检查完成"
    return 0
}

#############################################
# 阶段2: Daemon启动测试
#############################################
stage2_daemon_startup() {
    print_header "阶段2: Daemon启动测试"
    TOTAL_TESTS=$((TOTAL_TESTS + 4))

    # 2.1 启动daemon
    print_step "启动daemon..."
    cd "$PROJECT_ROOT/daemon"
    dart run bin/daemon.dart --mode personal > "$DAEMON_LOG" 2>&1 &
    DAEMON_PID=$!

    if ps -p $DAEMON_PID > /dev/null 2>&1; then
        print_success "Daemon进程已启动 (PID: $DAEMON_PID)"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        log "PASS: Daemon process started (PID: $DAEMON_PID)"
    else
        print_error "Daemon启动失败"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        log "FAIL: Daemon process failed to start"
        return 1
    fi

    # 2.2 等待启动完成
    if wait_for_daemon; then
        PASSED_TESTS=$((PASSED_TESTS + 1))
        log "PASS: Daemon is healthy"
    else
        FAILED_TESTS=$((FAILED_TESTS + 1))
        log "FAIL: Daemon health check failed"
        print_error "Daemon日志:"
        tail -20 "$DAEMON_LOG"
        return 1
    fi

    # 2.3 检查健康端点
    print_step "检查健康端点..."
    local health_response=$(curl -s http://localhost:9875/health)
    if echo "$health_response" | grep -q "healthy"; then
        print_success "健康检查通过: $health_response"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        log "PASS: Health endpoint responded"
    else
        print_error "健康检查失败: $health_response"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        log "FAIL: Health endpoint check failed"
    fi

    # 2.4 检查WebSocket端点
    print_step "检查WebSocket端点..."
    if curl -s -o /dev/null -w "%{http_code}" \
        -H "Connection: Upgrade" \
        -H "Upgrade: websocket" \
        http://localhost:9875/ws | grep -q "101"; then
        print_success "WebSocket端点可用"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        log "PASS: WebSocket endpoint available"
    else
        print_warning "WebSocket握手测试跳过（需要完整WebSocket客户端）"
        SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
        log "SKIP: WebSocket handshake test"
    fi

    print_success "Daemon启动测试完成"
    return 0
}

#############################################
# 阶段3: E2E自动化测试
#############################################
stage3_e2e_tests() {
    print_header "阶段3: E2E自动化测试"

    print_step "运行E2E测试套件..."
    cd "$PROJECT_ROOT/tests"

    local e2e_results="$RESULTS_DIR/e2e-test-results.txt"

    if ./run_e2e_tests.sh -v > "$e2e_results" 2>&1; then
        print_success "E2E测试全部通过"

        # 统计测试结果
        local test_count=$(grep -c "^\[PASS\]" "$e2e_results" 2>/dev/null || echo "0")
        TOTAL_TESTS=$((TOTAL_TESTS + test_count))
        PASSED_TESTS=$((PASSED_TESTS + test_count))
        log "PASS: E2E tests ($test_count tests passed)"

        # 显示摘要
        echo ""
        print_info "E2E测试摘要:"
        grep "All tests passed\|tests passed" "$e2e_results" | tail -5

    else
        print_error "部分E2E测试失败"

        # 统计结果
        local passed=$(grep -c "^\[PASS\]" "$e2e_results" 2>/dev/null || echo "0")
        local failed=$(grep -c "^\[FAIL\]" "$e2e_results" 2>/dev/null || echo "0")

        TOTAL_TESTS=$((TOTAL_TESTS + passed + failed))
        PASSED_TESTS=$((PASSED_TESTS + passed))
        FAILED_TESTS=$((FAILED_TESTS + failed))

        log "FAIL: E2E tests ($passed passed, $failed failed)"

        # 显示失败的测试
        print_error "失败的测试:"
        grep "^\[FAIL\]" "$e2e_results" || true

        print_info "完整结果: $e2e_results"
    fi

    cd "$PROJECT_ROOT"
    return 0
}

#############################################
# 阶段4: WebUI浏览器测试（手动）
#############################################
stage4_webui_test() {
    print_header "阶段4: WebUI浏览器测试"

    print_info "此阶段需要手动测试"
    print_step "打开WebSocket测试工具..."

    local test_file="$PROJECT_ROOT/web-ui/websocket-test.html"

    if [ -f "$test_file" ]; then
        print_success "测试工具存在: $test_file"

        print_info "请在浏览器中执行以下测试:"
        echo "  1. 打开文件: open $test_file"
        echo "  2. 点击 'Connect' 按钮"
        echo "  3. 验证状态变为绿色 'Connected'"
        echo "  4. 点击 'Get Status' 按钮"
        echo "  5. 验证收到响应消息"
        echo ""

        read -p "是否现在打开浏览器测试? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            open "$test_file"
            print_info "已在浏览器中打开测试工具"
            print_warning "请手动完成测试后按回车继续..."
            read

            read -p "WebUI测试是否通过? (y/n) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                TOTAL_TESTS=$((TOTAL_TESTS + 1))
                PASSED_TESTS=$((PASSED_TESTS + 1))
                log "PASS: WebUI browser test (manual)"
                print_success "WebUI测试通过"
            else
                TOTAL_TESTS=$((TOTAL_TESTS + 1))
                FAILED_TESTS=$((FAILED_TESTS + 1))
                log "FAIL: WebUI browser test (manual)"
                print_error "WebUI测试失败"
            fi
        else
            TOTAL_TESTS=$((TOTAL_TESTS + 1))
            SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
            log "SKIP: WebUI browser test"
            print_warning "跳过WebUI测试"
        fi
    else
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
        FAILED_TESTS=$((FAILED_TESTS + 1))
        log "FAIL: WebUI test file not found"
        print_error "测试文件不存在"
    fi

    return 0
}

#############################################
# 阶段5: Android测试（手动/自动）
#############################################
stage5_android_test() {
    print_header "阶段5: Android模拟器测试"

    if ! check_command flutter; then
        print_warning "Flutter未安装，跳过Android测试"
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
        SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
        log "SKIP: Android test (Flutter not installed)"
        return 0
    fi

    print_info "此阶段需要Android模拟器"

    # 检查模拟器
    if ! check_command emulator; then
        print_warning "Android模拟器未配置，跳过测试"
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
        SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
        log "SKIP: Android test (emulator not found)"
        return 0
    fi

    # 列出可用模拟器
    local avds=$(emulator -list-avds 2>/dev/null)
    if [ -z "$avds" ]; then
        print_warning "没有可用的Android模拟器，跳过测试"
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
        SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
        log "SKIP: Android test (no AVDs)"
        return 0
    fi

    print_info "可用的模拟器:"
    echo "$avds"
    echo ""

    read -p "是否启动Android模拟器测试? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
        SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
        log "SKIP: Android test (user skipped)"
        print_warning "跳过Android测试"
        return 0
    fi

    print_info "Android测试需要手动验证:"
    echo "  1. 在另一个终端启动模拟器"
    echo "  2. cd opencli_app && flutter run"
    echo "  3. 验证app连接成功（10.0.2.2）"
    echo "  4. 验证消息收发正常"
    echo ""
    print_warning "完成后按回车继续..."
    read

    read -p "Android测试是否通过? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
        PASSED_TESTS=$((PASSED_TESTS + 1))
        log "PASS: Android test (manual)"
        print_success "Android测试通过"
    else
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
        FAILED_TESTS=$((FAILED_TESTS + 1))
        log "FAIL: Android test (manual)"
        print_error "Android测试失败"
    fi

    return 0
}

#############################################
# 主流程
#############################################
main() {
    print_header "OpenCLI 实际测试执行"
    print_info "测试结果将保存到: $RESULTS_DIR"
    echo ""

    log "========== 测试开始 =========="
    log "Project root: $PROJECT_ROOT"
    log "Results dir: $RESULTS_DIR"

    # 执行各个阶段
    if ! stage1_environment_check; then
        print_error "环境检查失败，终止测试"
        exit 1
    fi

    if ! stage2_daemon_startup; then
        print_error "Daemon启动失败，终止测试"
        exit 1
    fi

    stage3_e2e_tests

    stage4_webui_test

    stage5_android_test

    log "========== 测试结束 =========="
}

# 运行主流程
main "$@"
