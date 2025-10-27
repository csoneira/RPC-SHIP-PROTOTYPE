#!/bin/bash

# Setup script for JOAO_SETUP Python environment
# This creates a virtual environment and installs all required packages

set -e  # Exit on error

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
VENV_DIR="$REPO_ROOT/STAGES/STAGE_1/DATA/DATA_FILES/venv"
REQUIREMENTS_FILE="$REPO_ROOT/STAGES/STAGE_1/CONFIGS/requirements.txt"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    cat <<EOF
Usage: $0

Create (if needed) and populate the Python virtual environment used by JOAO_SETUP.
The script installs python3-venv if missing, creates the venv under ./venv, and
installs the dependencies from requirements.txt.
EOF
    exit 0
fi

echo "=========================================="
echo "JOAO_SETUP Environment Setup"
echo "=========================================="
echo ""

cd "$REPO_ROOT"

# Check if python3-venv is installed
if ! dpkg -l | grep -q python3-venv; then
    echo "[WARNING] python3-venv is not installed"
    echo "[INFO] Installing python3-venv..."
    sudo apt update
    sudo apt install -y python3-venv python3-full
fi

mkdir -p "$(dirname "$VENV_DIR")"

# Create virtual environment if it doesn't exist
if [ ! -d "$VENV_DIR/bin" ]; then
    echo "[INFO] Creating virtual environment in '$VENV_DIR'..."
    python3 -m venv "$VENV_DIR"
    echo "[SUCCESS] Virtual environment created"
else
    echo "[INFO] Virtual environment already exists"
fi

echo ""
echo "[INFO] Activating virtual environment..."
source "$VENV_DIR/bin/activate"

PIP_CMD="pip"

echo "[INFO] Upgrading pip..."
if ! "$PIP_CMD" install --break-system-packages --upgrade pip; then
    echo "[WARNING] Could not upgrade pip (network issues or restricted environment). Proceeding with existing version."
fi

echo ""
echo "[INFO] Installing required packages from requirements.txt..."
if ! "$PIP_CMD" install --break-system-packages -r "$REQUIREMENTS_FILE"; then
    echo "[WARNING] Failed to install packages from $REQUIREMENTS_FILE. Requirements may already be satisfied or network may be unavailable."
fi

echo ""
echo "=========================================="
echo "Installation Complete!"
echo "=========================================="
echo ""
echo "To use this environment, run:"
echo "  source $VENV_DIR/bin/activate"
echo ""
echo "To deactivate the environment, run:"
echo "  deactivate"
echo ""
echo "To run Python scripts with this environment:"
echo "  $VENV_DIR/bin/python script.py"
echo ""
echo "=========================================="
