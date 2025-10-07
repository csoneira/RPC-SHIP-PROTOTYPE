#!/bin/bash

# Setup script for JOAO_SETUP Python environment
# This creates a virtual environment and installs all required packages

set -e  # Exit on error

VENV_DIR="venv"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "=========================================="
echo "JOAO_SETUP Environment Setup"
echo "=========================================="
echo ""

cd "$SCRIPT_DIR"

# Check if python3-venv is installed
if ! dpkg -l | grep -q python3-venv; then
    echo "[WARNING] python3-venv is not installed"
    echo "[INFO] Installing python3-venv..."
    sudo apt update
    sudo apt install -y python3-venv python3-full
fi

# Create virtual environment if it doesn't exist
if [ ! -d "$VENV_DIR" ]; then
    echo "[INFO] Creating virtual environment in '$VENV_DIR'..."
    python3 -m venv "$VENV_DIR"
    echo "[SUCCESS] Virtual environment created"
else
    echo "[INFO] Virtual environment already exists"
fi

echo ""
echo "[INFO] Activating virtual environment..."
source "$VENV_DIR/bin/activate"

echo "[INFO] Upgrading pip..."
pip install --upgrade pip

echo ""
echo "[INFO] Installing required packages from requirements.txt..."
pip install -r requirements.txt

echo ""
echo "=========================================="
echo "Installation Complete!"
echo "=========================================="
echo ""
echo "To use this environment, run:"
echo "  source $SCRIPT_DIR/$VENV_DIR/bin/activate"
echo ""
echo "To deactivate the environment, run:"
echo "  deactivate"
echo ""
echo "To run Python scripts with this environment:"
echo "  $SCRIPT_DIR/$VENV_DIR/bin/python script.py"
echo ""
echo "=========================================="
