#!/bin/bash
set -e

APP_NAME="Yell"
BUILD_DIR="build"
WHISPER_DIR="vendor/whisper.cpp"
WHISPER_BUILD="$WHISPER_DIR/build"
SDK="$(xcrun --show-sdk-path 2>/dev/null || echo /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk)"

# Clone whisper.cpp if needed
if [ ! -d "$WHISPER_DIR" ]; then
    echo "Cloning whisper.cpp..."
    git clone --depth 1 https://github.com/ggerganov/whisper.cpp "$WHISPER_DIR"
fi

# Build whisper.cpp if needed
if [ ! -f "$WHISPER_BUILD/src/libwhisper.a" ]; then
    echo "Building whisper.cpp..."
    cd "$WHISPER_DIR"
    cmake -B build \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_SHARED_LIBS=OFF \
        -DWHISPER_BUILD_EXAMPLES=OFF \
        -DWHISPER_BUILD_TESTS=OFF \
        -DGGML_METAL=ON \
        -DGGML_ACCELERATE=ON \
        -DGGML_NATIVE=OFF
    cmake --build build --config Release -j$(sysctl -n hw.ncpu)
    cd ../..
fi

echo "Compiling $APP_NAME..."
mkdir -p "$BUILD_DIR"

swiftc \
    -O \
    -whole-module-optimization \
    -target arm64-apple-macosx14.0 \
    -sdk "$SDK" \
    -I include \
    -I "$WHISPER_DIR/include" \
    -I "$WHISPER_DIR/ggml/include" \
    -L "$WHISPER_BUILD/src" \
    -L "$WHISPER_BUILD/ggml/src" \
    -L "$WHISPER_BUILD/ggml/src/ggml-blas" \
    -L "$WHISPER_BUILD/ggml/src/ggml-metal" \
    -lwhisper \
    -lggml \
    -lggml-base \
    -lggml-cpu \
    -lggml-blas \
    -lggml-metal \
    -framework AppKit \
    -framework AVFoundation \
    -framework CoreGraphics \
    -framework Accelerate \
    -framework Carbon \
    -framework Metal \
    -framework MetalKit \
    -framework Foundation \
    -lc++ \
    Sources/*.swift \
    -o "$BUILD_DIR/$APP_NAME"

echo "Creating app bundle..."
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Bundle tiny.en model
TINY_MODEL="$HOME/.yell/models/ggml-tiny.en.bin"
if [ -f "$TINY_MODEL" ]; then
    echo "Bundling ggml-tiny.en.bin..."
    cp "$TINY_MODEL" "$APP_BUNDLE/Contents/Resources/ggml-tiny.en.bin"
else
    echo "⚠️  tiny.en model not found at $TINY_MODEL — run ./download-model.sh first"
fi

cat > "$APP_BUNDLE/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Yell</string>
    <key>CFBundleIdentifier</key>
    <string>com.yell.app</string>
    <key>CFBundleName</key>
    <string>Yell</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>Yell needs microphone access to record audio for transcription.</string>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP_BUNDLE"

echo ""
echo "✅ Built $APP_BUNDLE"
echo ""
echo "To run:  open $APP_BUNDLE"
