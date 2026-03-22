#!/bin/bash

# Build script for Image Compressor
# Usage: ./build-release.sh [configuration]

set -e

CONFIGURATION="${1:-Release}"
PROJECT_NAME="ImageCompressor"
SCHEME_NAME="ImageCompressor"
ARCHIVE_PATH="./build/${PROJECT_NAME}.xcarchive"
EXPORT_PATH="./build/export"

echo "🏗️  Building ${PROJECT_NAME} in ${CONFIGURATION} mode..."

# Clean build folder
echo "🧹 Cleaning build folder..."
rm -rf ./build

# Archive the app
echo "📦 Archiving..."
xcodebuild archive \
    -project ${PROJECT_NAME}.xcodeproj \
    -scheme ${SCHEME_NAME} \
    -configuration ${CONFIGURATION} \
    -archivePath ${ARCHIVE_PATH} \
    -destination 'platform=macOS' \
    ONLY_ACTIVE_ARCH=NO \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO

# Export the app (unsigned for local use)
echo "📤 Exporting..."
mkdir -p ${EXPORT_PATH}
cp -R ${ARCHIVE_PATH}/Products/Applications/${PROJECT_NAME}.app ${EXPORT_PATH}/

echo "✅ Build complete!"
echo "App location: ${EXPORT_PATH}/${PROJECT_NAME}.app"

# Get app size
APP_SIZE=$(du -sh ${EXPORT_PATH}/${PROJECT_NAME}.app | cut -f1)
echo "App size: ${APP_SIZE}"
