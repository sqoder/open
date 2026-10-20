#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$DIR/build/momi.app"

echo "==> 正在编译 momi.app..."
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$DIR/src/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$DIR/resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
cp "$DIR/resources/menubar_icon.png" "$APP_DIR/Contents/Resources/menubar_icon.png"
cp "$DIR/resources/menu_logo.png" "$APP_DIR/Contents/Resources/menu_logo.png"

swiftc -O "$DIR/src/main.swift" -o "$APP_DIR/Contents/MacOS/momi"

echo "==> 安装至 /Applications/momi.app..."
pkill -f "momi" 2>/dev/null || true
rm -rf /Applications/momi.app
cp -R "$APP_DIR" /Applications/momi.app

echo "==> 编译完成！已安装到 /Applications/momi.app"
