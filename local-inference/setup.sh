#!/bin/bash
# OpenCLI Local Inference Setup
# Creates a Python venv and installs dependencies

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/.venv"

echo "=== OpenCLI Local Inference Setup ==="

# Check Python version
if ! command -v python3 &>/dev/null; then
  echo "ERROR: python3 not found. Install Python 3.10+ first."
  echo "  macOS: brew install python@3.11"
  echo "  Linux: sudo apt install python3 python3-venv python3-pip"
  exit 1
fi

PY_VERSION=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
echo "Found Python $PY_VERSION"

# Create venv
if [ ! -d "$VENV_DIR" ]; then
  echo "Creating virtual environment..."
  python3 -m venv "$VENV_DIR"
fi

# Activate
source "$VENV_DIR/bin/activate"

# Install dependencies
echo "Installing dependencies..."
pip install --upgrade pip -q
pip install -r "$SCRIPT_DIR/requirements.txt" -q

echo ""
echo "=== Setup Complete ==="
echo "Virtual environment: $VENV_DIR"
echo "Python: $(python --version)"
echo "PyTorch: $(python -c 'import torch; print(torch.__version__)')"

# Check GPU
python -c "
import torch
if torch.cuda.is_available():
    print(f'GPU: {torch.cuda.get_device_name(0)} ({torch.cuda.get_device_properties(0).total_mem / 1024**3:.1f} GB)')
elif hasattr(torch.backends, 'mps') and torch.backends.mps.is_available():
    print('GPU: Apple Silicon (MPS)')
else:
    print('GPU: None (CPU only - inference will be slow)')
"
echo ""
echo "Run inference: python $SCRIPT_DIR/infer.py --help"
