#!/bin/bash
# Quick test of venv creation

set -e

INSTALL_DIR="/tmp/test_faceunlock"
VENV_DIR="$INSTALL_DIR/venv"

echo "Creating test directory..."
mkdir -p "$INSTALL_DIR"

echo "Creating virtual environment..."
python3 -m venv "$VENV_DIR"

echo "Checking venv structure..."
ls -la "$VENV_DIR/bin/"

echo "Checking venv python..."
"$VENV_DIR/bin/python3" --version

echo "Checking venv pip..."
"$VENV_DIR/bin/pip" --version

echo "Testing pip install in venv..."
"$VENV_DIR/bin/pip" install --quiet pip --upgrade

echo "✓ Virtual environment test successful!"
echo "Cleaning up..."
rm -rf "$INSTALL_DIR"
