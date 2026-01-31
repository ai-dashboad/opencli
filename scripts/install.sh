#!/bin/bash
set -e

echo "Installing OpenCLI"
echo "=================="

# Detect OS
OS=$(uname -s)
ARCH=$(uname -m)

# Installation directory
INSTALL_DIR="$HOME/.opencli"
BIN_DIR="$INSTALL_DIR/bin"

# Create directories
mkdir -p "$BIN_DIR"
mkdir -p "$INSTALL_DIR/plugins"
mkdir -p "$INSTALL_DIR/cache"
mkdir -p "$INSTALL_DIR/logs"

# Copy binaries
echo "Installing binaries..."
cp dist/bin/opencli "$BIN_DIR/"
cp dist/bin/opencli-daemon "$BIN_DIR/"

# Make executable
chmod +x "$BIN_DIR/opencli"
chmod +x "$BIN_DIR/opencli-daemon"

# Copy configuration
if [ ! -f "$INSTALL_DIR/config.yaml" ]; then
    echo "Creating default configuration..."
    cp config/config.example.yaml "$INSTALL_DIR/config.yaml"
fi

# Add to PATH
SHELL_RC="$HOME/.bashrc"
if [ -f "$HOME/.zshrc" ]; then
    SHELL_RC="$HOME/.zshrc"
fi

if ! grep -q "opencli/bin" "$SHELL_RC"; then
    echo "" >> "$SHELL_RC"
    echo "# OpenCLI" >> "$SHELL_RC"
    echo "export PATH=\"\$HOME/.opencli/bin:\$PATH\"" >> "$SHELL_RC"
    echo "Added OpenCLI to PATH in $SHELL_RC"
fi

echo ""
echo "✓ Installation complete!"
echo ""
echo "To start using OpenCLI:"
echo "  1. Restart your terminal or run: source $SHELL_RC"
echo "  2. Test installation: opencli --version"
echo "  3. Start daemon: opencli daemon start"
echo "  4. Try it out: opencli chat \"Hello!\""
