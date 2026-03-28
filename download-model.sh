#!/bin/bash
set -e

MODEL_DIR="$HOME/.yell/models"
BASE_URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main"

mkdir -p "$MODEL_DIR"

download_if_missing() {
    local name="$1"
    local path="$MODEL_DIR/$name"
    if [ -f "$path" ]; then
        echo "$name already exists, skipping."
    else
        echo "Downloading $name..."
        curl -L --progress-bar -o "$path" "$BASE_URL/$name"
        echo "Downloaded to $path"
    fi
}

download_if_missing "ggml-tiny.en.bin"
download_if_missing "ggml-base.en.bin"
