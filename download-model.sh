#!/bin/bash
set -e

MODEL_DIR="$HOME/.yell/models"
MODEL_PATH="$MODEL_DIR/ggml-base.en.bin"
MODEL_URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin"

if [ -f "$MODEL_PATH" ]; then
    echo "Model already exists at $MODEL_PATH"
    exit 0
fi

mkdir -p "$MODEL_DIR"
echo "Downloading ggml-base.en.bin (~142MB)..."
curl -L --progress-bar -o "$MODEL_PATH" "$MODEL_URL"
echo "Model downloaded to $MODEL_PATH"
