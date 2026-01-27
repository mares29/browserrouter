#!/bin/bash
# Build BrowserRouter.app and create release zip

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_NAME="BrowserRouter"
BUILD_DIR="$PROJECT_DIR/build"
BUNDLE_DIR="$BUILD_DIR/$APP_NAME.app"

# Get version from argument or git tag
VERSION="${1:-$(git describe --tags --abbrev=0 2>/dev/null || echo "dev")}"
ZIP_NAME="$APP_NAME-$VERSION.zip"

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

echo "Creating zip..."
cd "$BUILD_DIR"
rm -f "$ZIP_NAME"
zip -r "$ZIP_NAME" "$APP_NAME.app"

echo ""
echo "Done! Created $BUILD_DIR/$ZIP_NAME"
