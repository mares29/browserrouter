#!/bin/bash
# Build BrowserRouter.app and create release DMG

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_NAME="BrowserRouter"
BUILD_DIR="$PROJECT_DIR/build"
BUNDLE_DIR="$BUILD_DIR/$APP_NAME.app"
DMG_STAGING="$BUILD_DIR/dmg-staging"
DMG_BACKGROUND="$BUILD_DIR/dmg-background.png"

# Get version from argument or git tag
VERSION="${1:-$(git describe --tags --abbrev=0 2>/dev/null || echo "dev")}"
DMG_NAME="$APP_NAME-$VERSION.dmg"
DMG_TEMP="$BUILD_DIR/$APP_NAME-temp.dmg"
DMG_FINAL="$BUILD_DIR/$DMG_NAME"

# DMG window dimensions
DMG_WIDTH=540
DMG_HEIGHT=400
ICON_SIZE=80
APP_X=135
APP_Y=195
APPS_X=405
APPS_Y=195

echo "Building $APP_NAME $VERSION..."
cd "$PROJECT_DIR"
swift build -c release

echo "Creating app bundle..."
rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR/Contents/MacOS"
mkdir -p "$BUNDLE_DIR/Contents/Resources"

# Copy binary
cp ".build/release/$APP_NAME" "$BUNDLE_DIR/Contents/MacOS/"

# Copy Info.plist
cp "$PROJECT_DIR/$APP_NAME/Info.plist" "$BUNDLE_DIR/Contents/"

# Copy app icon
cp "$PROJECT_DIR/AppIcon.icns" "$BUNDLE_DIR/Contents/Resources/"

# Create PkgInfo
echo -n "APPL????" > "$BUNDLE_DIR/Contents/PkgInfo"

echo "Generating DMG background..."
swift "$SCRIPT_DIR/generate-dmg-background.swift" "$DMG_BACKGROUND"

echo "Creating DMG staging..."
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING/.background"
cp -R "$BUNDLE_DIR" "$DMG_STAGING/"
cp "$DMG_BACKGROUND" "$DMG_STAGING/.background/background.png"
ln -s /Applications "$DMG_STAGING/Applications"

echo "Creating temporary DMG..."
rm -f "$DMG_TEMP" "$DMG_FINAL"

# Create read-write DMG
hdiutil create -volname "$APP_NAME" -srcfolder "$DMG_STAGING" -ov -format UDRW "$DMG_TEMP"

echo "Mounting DMG for customization..."
MOUNT_DIR=$(hdiutil attach -readwrite -noverify "$DMG_TEMP" | grep "/Volumes/$APP_NAME" | awk '{print $3}')

if [ -z "$MOUNT_DIR" ]; then
    echo "Error: Failed to mount DMG"
    exit 1
fi

echo "Customizing DMG window..."
# Use AppleScript to set window appearance
osascript <<EOF
tell application "Finder"
    tell disk "$APP_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {100, 100, $((100 + DMG_WIDTH)), $((100 + DMG_HEIGHT))}

        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to $ICON_SIZE
        set background picture of viewOptions to file ".background:background.png"

        set position of item "$APP_NAME.app" of container window to {$APP_X, $APP_Y}
        set position of item "Applications" of container window to {$APPS_X, $APPS_Y}

        close
        open

        update without registering applications
        delay 1
    end tell
end tell
EOF

# Make sure changes are written
sync

echo "Unmounting..."
hdiutil detach "$MOUNT_DIR" -quiet

echo "Converting to compressed DMG..."
hdiutil convert "$DMG_TEMP" -format UDZO -imagekey zlib-level=9 -o "$DMG_FINAL"
rm -f "$DMG_TEMP"

# Cleanup
rm -rf "$DMG_STAGING"
rm -f "$DMG_BACKGROUND"

echo ""
echo "Done! Created $DMG_FINAL"
echo "Size: $(du -h "$DMG_FINAL" | cut -f1)"
