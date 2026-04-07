#!/usr/bin/env bash
# Aegis local dev setup — run once after cloning.
set -e

echo "==> Checking Python 3.12..."
python3.12 --version || { echo "Run: brew install python@3.12"; exit 1; }

echo "==> Creating virtual environment..."
python3.12 -m venv .venv

echo "==> Installing MLX-LM..."
.venv/bin/pip install mlx-lm

echo "==> Checking Go..."
go version || { echo "Run: brew install go"; exit 1; }

echo ""
echo "Setup complete."
echo ""
echo "To start the local model server (Aegis Lite):"
echo "  source .venv/bin/activate"
echo "  mlx_lm.server --model mlx-community/gemma-3-4b-it-4bit --port 8080 --trust-remote-code"
echo ""
echo "In a new terminal, build and run the CLI:"
echo "  go build -o aegis . && ./aegis chat"
echo ""
echo "Available models:"
echo "  aegis-lite  →  gemma-3-4b-it-4bit   (~2.5GB, fastest)"
echo "  aegis       →  gemma-3-12b-it-4bit  (~7GB, smarter)"
