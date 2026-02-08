#!/bin/bash
# OpenCLI 一键安装脚本
# curl -fsSL https://opencli.ai/install | sh
# 或者: curl -fsSL https://raw.githubusercontent.com/user/opencli/main/scripts/install.sh | sh

set -e

# ========================================
# 配置
# ========================================
OPENCLI_VERSION="${OPENCLI_VERSION:-latest}"
OPENCLI_HOME="${OPENCLI_HOME:-$HOME/.opencli}"
OPENCLI_BIN="${OPENCLI_BIN:-$HOME/.local/bin}"
GITHUB_REPO="${GITHUB_REPO:-user/opencli}"
DOWNLOAD_BASE="${DOWNLOAD_BASE:-https://github.com/$GITHUB_REPO/releases/download}"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ========================================
# 工具函数
# ========================================

print_banner() {
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                                           ║${NC}"
    echo -e "${CYAN}║    ${GREEN}OpenCLI${CYAN} - AI 驱动的电脑控制助手        ║${NC}"
    echo -e "${CYAN}║                                           ║${NC}"
    echo -e "${CYAN}║    🖥️  从手机远程控制你的电脑              ║${NC}"
    echo -e "${CYAN}║    🤖  自然语言即可操作                    ║${NC}"
    echo -e "${CYAN}║    🔒  端到端加密，安全可靠                ║${NC}"
    echo -e "${CYAN}║                                           ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════╝${NC}"
    echo ""
}

info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

success() {
    echo -e "${GREEN}✓${NC} $1"
}

warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

error() {
    echo -e "${RED}✗${NC} $1"
    exit 1
}

# 检测操作系统
detect_os() {
    OS="$(uname -s)"
    ARCH="$(uname -m)"

    case "$OS" in
        Darwin)
            OS="macos"
            ;;
        Linux)
            OS="linux"
            ;;
        MINGW*|MSYS*|CYGWIN*)
            OS="windows"
            ;;
        *)
            error "不支持的操作系统: $OS"
            ;;
    esac

    case "$ARCH" in
        x86_64|amd64)
            ARCH="x64"
            ;;
        arm64|aarch64)
            ARCH="arm64"
            ;;
        *)
            error "不支持的架构: $ARCH"
            ;;
    esac

    info "检测到系统: $OS-$ARCH"
}

# 检测包管理器
detect_package_manager() {
    if command -v brew &> /dev/null; then
        PKG_MANAGER="brew"
    elif command -v apt-get &> /dev/null; then
        PKG_MANAGER="apt"
    elif command -v yum &> /dev/null; then
        PKG_MANAGER="yum"
    elif command -v pacman &> /dev/null; then
        PKG_MANAGER="pacman"
    else
        PKG_MANAGER="none"
    fi
}

# 获取最新版本
get_latest_version() {
    if [ "$OPENCLI_VERSION" = "latest" ]; then
        info "获取最新版本..."
        # 尝试从 GitHub API 获取最新版本
        if command -v curl &> /dev/null; then
            OPENCLI_VERSION=$(curl -sL "https://api.github.com/repos/$GITHUB_REPO/releases/latest" 2>/dev/null | grep '"tag_name":' | sed -E 's/.*"v?([^"]+)".*/\1/' || echo "0.2.0")
        else
            OPENCLI_VERSION="0.2.0"
        fi
    fi
    info "安装版本: v$OPENCLI_VERSION"
}

# 检查依赖
check_dependencies() {
    info "检查依赖..."

    local missing_deps=()

    # 检查 Dart
    if ! command -v dart &> /dev/null; then
        missing_deps+=("dart")
    fi

    # 检查 curl
    if ! command -v curl &> /dev/null && ! command -v wget &> /dev/null; then
        missing_deps+=("curl")
    fi

    if [ ${#missing_deps[@]} -gt 0 ]; then
        warn "缺少依赖: ${missing_deps[*]}"
        install_dependencies "${missing_deps[@]}"
    else
        success "所有依赖已满足"
    fi
}

# 安装依赖
install_dependencies() {
    local deps=("$@")

    for dep in "${deps[@]}"; do
        case "$dep" in
            dart)
                install_dart
                ;;
            curl)
                install_curl
                ;;
        esac
    done
}

install_dart() {
    info "安装 Dart SDK..."
    case "$PKG_MANAGER" in
        brew)
            brew install dart
            ;;
        apt)
            sudo apt-get update
            sudo apt-get install -y apt-transport-https
            sudo sh -c 'wget -qO- https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -'
            sudo sh -c 'wget -qO- https://storage.googleapis.com/download.dartlang.org/linux/debian/dart_stable.list > /etc/apt/sources.list.d/dart_stable.list'
            sudo apt-get update
            sudo apt-get install -y dart
            ;;
        *)
            warn "无法自动安装 Dart，请手动安装: https://dart.dev/get-dart"
            ;;
    esac
}

install_curl() {
    info "安装 curl..."
    case "$PKG_MANAGER" in
        apt)
            sudo apt-get install -y curl
            ;;
        yum)
            sudo yum install -y curl
            ;;
        pacman)
            sudo pacman -S curl
            ;;
        *)
            error "请手动安装 curl"
            ;;
    esac
}

# 创建目录结构
create_directories() {
    info "创建目录结构..."

    mkdir -p "$OPENCLI_HOME"
    mkdir -p "$OPENCLI_HOME/bin"
    mkdir -p "$OPENCLI_HOME/capabilities"
    mkdir -p "$OPENCLI_HOME/cache"
    mkdir -p "$OPENCLI_HOME/logs"
    mkdir -p "$OPENCLI_HOME/data"
    mkdir -p "$OPENCLI_HOME/plugins"
    mkdir -p "$OPENCLI_BIN"

    success "目录结构已创建: $OPENCLI_HOME"
}

# 生成设备 ID
generate_device_id() {
    info "生成设备标识..."

    local device_id_file="$OPENCLI_HOME/device_id"

    if [ -f "$device_id_file" ]; then
        DEVICE_ID=$(cat "$device_id_file")
        info "使用现有设备ID: ${DEVICE_ID:0:8}..."
    else
        # 生成唯一设备ID
        if command -v uuidgen &> /dev/null; then
            DEVICE_ID=$(uuidgen | tr '[:upper:]' '[:lower:]')
        else
            DEVICE_ID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "$(hostname)-$(date +%s)" | sha256sum | cut -c1-36)
        fi
        echo "$DEVICE_ID" > "$device_id_file"
        success "生成设备ID: ${DEVICE_ID:0:8}..."
    fi
}

# 下载并安装二进制文件
download_and_install() {
    info "下载 OpenCLI..."

    local download_url="$DOWNLOAD_BASE/v$OPENCLI_VERSION/opencli-$OS-$ARCH.tar.gz"
    local temp_dir=$(mktemp -d)
    local archive_path="$temp_dir/opencli.tar.gz"

    # 尝试下载
    if command -v curl &> /dev/null; then
        if ! curl -fsSL "$download_url" -o "$archive_path" 2>/dev/null; then
            warn "无法下载预编译版本，将从源码构建..."
            build_from_source
            return
        fi
    elif command -v wget &> /dev/null; then
        if ! wget -q "$download_url" -O "$archive_path" 2>/dev/null; then
            warn "无法下载预编译版本，将从源码构建..."
            build_from_source
            return
        fi
    else
        warn "找不到 curl 或 wget，将从源码构建..."
        build_from_source
        return
    fi

    # 解压并安装
    tar -xzf "$archive_path" -C "$temp_dir"
    cp "$temp_dir/opencli" "$OPENCLI_HOME/bin/" 2>/dev/null || true
    cp "$temp_dir/opencli-daemon" "$OPENCLI_HOME/bin/" 2>/dev/null || true
    chmod +x "$OPENCLI_HOME/bin/"* 2>/dev/null || true

    # 创建符号链接
    ln -sf "$OPENCLI_HOME/bin/opencli" "$OPENCLI_BIN/opencli" 2>/dev/null || true

    rm -rf "$temp_dir"
    success "OpenCLI 已安装到 $OPENCLI_HOME/bin/"
}

# 从源码构建（备选方案）
build_from_source() {
    info "从源码构建 OpenCLI..."

    # 检查是否在项目目录中
    if [ -d "./daemon" ]; then
        info "检测到本地源码，从当前目录构建..."
        cd daemon

        # 安装依赖
        dart pub get

        # 编译 daemon
        dart compile exe bin/daemon.dart -o "$OPENCLI_HOME/bin/opencli-daemon"

        cd ..
        success "从本地源码构建完成"
        return
    fi

    local temp_dir=$(mktemp -d)

    # 克隆仓库
    if command -v git &> /dev/null; then
        git clone --depth 1 "https://github.com/$GITHUB_REPO.git" "$temp_dir/opencli" 2>/dev/null || {
            error "无法获取源码，请手动安装"
        }

        cd "$temp_dir/opencli/daemon"

        # 安装依赖
        dart pub get

        # 编译
        dart compile exe bin/daemon.dart -o opencli-daemon

        # 安装
        cp opencli-daemon "$OPENCLI_HOME/bin/"
        chmod +x "$OPENCLI_HOME/bin/opencli-daemon"

        cd - > /dev/null
        rm -rf "$temp_dir"

        success "从源码构建完成"
    else
        error "需要 git 来克隆源码"
    fi
}

# 创建默认配置
create_default_config() {
    info "创建配置文件..."

    local config_file="$OPENCLI_HOME/config.yaml"

    if [ ! -f "$config_file" ]; then
        cat > "$config_file" << 'EOF'
# OpenCLI 配置文件
# 更多配置项请参考: https://opencli.ai/docs/config

config_version: 1
auto_mode: true

# AI 模型优先级
models:
  priority:
    - ollama      # 本地 Ollama (免费)
    - tinylm      # 轻量本地模型
    - claude      # Anthropic Claude (需API Key)

# 缓存配置
cache:
  enabled: true
  l1:
    max_size: 100
  l2:
    max_size: 1000
  l3:
    enabled: true
    max_size_mb: 500

# 能力包配置
capabilities:
  auto_update: true
  update_interval: 3600  # 秒
  repository: "https://opencli.ai/api/capabilities"

# 插件配置
plugins:
  auto_load: true
  enabled: []

# 安全配置
security:
  socket_path: /tmp/opencli.sock
  socket_permissions: 0600
  require_confirmation_for:
    - delete_file
    - run_command
    - close_app

# 遥测配置 (匿名，用于改进产品)
telemetry:
  enabled: true
  anonymous: true
  report_errors: true
  report_usage: false

# 远程控制配置
remote:
  enabled: true
  port: 9876
  require_pairing: true
EOF
        success "配置文件已创建: $config_file"
    else
        info "配置文件已存在，跳过创建"
    fi
}

# 注册为系统服务
register_service() {
    info "注册系统服务..."

    case "$OS" in
        macos)
            register_launchd_service
            ;;
        linux)
            register_systemd_service
            ;;
    esac
}

# macOS launchd 服务
register_launchd_service() {
    local plist_path="$HOME/Library/LaunchAgents/io.opencli.daemon.plist"
    mkdir -p "$HOME/Library/LaunchAgents"

    cat > "$plist_path" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>io.opencli.daemon</string>
    <key>ProgramArguments</key>
    <array>
        <string>$OPENCLI_HOME/bin/opencli-daemon</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$OPENCLI_HOME/logs/daemon.log</string>
    <key>StandardErrorPath</key>
    <string>$OPENCLI_HOME/logs/daemon.error.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>HOME</key>
        <string>$HOME</string>
        <key>OPENCLI_HOME</key>
        <string>$OPENCLI_HOME</string>
    </dict>
</dict>
</plist>
EOF

    # 加载服务
    launchctl unload "$plist_path" 2>/dev/null || true
    launchctl load "$plist_path" 2>/dev/null || true

    success "已注册 macOS 服务 (launchd)"
}

# Linux systemd 服务
register_systemd_service() {
    local service_path="$HOME/.config/systemd/user/opencli-daemon.service"
    mkdir -p "$(dirname "$service_path")"

    cat > "$service_path" << EOF
[Unit]
Description=OpenCLI Daemon - AI Desktop Control
After=network.target

[Service]
Type=simple
ExecStart=$OPENCLI_HOME/bin/opencli-daemon
Restart=always
RestartSec=5
Environment=HOME=$HOME
Environment=OPENCLI_HOME=$OPENCLI_HOME

[Install]
WantedBy=default.target
EOF

    # 启用并启动服务
    systemctl --user daemon-reload 2>/dev/null || true
    systemctl --user enable opencli-daemon 2>/dev/null || true
    systemctl --user start opencli-daemon 2>/dev/null || true

    success "已注册 Linux 服务 (systemd)"
}

# 生成并显示配对二维码
show_pairing_qrcode() {
    info "生成配对二维码..."

    local pairing_data="{\"device_id\":\"$DEVICE_ID\",\"host\":\"$(hostname)\",\"port\":9876}"
    local pairing_url="opencli://pair?data=$(echo "$pairing_data" | base64 | tr -d '\n')"

    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║         📱 扫码配对手机 App              ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════╝${NC}"
    echo ""

    # 如果有 qrencode，生成二维码
    if command -v qrencode &> /dev/null; then
        qrencode -t ANSIUTF8 "$pairing_url"
    else
        echo "配对链接: $pairing_url"
        echo ""
        echo "提示: 安装 qrencode 可显示二维码"
        echo "  macOS: brew install qrencode"
        echo "  Linux: sudo apt install qrencode"
    fi

    echo ""
    echo -e "设备 ID: ${GREEN}${DEVICE_ID:0:8}...${NC}"
    echo -e "主机名:  ${GREEN}$(hostname)${NC}"
    echo -e "端口:    ${GREEN}9876${NC}"
    echo ""
}

# 添加到 PATH
add_to_path() {
    info "配置环境变量..."

    local shell_rc=""
    local shell_name=$(basename "$SHELL")

    case "$shell_name" in
        bash)
            shell_rc="$HOME/.bashrc"
            ;;
        zsh)
            shell_rc="$HOME/.zshrc"
            ;;
        fish)
            shell_rc="$HOME/.config/fish/config.fish"
            ;;
        *)
            shell_rc="$HOME/.profile"
            ;;
    esac

    # 检查是否已添加
    if ! grep -q "OPENCLI_HOME" "$shell_rc" 2>/dev/null; then
        echo "" >> "$shell_rc"
        echo "# OpenCLI" >> "$shell_rc"
        echo "export OPENCLI_HOME=\"$OPENCLI_HOME\"" >> "$shell_rc"
        echo "export PATH=\"\$OPENCLI_HOME/bin:\$PATH\"" >> "$shell_rc"
        success "环境变量已添加到 $shell_rc"
    else
        info "环境变量已配置"
    fi
}

# 验证安装
verify_installation() {
    info "验证安装..."

    # 检查文件
    if [ ! -d "$OPENCLI_HOME" ]; then
        error "安装目录不存在"
    fi

    # 检查配置
    if [ ! -f "$OPENCLI_HOME/config.yaml" ]; then
        error "配置文件不存在"
    fi

    success "安装验证通过"
}

# 打印完成信息
print_completion() {
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                           ║${NC}"
    echo -e "${GREEN}║      ✨ OpenCLI 安装成功！               ║${NC}"
    echo -e "${GREEN}║                                           ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════╝${NC}"
    echo ""
    echo "快速开始："
    echo ""
    echo -e "  ${CYAN}1.${NC} 重新加载终端或运行:"
    echo -e "     ${GREEN}source ~/.$(basename $SHELL)rc${NC}"
    echo ""
    echo -e "  ${CYAN}2.${NC} 启动守护进程:"
    echo -e "     ${GREEN}opencli-daemon${NC}"
    echo ""
    echo -e "  ${CYAN}3.${NC} 从手机扫码配对"
    echo ""
    echo -e "  ${CYAN}4.${NC} 开始使用!"
    echo ""
    echo "更多信息: https://opencli.ai/docs"
    echo ""
}

# ========================================
# 主流程
# ========================================

main() {
    print_banner

    # 检查是否以 root 运行
    if [ "$(id -u)" = "0" ]; then
        warn "不建议以 root 用户运行安装脚本"
    fi

    detect_os
    detect_package_manager
    get_latest_version
    check_dependencies
    create_directories
    generate_device_id
    download_and_install
    create_default_config
    add_to_path
    register_service
    verify_installation
    show_pairing_qrcode
    print_completion
}

# 运行安装
main "$@"
