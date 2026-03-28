#!/bin/bash
set -e

APP_NAME="Yell"
BUILD_DIR="build"
DIST_DIR="dist"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
DMG_PATH="$DIST_DIR/$APP_NAME.dmg"

# Build first
./build.sh

echo "Packaging $DMG_PATH..."
mkdir -p "$DIST_DIR"
rm -f "$DMG_PATH"

TMP_DIR=$(mktemp -d)
cp -r "$APP_BUNDLE" "$TMP_DIR/"
ln -s /Applications "$TMP_DIR/Applications"

hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$TMP_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

rm -rf "$TMP_DIR"

echo ""
echo "✅ $DMG_PATH"
