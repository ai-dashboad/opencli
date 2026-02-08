#!/bin/bash
#
# OpenCLI Personal Mode - One-Click Installation Script
# 个人模式一键安装脚本 - 零配置，开箱即用
#
# Usage:
#   curl -sSL https://opencli.ai/install.sh | sh
#   或
#   wget -qO- https://opencli.ai/install.sh | sh
#

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 输出函数
info() {
    echo -e "${BLUE}ℹ ${NC}$1"
}

success() {
    echo -e "${GREEN}✓ ${NC}$1"
}

warning() {
    echo -e "${YELLOW}⚠ ${NC}$1"
}

error() {
    echo -e "${RED}✗ ${NC}$1"
}

# 显示欢迎信息
welcome() {
    clear
    cat << "EOF"
    ___                   __________   ____
   / _ \____  ___ ___    / ___/ / /  /  _/
  / // / _ \/ -_) _ \  / /__/ / /___/ /
  \___/ .__/\__/_//_/  \___/_/____/___/
     /_/

  Enterprise Autonomous Company Operating System
  零配置 • 开箱即用 • 个人模式

EOF
    echo ""
    info "开始安装 OpenCLI Personal Mode..."
    echo ""
}

# 检测操作系统
detect_os() {
    info "检测操作系统..."

    if [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
        success "检测到 macOS"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="linux"
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            DISTRO=$ID
            success "检测到 Linux ($DISTRO)"
        fi
    else
        error "不支持的操作系统: $OSTYPE"
        exit 1
    fi
}

# 检查依赖
check_dependencies() {
    info "检查系统依赖..."

    # 检查是否有包管理器
    if [[ "$OS" == "macos" ]]; then
        if ! command -v brew &> /dev/null; then
            warning "未检测到 Homebrew，正在安装..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi
        success "Homebrew 已安装"
    elif [[ "$OS" == "linux" ]]; then
        if command -v apt-get &> /dev/null; then
            PKG_MANAGER="apt-get"
        elif command -v yum &> /dev/null; then
            PKG_MANAGER="yum"
        elif command -v dnf &> /dev/null; then
            PKG_MANAGER="dnf"
        else
            error "未检测到支持的包管理器"
            exit 1
        fi
        success "包管理器: $PKG_MANAGER"
    fi
}

# 下载并安装
install_opencli() {
    info "下载 OpenCLI..."

    INSTALL_DIR="$HOME/.opencli"
    mkdir -p "$INSTALL_DIR"

    # 下载二进制文件
    DOWNLOAD_URL="https://github.com/opencli/opencli/releases/latest/download"

    if [[ "$OS" == "macos" ]]; then
        ARCH=$(uname -m)
        if [[ "$ARCH" == "arm64" ]]; then
            BINARY="opencli-macos-arm64.tar.gz"
        else
            BINARY="opencli-macos-x64.tar.gz"
        fi
    elif [[ "$OS" == "linux" ]]; then
        ARCH=$(uname -m)
        if [[ "$ARCH" == "x86_64" ]]; then
            BINARY="opencli-linux-x64.tar.gz"
        elif [[ "$ARCH" == "aarch64" ]]; then
            BINARY="opencli-linux-arm64.tar.gz"
        else
            error "不支持的架构: $ARCH"
            exit 1
        fi
    fi

    info "下载 $BINARY..."
    curl -sSL "$DOWNLOAD_URL/$BINARY" -o "/tmp/opencli.tar.gz"

    info "解压安装包..."
    tar -xzf "/tmp/opencli.tar.gz" -C "$INSTALL_DIR"
    rm /tmp/opencli.tar.gz

    success "OpenCLI 已安装到 $INSTALL_DIR"
}

# 创建默认配置
create_config() {
    info "生成默认配置..."

    CONFIG_DIR="$HOME/.opencli"
    mkdir -p "$CONFIG_DIR/data"
    mkdir -p "$CONFIG_DIR/logs"
    mkdir -p "$CONFIG_DIR/storage"
    mkdir -p "$CONFIG_DIR/backups"

    # 生成配置文件
    cat > "$CONFIG_DIR/config.yaml" << 'EOL'
mode: personal
daemon:
  name: "OpenCLI Personal"
  auto_start: true
  system_tray: true
  log_level: info

database:
  type: sqlite
  path: ~/.opencli/data/opencli.db
  auto_backup: true

storage:
  type: local
  base_path: ~/.opencli/storage

mobile:
  enabled: true
  port: 8765
  auto_discovery: true
  security:
    pairing_required: true
    auto_trust_local: true

automation:
  desktop:
    enabled: true
    screenshot: true
    keyboard_input: true
    mouse_input: true

notifications:
  desktop:
    enabled: true

logging:
  level: info
  file: true
  file_path: ~/.opencli/logs/opencli.log

security:
  authentication:
    type: simple
    session_timeout: 24h

ui:
  language: auto
  theme: auto
  tray:
    enabled: true
EOL

    success "配置文件已生成"
}

# 添加到 PATH
add_to_path() {
    info "添加到系统 PATH..."

    SHELL_RC=""
    if [[ "$SHELL" == */zsh ]]; then
        SHELL_RC="$HOME/.zshrc"
    elif [[ "$SHELL" == */bash ]]; then
        SHELL_RC="$HOME/.bashrc"
    fi

    if [ -n "$SHELL_RC" ]; then
        if ! grep -q "opencli" "$SHELL_RC"; then
            echo "" >> "$SHELL_RC"
            echo "# OpenCLI" >> "$SHELL_RC"
            echo 'export PATH="$HOME/.opencli/bin:$PATH"' >> "$SHELL_RC"
            success "已添加到 $SHELL_RC"
        fi
    fi

    # 创建系统范围的符号链接（需要 sudo）
    if [[ "$OS" == "macos" ]]; then
        sudo ln -sf "$HOME/.opencli/bin/opencli" /usr/local/bin/opencli 2>/dev/null || true
    elif [[ "$OS" == "linux" ]]; then
        sudo ln -sf "$HOME/.opencli/bin/opencli" /usr/bin/opencli 2>/dev/null || true
    fi
}

# 设置开机自启动
setup_autostart() {
    info "设置开机自启动..."

    if [[ "$OS" == "macos" ]]; then
        # macOS LaunchAgent
        PLIST_DIR="$HOME/Library/LaunchAgents"
        mkdir -p "$PLIST_DIR"

        cat > "$PLIST_DIR/com.opencli.daemon.plist" << EOL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.opencli.daemon</string>
    <key>ProgramArguments</key>
    <array>
        <string>$HOME/.opencli/bin/opencli</string>
        <string>daemon</string>
        <string>start</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$HOME/.opencli/logs/daemon.log</string>
    <key>StandardErrorPath</key>
    <string>$HOME/.opencli/logs/daemon.error.log</string>
</dict>
</plist>
EOL

        launchctl load "$PLIST_DIR/com.opencli.daemon.plist"
        success "已设置 macOS 开机自启动"

    elif [[ "$OS" == "linux" ]]; then
        # Linux systemd
        SYSTEMD_DIR="$HOME/.config/systemd/user"
        mkdir -p "$SYSTEMD_DIR"

        cat > "$SYSTEMD_DIR/opencli.service" << EOL
[Unit]
Description=OpenCLI Daemon
After=network.target

[Service]
Type=simple
ExecStart=$HOME/.opencli/bin/opencli daemon start
Restart=always
RestartSec=10

[Install]
WantedBy=default.target
EOL

        systemctl --user enable opencli.service
        systemctl --user start opencli.service
        success "已设置 Linux 开机自启动"
    fi
}

# 安装系统托盘（仅 macOS/Linux 桌面）
install_tray() {
    info "安装系统托盘..."

    if [[ "$OS" == "macos" ]]; then
        # macOS 会自动显示托盘图标
        success "macOS 托盘图标将自动显示"
    elif [[ "$OS" == "linux" ]]; then
        # 检查桌面环境
        if [ -n "$XDG_CURRENT_DESKTOP" ]; then
            success "检测到桌面环境: $XDG_CURRENT_DESKTOP"
            # Linux 桌面环境的托盘图标会自动显示
        else
            warning "未检测到桌面环境，跳过托盘图标设置"
        fi
    fi
}

# 启动守护进程
start_daemon() {
    info "启动 OpenCLI 守护进程..."

    if [[ "$OS" == "macos" ]]; then
        # macOS 通过 LaunchAgent 启动
        sleep 2  # 等待 LaunchAgent 启动
    elif [[ "$OS" == "linux" ]]; then
        # Linux 通过 systemd 启动
        sleep 2  # 等待 systemd 启动
    fi

    # 检查是否启动成功
    if "$HOME/.opencli/bin/opencli" status &> /dev/null; then
        success "守护进程已启动"
    else
        warning "守护进程启动中..."
    fi
}

# 显示配对二维码
show_pairing_qr() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    info "手机配对"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  请在手机上："
    echo ""
    echo "  1. 下载 OpenCLI App"
    echo "     • iOS: App Store 搜索 'OpenCLI'"
    echo "     • Android: Google Play 搜索 'OpenCLI'"
    echo ""
    echo "  2. 打开 App，选择 '扫码连接'"
    echo ""
    echo "  3. 扫描下方二维码"
    echo ""

    # 生成配对码和二维码（需要守护进程运行）
    if command -v qrencode &> /dev/null; then
        PAIRING_CODE=$("$HOME/.opencli/bin/opencli" mobile pairing-code 2>/dev/null || echo "")
        if [ -n "$PAIRING_CODE" ]; then
            echo "$PAIRING_CODE" | qrencode -t UTF8
            echo ""
            echo "  配对码: $PAIRING_CODE"
        else
            warning "守护进程尚未完全启动，请稍后运行："
            echo "  opencli mobile pairing-code"
        fi
    else
        info "运行以下命令获取配对码和二维码："
        echo "  opencli mobile pairing-code"
    fi

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# 完成提示
show_completion() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    success "安装完成！"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  ✓ OpenCLI 已成功安装"
    echo "  ✓ 守护进程已启动"
    echo "  ✓ 开机自启动已配置"
    echo ""
    echo "  下一步："
    echo ""
    echo "  • 查看状态: opencli status"
    echo "  • 系统托盘: 点击托盘图标查看菜单"
    echo "  • 手机连接: opencli mobile pairing-code"
    echo "  • 帮助文档: opencli help"
    echo ""
    echo "  配置文件位置: ~/.opencli/config.yaml"
    echo "  日志文件位置: ~/.opencli/logs/"
    echo ""
    echo "  需要帮助？访问: https://docs.opencli.ai"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# 主安装流程
main() {
    welcome
    detect_os
    check_dependencies
    install_opencli
    create_config
    add_to_path
    setup_autostart
    install_tray
    start_daemon
    show_pairing_qr
    show_completion
}

# 运行安装
main
