#!/bin/bash

# Create DMG installer for Image Compressor
# Requires: brew install create-dmg

set -e

APP_NAME="ImageCompressor"
APP_PATH="./build/export/${APP_NAME}.app"
DMG_NAME="图片压缩V2.dmg"
DMG_PATH="./build/${DMG_NAME}"

# Check if app exists
if [ ! -d "${APP_PATH}" ]; then
    echo "❌ App not found at ${APP_PATH}"
    echo "Please run ./build-release.sh first"
    exit 1
fi

# Check if create-dmg is installed
if ! command -v create-dmg &> /dev/null; then
    echo "❌ create-dmg is not installed"
    echo "Install with: brew install create-dmg"
    exit 1
fi

echo "📦 Creating DMG installer..."

# Remove existing DMG
rm -f ${DMG_PATH}

# Create DMG
create-dmg \
    --volname "图片压缩" \
    --volicon "./DMG/logo.icns" \
    --background "./DMG/background.png" \
    --window-pos 200 120 \
    --window-size 660 400 \
    --icon-size 100 \
    --icon "${APP_NAME}.app" 180 170 \
    --hide-extension "${APP_NAME}.app" \
    --app-drop-link 480 170 \
    --no-internet-enable \
    ${DMG_PATH} \
    ${APP_PATH}

echo "✅ DMG created at: ${DMG_PATH}"

# Get DMG size
DMG_SIZE=$(du -sh ${DMG_PATH} | cut -f1)
echo "DMG size: ${DMG_SIZE}"

# Optional: Notarize (requires Apple Developer account)
# echo "📝 Notarizing..."
# xcrun notarytool submit ${DMG_PATH} --apple-id "your@email.com" --password "app-specific-password" --team-id "TEAMID"
# xcrun stapler staple ${DMG_PATH}
