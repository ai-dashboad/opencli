#!/bin/bash
# OpenCLI 完整测试套件运行器
# 按顺序运行所有测试，生成完整报告

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPORT_FILE="$SCRIPT_DIR/test-results/test_run_$(date +%Y%m%d_%H%M%S).md"
mkdir -p "$SCRIPT_DIR/test-results"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 测试结果统计
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

# 开始测试
echo "=========================================="
echo "OpenCLI 完整测试套件"
echo "=========================================="
echo "开始时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo "报告文件: $REPORT_FILE"
echo ""

# 创建报告头
cat > "$REPORT_FILE" <<EOF
# OpenCLI 自动化测试报告

**测试日期**: $(date '+%Y-%m-%d %H:%M:%S')
**测试类型**: 自动化 + 半自动测试
**执行人**: 自动化脚本

---

## 📊 测试概览

EOF

# 运行测试的函数
run_test() {
    local test_name="$1"
    local test_script="$2"
    local test_type="$3"  # backend/frontend/integration/performance

    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    echo ""
    echo "=========================================="
    echo "运行: $test_name"
    echo "=========================================="

    if [ ! -f "$test_script" ]; then
        echo -e "${YELLOW}⚠️  SKIPPED: 测试脚本不存在${NC}"
        SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
        echo "| $test_name | ⚠️ 跳过 | 脚本不存在 |" >> "$REPORT_FILE"
        return
    fi

    chmod +x "$test_script"

    if "$test_script"; then
        echo -e "${GREEN}✅ PASSED${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        echo "| $test_name | ✅ 通过 | - |" >> "$REPORT_FILE"
    else
        echo -e "${RED}❌ FAILED${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        echo "| $test_name | ❌ 失败 | 详见日志 |" >> "$REPORT_FILE"
    fi
}

# 阶段1: Backend测试
echo ""
echo "=========================================="
echo "阶段 1/4: Backend测试"
echo "=========================================="

cat >> "$REPORT_FILE" <<EOF

### Backend测试

| 测试项 | 状态 | 备注 |
|--------|------|------|
EOF

run_test "Test-Backend-01: Daemon启动测试" "$SCRIPT_DIR/backend/test_daemon_startup.sh" "backend"
run_test "Test-Backend-02: 健康检查端点测试" "$SCRIPT_DIR/backend/test_health_endpoint.sh" "backend"
run_test "Test-Backend-03: WebSocket连接测试" "$SCRIPT_DIR/backend/test_websocket_connection.sh" "backend"

# 阶段2: Frontend测试
echo ""
echo "=========================================="
echo "阶段 2/4: Frontend测试 (半自动)"
echo "=========================================="

cat >> "$REPORT_FILE" <<EOF

### Frontend测试

| 测试项 | 状态 | 备注 |
|--------|------|------|
EOF

echo ""
echo "⚠️  Frontend测试需要手动验证UI交互"
read -p "是否运行Frontend测试? (y/n): " RUN_FRONTEND

if [ "$RUN_FRONTEND" = "y" ] || [ "$RUN_FRONTEND" = "Y" ]; then
    run_test "Test-Frontend-01: macOS Menubar" "$SCRIPT_DIR/frontend/test_menubar.sh" "frontend"
    run_test "Test-Frontend-02: Android应用" "$SCRIPT_DIR/frontend/test_android.sh" "frontend"
else
    echo "跳过Frontend测试"
    SKIPPED_TESTS=$((SKIPPED_TESTS + 2))
    echo "| Test-Frontend-01: macOS Menubar | ⚠️ 跳过 | 用户跳过 |" >> "$REPORT_FILE"
    echo "| Test-Frontend-02: Android应用 | ⚠️ 跳过 | 用户跳过 |" >> "$REPORT_FILE"
fi

# 阶段3: E2E测试
echo ""
echo "=========================================="
echo "阶段 3/4: E2E自动化测试"
echo "=========================================="

cat >> "$REPORT_FILE" <<EOF

### E2E自动化测试

| 测试项 | 状态 | 备注 |
|--------|------|------|
EOF

if [ -d "$SCRIPT_DIR/e2e" ]; then
    cd "$SCRIPT_DIR/e2e"

    for test_file in *_test.dart; do
        if [ -f "$test_file" ]; then
            TOTAL_TESTS=$((TOTAL_TESTS + 1))
            echo "运行: $test_file"

            if dart test "$test_file"; then
                echo -e "${GREEN}✅ PASSED${NC}"
                PASSED_TESTS=$((PASSED_TESTS + 1))
                echo "| $test_file | ✅ 通过 | - |" >> "$REPORT_FILE"
            else
                echo -e "${RED}❌ FAILED${NC}"
                FAILED_TESTS=$((FAILED_TESTS + 1))
                echo "| $test_file | ❌ 失败 | 协议不匹配 |" >> "$REPORT_FILE"
            fi
        fi
    done
else
    echo "E2E测试目录不存在"
    echo "| E2E测试 | ⚠️ 跳过 | 目录不存在 |" >> "$REPORT_FILE"
fi

# 阶段4: 性能测试
echo ""
echo "=========================================="
echo "阶段 4/4: 性能测试"
echo "=========================================="

cat >> "$REPORT_FILE" <<EOF

### 性能测试

| 测试项 | 状态 | 备注 |
|--------|------|------|
| 响应时间测试 | ⚠️ 跳过 | 待实现 |
| 并发连接测试 | ⚠️ 跳过 | 待实现 |
| 内存使用测试 | ⚠️ 跳过 | 待实现 |

EOF

# 生成总结
SUCCESS_RATE=0
if [ $TOTAL_TESTS -gt 0 ]; then
    SUCCESS_RATE=$((PASSED_TESTS * 100 / TOTAL_TESTS))
fi

cat >> "$REPORT_FILE" <<EOF
---

## 📈 测试统计

| 指标 | 数值 |
|------|------|
| 总测试数 | $TOTAL_TESTS |
| 通过 | $PASSED_TESTS |
| 失败 | $FAILED_TESTS |
| 跳过 | $SKIPPED_TESTS |
| 成功率 | ${SUCCESS_RATE}% |

---

## 🎯 结论

EOF

if [ $SUCCESS_RATE -ge 90 ]; then
    echo "**✅ 优秀**: 测试通过率 ${SUCCESS_RATE}%，系统状态良好" >> "$REPORT_FILE"
    CONCLUSION="优秀"
elif [ $SUCCESS_RATE -ge 70 ]; then
    echo "**⚠️ 良好**: 测试通过率 ${SUCCESS_RATE}%，存在小问题需要修复" >> "$REPORT_FILE"
    CONCLUSION="良好"
elif [ $SUCCESS_RATE -ge 50 ]; then
    echo "**⚠️ 一般**: 测试通过率 ${SUCCESS_RATE}%，需要重大改进" >> "$REPORT_FILE"
    CONCLUSION="一般"
else
    echo "**❌ 不合格**: 测试通过率 ${SUCCESS_RATE}%，系统存在严重问题" >> "$REPORT_FILE"
    CONCLUSION="不合格"
fi

cat >> "$REPORT_FILE" <<EOF

---

**报告生成时间**: $(date '+%Y-%m-%d %H:%M:%S')

EOF

# 打印最终结果
echo ""
echo "=========================================="
echo "测试完成"
echo "=========================================="
echo "总测试数: $TOTAL_TESTS"
echo -e "通过: ${GREEN}$PASSED_TESTS${NC}"
echo -e "失败: ${RED}$FAILED_TESTS${NC}"
echo -e "跳过: ${YELLOW}$SKIPPED_TESTS${NC}"
echo "成功率: ${SUCCESS_RATE}%"
echo ""
echo "结论: $CONCLUSION"
echo ""
echo "完整报告: $REPORT_FILE"
echo "=========================================="

# 返回适当的退出码
if [ $FAILED_TESTS -eq 0 ]; then
    exit 0
else
    exit 1
fi
