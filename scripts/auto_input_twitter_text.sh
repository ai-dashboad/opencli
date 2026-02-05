#!/bin/bash
# 自动化输入 Twitter/X 推广系统文本到模拟器
# 使用方法:
#   ./auto_input_twitter_text.sh android  # 在 Android 模拟器运行
#   ./auto_input_twitter_text.sh ios      # 在 iOS 模拟器运行
#   ./auto_input_twitter_text.sh both     # 在两个模拟器都运行

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
APP_DIR="$SCRIPT_DIR/../opencli_app"

# 颜色输出
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Twitter/X 推广系统文本 - 自动化输入测试${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# 函数：运行 Android 测试
run_android_test() {
    echo -e "${GREEN}📱 开始在 Android 模拟器上运行测试...${NC}"
    echo ""

    cd "$APP_DIR"
    flutter test integration_test/auto_input_test.dart -d emulator-5554

    echo ""
    echo -e "${GREEN}✅ Android 测试完成！${NC}"
}

# 函数：运行 iOS 测试
run_ios_test() {
    echo -e "${GREEN}📱 开始在 iOS 模拟器上运行测试...${NC}"
    echo ""

    # 获取可用的 iOS 模拟器
    IOS_DEVICE=$(flutter devices | grep "iPhone" | head -1 | awk '{print $5}')

    if [ -z "$IOS_DEVICE" ]; then
        echo -e "${RED}❌ 未找到 iOS 模拟器！${NC}"
        echo -e "${YELLOW}请先启动 iOS 模拟器${NC}"
        exit 1
    fi

    echo -e "${BLUE}使用设备: $IOS_DEVICE${NC}"

    cd "$APP_DIR"
    flutter test integration_test/auto_input_test.dart -d "$IOS_DEVICE"

    echo ""
    echo -e "${GREEN}✅ iOS 测试完成！${NC}"
}

# 主逻辑
PLATFORM="${1:-android}"

case "$PLATFORM" in
    android)
        run_android_test
        ;;
    ios)
        run_ios_test
        ;;
    both)
        run_android_test
        echo ""
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        run_ios_test
        ;;
    *)
        echo -e "${RED}错误: 未知平台 '$PLATFORM'${NC}"
        echo ""
        echo "使用方法:"
        echo "  $0 android  # 在 Android 模拟器运行"
        echo "  $0 ios      # 在 iOS 模拟器运行"
        echo "  $0 both     # 在两个模拟器都运行"
        exit 1
        ;;
esac

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}🎉 所有测试完成！${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}测试摘要:${NC}"
echo -e "  • 自动启动应用"
echo -e "  • 自动点击输入框"
echo -e "  • 自动输入完整的 Twitter/X 推广系统文本 (202 字符)"
echo -e "  • 自动点击发送按钮"
echo -e "  • 等待 AI 响应 (10 秒)"
echo ""
echo -e "${GREEN}💡 提示: 您可以在 integration_test/auto_input_test.dart 中修改要输入的文本${NC}"
echo ""
