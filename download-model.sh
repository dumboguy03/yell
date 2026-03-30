#!/bin/bash
set -euo pipefail

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
        local tmp_path="$path.download"
        rm -f "$tmp_path"
        local curl_progress="--no-progress-meter"
        if [ -t 2 ]; then
            curl_progress="--progress-bar"
        fi
        curl -fL --retry 3 "$curl_progress" -o "$tmp_path" "$BASE_URL/$name"
        mv "$tmp_path" "$path"
        echo "Downloaded to $path"
    fi
}

download_if_missing "ggml-tiny.en.bin"
download_if_missing "ggml-base.en.bin"
download_if_missing "ggml-small.en.bin"
