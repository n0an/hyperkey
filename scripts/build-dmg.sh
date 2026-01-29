#!/bin/bash

set -e

# Configuration
APP_NAME="HyperKey"
SCHEME="HyperKey"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
DMG_DIR="$BUILD_DIR/dmg"
APP_PATH="$DMG_DIR/$APP_NAME.app"
DMG_PATH="$BUILD_DIR/$APP_NAME.dmg"

echo "🔨 Building $APP_NAME..."

# Clean previous build
rm -rf "$BUILD_DIR"
mkdir -p "$DMG_DIR"

# Build the app
xcodebuild -project "$PROJECT_DIR/HyperKey.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    -archivePath "$BUILD_DIR/$APP_NAME.xcarchive" \
    archive

# Export the app
xcodebuild -exportArchive \
    -archivePath "$BUILD_DIR/$APP_NAME.xcarchive" \
    -exportPath "$DMG_DIR" \
    -exportOptionsPlist "$PROJECT_DIR/scripts/ExportOptions.plist"

echo "📦 Creating DMG..."

# Check if create-dmg is installed
if command -v create-dmg &> /dev/null; then
    create-dmg \
        --volname "$APP_NAME" \
        --volicon "$PROJECT_DIR/icon.png" \
        --window-pos 200 120 \
        --window-size 600 400 \
        --icon-size 100 \
        --icon "$APP_NAME.app" 150 185 \
        --app-drop-link 450 185 \
        --hide-extension "$APP_NAME.app" \
        "$DMG_PATH" \
        "$DMG_DIR/$APP_NAME.app"
else
    echo "⚠️  create-dmg not found, using hdiutil (basic DMG)"
    echo "   Install create-dmg for prettier DMGs: brew install create-dmg"

    # Create Applications symlink
    ln -sf /Applications "$DMG_DIR/Applications"

    # Create DMG with hdiutil
    hdiutil create -volname "$APP_NAME" \
        -srcfolder "$DMG_DIR" \
        -ov -format UDZO \
        "$DMG_PATH"
fi

echo ""
echo "✅ DMG created: $DMG_PATH"
echo ""
echo "📏 Size: $(du -h "$DMG_PATH" | cut -f1)"
