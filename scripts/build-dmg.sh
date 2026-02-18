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

# Notarization credentials (store in keychain with: xcrun notarytool store-credentials "hyperkey-notarize")
NOTARIZE_PROFILE="hyperkey-notarize"

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

ICON_PATH="$APP_PATH/Contents/Resources/AppIcon.icns"

if command -v create-dmg &> /dev/null; then
    create-dmg \
        --volname "$APP_NAME" \
        ${ICON_PATH:+--volicon "$ICON_PATH"} \
        --window-pos 200 120 \
        --window-size 660 400 \
        --icon-size 100 \
        --icon "$APP_NAME.app" 180 190 \
        --app-drop-link 480 190 \
        --hide-extension "$APP_NAME.app" \
        --no-internet-enable \
        "$DMG_PATH" \
        "$APP_PATH" || true

    if [ ! -f "$DMG_PATH" ]; then
        echo "create-dmg failed, falling back to hdiutil..."
        ln -sf /Applications "$DMG_DIR/Applications"
        hdiutil create -volname "$APP_NAME" -srcfolder "$DMG_DIR" -ov -format UDZO "$DMG_PATH"
    fi
else
    echo "⚠️  create-dmg not found, using hdiutil (basic DMG)"
    echo "   Install for prettier DMGs: brew install create-dmg"

    ln -sf /Applications "$DMG_DIR/Applications"

    hdiutil create -volname "$APP_NAME" \
        -srcfolder "$DMG_DIR" \
        -ov -format UDZO \
        "$DMG_PATH"
fi

echo ""
echo "✅ DMG created: $DMG_PATH"
echo ""

# Set app icon on the DMG file
if command -v fileicon &> /dev/null; then
    if [ -f "$ICON_PATH" ]; then
        echo "🎨 Setting DMG icon..."
        fileicon set "$DMG_PATH" "$ICON_PATH"
    fi
else
    echo "⚠️  fileicon not found, DMG will have default icon"
    echo "   Install for custom DMG icon: brew install fileicon"
fi

# Notarization
if xcrun notarytool history --keychain-profile "$NOTARIZE_PROFILE" &> /dev/null; then
    echo "🔏 Notarizing DMG..."
    xcrun notarytool submit "$DMG_PATH" \
        --keychain-profile "$NOTARIZE_PROFILE" \
        --wait

    echo "📎 Stapling notarization ticket..."
    xcrun stapler staple "$DMG_PATH"

    echo ""
    echo "✅ Notarization complete!"
else
    echo "⚠️  Notarization skipped (keychain profile '$NOTARIZE_PROFILE' not found)"
    echo "   To enable notarization, run:"
    echo "   xcrun notarytool store-credentials \"$NOTARIZE_PROFILE\" --apple-id YOUR_EMAIL --team-id YOUR_TEAM_ID --password YOUR_APP_SPECIFIC_PASSWORD"
fi

echo ""
echo "📏 Size: $(du -h "$DMG_PATH" | cut -f1)"
