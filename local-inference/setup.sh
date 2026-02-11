#!/bin/bash
# OpenCLI Local Inference Setup
# Creates a Python venv and installs dependencies

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/.venv"

echo "=== OpenCLI Local Inference Setup ==="

# Find a compatible Python (3.10-3.12 for PyTorch support)
PYTHON_CMD=""
for candidate in python3.12 python3.11 python3.10; do
  if command -v "$candidate" &>/dev/null; then
    PYTHON_CMD="$candidate"
    break
  fi
done

# Fallback to python3 if no specific version found
if [ -z "$PYTHON_CMD" ]; then
  if command -v python3 &>/dev/null; then
    PYTHON_CMD="python3"
  else
    echo "ERROR: python3 not found. Install Python 3.10-3.12 first."
    echo "  macOS: brew install python@3.12"
    echo "  Linux: sudo apt install python3 python3-venv python3-pip"
    exit 1
  fi
fi

PY_VERSION=$($PYTHON_CMD -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
PY_MINOR=$($PYTHON_CMD -c 'import sys; print(sys.version_info.minor)')
echo "Found Python $PY_VERSION ($PYTHON_CMD)"

if [ "$PY_MINOR" -gt 12 ]; then
  echo "WARNING: Python $PY_VERSION may not be compatible with PyTorch (needs 3.10-3.12)."
  echo "  Install a compatible version: brew install python@3.12"
  # Try to find a compatible version before failing
  for fallback in python3.12 python3.11 python3.10; do
    if command -v "$fallback" &>/dev/null; then
      PYTHON_CMD="$fallback"
      PY_VERSION=$($PYTHON_CMD -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
      echo "Using fallback: $PYTHON_CMD (Python $PY_VERSION)"
      break
    fi
  done
fi

# Create venv (recreate if Python version changed)
if [ -d "$VENV_DIR" ]; then
  EXISTING_PY=$("$VENV_DIR/bin/python3" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")' 2>/dev/null || echo "unknown")
  if [ "$EXISTING_PY" != "$PY_VERSION" ]; then
    echo "Recreating venv (was Python $EXISTING_PY, now $PY_VERSION)..."
    rm -rf "$VENV_DIR"
  fi
fi

if [ ! -d "$VENV_DIR" ]; then
  echo "Creating virtual environment with Python $PY_VERSION..."
  $PYTHON_CMD -m venv "$VENV_DIR"
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
# Create LoRA directory for user style LoRAs
LORA_DIR="$HOME/.opencli/models/loras"
if [ ! -d "$LORA_DIR" ]; then
  echo "Creating LoRA directory: $LORA_DIR"
  mkdir -p "$LORA_DIR"
fi

# Check for rife-ncnn-vulkan (frame interpolation)
if command -v rife-ncnn-vulkan &>/dev/null; then
  echo "RIFE: $(rife-ncnn-vulkan --version 2>&1 | head -1 || echo 'installed')"
else
  echo "RIFE: Not installed (optional - for frame interpolation)"
  echo "  Install: brew install rife-ncnn-vulkan"
fi

# Check ControlNet aux (for lineart/depth/openpose extraction)
python -c "import controlnet_aux; print(f'ControlNet Aux: {controlnet_aux.__version__}')" 2>/dev/null || \
  echo "ControlNet Aux: Not yet installed (will install from requirements.txt)"

# Create LUT directory for color grading presets
LUT_DIR="$HOME/.opencli/luts"
if [ ! -d "$LUT_DIR" ]; then
  echo "Creating LUT directory: $LUT_DIR"
  mkdir -p "$LUT_DIR"
fi

echo ""
echo "=== Available ControlNet Models ==="
echo "  controlnet_lineart_anime  (1.4 GB) — lllyasviel/control_v11p_sd15_lineart_anime"
echo "  controlnet_openpose       (1.4 GB) — lllyasviel/control_v11p_sd15_openpose"
echo "  controlnet_depth          (1.4 GB) — lllyasviel/control_v11f1p_sd15_depth"
echo "  Download via: POST /api/v1/local-models/<model_id>/download"
echo ""
echo "Run inference: python $SCRIPT_DIR/infer.py --help"
