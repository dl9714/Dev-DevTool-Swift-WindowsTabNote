#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h}"
BUILD_DIR="$PROJECT_DIR/build"
DIST_DIR="$PROJECT_DIR/dist"
APP_DIR="$DIST_DIR/윈도우탭노트.app"
ICON_WORK_DIR="$BUILD_DIR/icon"
EXECUTABLE_NAME="WindowsTabNote"
ARCHIVE_PATH="$DIST_DIR/WindowsTabNote-macOS.zip"

mkdir -p "$BUILD_DIR" "$DIST_DIR"

swiftc \
  -swift-version 5 \
  -O \
  -framework AppKit \
  -framework UniformTypeIdentifiers \
  "$PROJECT_DIR/Sources/main.swift" \
  -o "$BUILD_DIR/$EXECUTABLE_NAME"

mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
ditto "$BUILD_DIR/$EXECUTABLE_NAME" "$APP_DIR/Contents/MacOS/$EXECUTABLE_NAME"
ditto "$PROJECT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"

rm -rf "$ICON_WORK_DIR"
mkdir -p "$ICON_WORK_DIR/AppIcon.iconset" "$ICON_WORK_DIR/rendered"
qlmanage -t -s 1024 -o "$ICON_WORK_DIR/rendered" "$PROJECT_DIR/Resources/AppIcon.svg" >/dev/null 2>&1
RENDERED_ICON="$ICON_WORK_DIR/rendered/AppIcon.svg.png"

if [[ -f "$RENDERED_ICON" ]]; then
  for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$RENDERED_ICON" --out "$ICON_WORK_DIR/AppIcon.iconset/icon_${size}x${size}.png" >/dev/null
    doubled=$((size * 2))
    sips -z "$doubled" "$doubled" "$RENDERED_ICON" --out "$ICON_WORK_DIR/AppIcon.iconset/icon_${size}x${size}@2x.png" >/dev/null
  done
  iconutil -c icns "$ICON_WORK_DIR/AppIcon.iconset" -o "$APP_DIR/Contents/Resources/AppIcon.icns"
fi

codesign --force --deep --sign - "$APP_DIR"

rm -f "$ARCHIVE_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ARCHIVE_PATH"

echo "$APP_DIR"
