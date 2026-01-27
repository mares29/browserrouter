#!/bin/bash
# Build and bundle BrowserRouter.app

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_NAME="BrowserRouter"
BUNDLE_DIR="$PROJECT_DIR/build/$APP_NAME.app"
INSTALL_DIR="$HOME/Applications"

echo "Building $APP_NAME..."
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

echo "Installing to $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR"
rm -rf "$INSTALL_DIR/$APP_NAME.app"
cp -R "$BUNDLE_DIR" "$INSTALL_DIR/"

echo ""
echo "Done! $APP_NAME.app installed to $INSTALL_DIR"
echo ""
echo "Next steps:"
echo "  1. Open $INSTALL_DIR/$APP_NAME.app"
echo "  2. Go to System Settings → Desktop & Dock → Default web browser"
echo "  3. Select BrowserRouter from the dropdown"
echo ""
echo "Or run: open '$INSTALL_DIR/$APP_NAME.app'"
