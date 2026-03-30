#!/bin/bash
set -euo pipefail

APP_NAME="Yell"
REPO_URL="${YELL_REPO_URL:-https://github.com/LTCyogi/yell.git}"
MODEL_DIR="$HOME/.yell/models"
# Pin to the current Hugging Face repo commit so installs stay reproducible.
MODEL_URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/5359861c739e955e79d9a303bcbc70fb988958b1/ggml-tiny.en.bin"
# SHA-256 for the pinned ggml-tiny.en.bin above.
MODEL_SHA256="921e4cf8686fdd993dcd081a5da5b6c365bfde1162e72b08d75ac75289920b1f"
PRIMARY_INSTALL_DIR="${YELL_INSTALL_DIR:-/Applications}"
FALLBACK_INSTALL_DIR="$HOME/Applications"
TEMP_REPO_DIR=""

cleanup() {
    if [ -n "$TEMP_REPO_DIR" ] && [ -d "$TEMP_REPO_DIR" ]; then
        rm -rf "$TEMP_REPO_DIR"
    fi
}

trap cleanup EXIT

fail() {
    echo "Error: $*" >&2
    exit 1
}

ensure_supported_platform() {
    [ "$(uname -s)" = "Darwin" ] || fail "Yell only supports macOS."
    [ "$(uname -m)" = "arm64" ] || fail "Yell currently requires Apple Silicon."

    local macos_major
    macos_major="$(sw_vers -productVersion | cut -d. -f1)"
    [ "$macos_major" -ge 14 ] || fail "Yell requires macOS 14 or newer."
}

ensure_xcode_tools() {
    xcode-select -p >/dev/null 2>&1 || fail "Install Xcode Command Line Tools first: xcode-select --install"
}

ensure_cmake() {
    if command -v cmake >/dev/null 2>&1; then
        return
    fi

    if command -v brew >/dev/null 2>&1; then
        echo "Installing CMake with Homebrew..." >&2
        brew install cmake
        return
    fi

    fail "CMake is required. Install Homebrew or install CMake manually, then rerun."
}

resolve_repo_dir() {
    local script_dir=""

    if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
        script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    fi

    if [ -n "$script_dir" ] && [ -f "$script_dir/build.sh" ] && [ -f "$script_dir/download-model.sh" ]; then
        echo "$script_dir"
        return
    fi

    TEMP_REPO_DIR="$(mktemp -d)"
    echo "Cloning Yell into $TEMP_REPO_DIR..." >&2
    git clone --depth 1 --single-branch "$REPO_URL" "$TEMP_REPO_DIR"
    echo "$TEMP_REPO_DIR"
}

model_checksum() {
    shasum -a 256 "$1" | awk '{print $1}'
}

download_tiny_model() {
    local model_path="$MODEL_DIR/ggml-tiny.en.bin"

    mkdir -p "$MODEL_DIR"
    if [ -f "$model_path" ] && [ "$(model_checksum "$model_path")" = "$MODEL_SHA256" ]; then
        echo "ggml-tiny.en.bin already exists, skipping download."
        return
    fi

    if [ -f "$model_path" ]; then
        echo "Existing ggml-tiny.en.bin does not match the expected checksum, re-downloading..." >&2
        rm -f "$model_path"
    fi

    echo "Downloading ggml-tiny.en.bin..."
    local curl_progress="--no-progress-meter"
    if [ -t 2 ]; then
        curl_progress="--progress-bar"
    fi
    curl -fL --retry 3 "$curl_progress" -o "$model_path" "$MODEL_URL"

    if [ "$(model_checksum "$model_path")" != "$MODEL_SHA256" ]; then
        rm -f "$model_path"
        fail "Downloaded model checksum mismatch."
    fi
}

select_install_dir() {
    local target="$PRIMARY_INSTALL_DIR"

    if [ -e "$target" ] && [ ! -d "$target" ]; then
        fail "Install destination exists but is not a directory: $target"
    fi

    if [ "$target" = "/Applications" ] && [ ! -w "$target" ]; then
        echo "Falling back to $FALLBACK_INSTALL_DIR because /Applications is not writable."
        target="$FALLBACK_INSTALL_DIR"
    fi

    mkdir -p "$target"
    [ -w "$target" ] || fail "Install destination is not writable: $target"
    echo "$target"
}

main() {
    ensure_supported_platform
    ensure_xcode_tools
    ensure_cmake

    local repo_dir install_dir
    repo_dir="$(resolve_repo_dir)"
    # build.sh bundles ggml-tiny.en.bin from ~/.yell/models into the app bundle.
    download_tiny_model

    echo "Building Yell..."
    (
        cd "$repo_dir"
        ./build.sh
    )

    install_dir="$(select_install_dir)"
    [ -n "$install_dir" ] || fail "Install destination resolved to an empty path."
    [ "$install_dir" != "/" ] || fail "Refusing to install directly into /."
    local app_path="$install_dir/$APP_NAME.app"
    local staging_path="$install_dir/$APP_NAME.app.new"
    local backup_path="$install_dir/$APP_NAME.app.bak"
    [ "$app_path" != "/$APP_NAME.app" ] || fail "Refusing to overwrite an unexpected root-level app path."
    echo "Installing to $app_path..."
    rm -rf "$staging_path"
    rm -rf "$backup_path"
    ditto "$repo_dir/build/$APP_NAME.app" "$staging_path"
    if [ -d "$app_path" ]; then
        mv "$app_path" "$backup_path"
    fi
    if mv "$staging_path" "$app_path"; then
        rm -rf "$backup_path"
    else
        if [ -d "$backup_path" ]; then
            mv "$backup_path" "$app_path"
        fi
        fail "Install move failed."
    fi

    cat <<EOF

Installed $APP_NAME to:
  $app_path

Next steps:
  1. Open the app.
  2. Grant microphone and accessibility access when prompted.
  3. If macOS blocks the app, right-click it and choose Open once.
EOF
}

main "$@"
