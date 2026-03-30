#!/bin/bash
set -euo pipefail

MODEL_DIR="$HOME/.yell/models"
BASE_URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main"
DEFAULT_MODELS=(
    "ggml-tiny.en.bin"
    "ggml-base.en.bin"
    "ggml-small.en.bin"
)

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

MODELS=("$@")
if [ "${#MODELS[@]}" -eq 0 ]; then
    MODELS=("${DEFAULT_MODELS[@]}")
fi

for model in "${MODELS[@]}"; do
    download_if_missing "$model"
done
