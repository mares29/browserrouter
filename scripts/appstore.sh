#!/bin/bash
# Build, sign and package BrowserRouter.app for the Mac App Store

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_NAME="BrowserRouter"
BUILD_DIR="$PROJECT_DIR/build/appstore"
BUNDLE_DIR="$BUILD_DIR/$APP_NAME.app"
ENTITLEMENTS="$PROJECT_DIR/$APP_NAME/$APP_NAME.entitlements"

# Version from argument or git tag (v1.2.3 -> 1.2.3).
# The build number must grow with every upload; the commit count does.
VERSION="${1:-$(git describe --tags --abbrev=0 2>/dev/null)}"
VERSION="${VERSION#v}"
BUILD_NUMBER="${2:-$(git rev-list --count HEAD)}"

# Mac App Store profile for com.browserrouter.app, downloaded from the developer portal
PROFILE="${PROFILE:-$PROJECT_DIR/build/$APP_NAME.provisionprofile}"
APP_IDENTITY="${APP_IDENTITY:-Apple Distribution}"
INSTALLER_IDENTITY="${INSTALLER_IDENTITY:-3rd Party Mac Developer Installer}"

PKG="$PROJECT_DIR/build/$APP_NAME-$VERSION.pkg"

if [ -z "$VERSION" ]; then
    echo "Usage: $0 <version> [build-number]"
    exit 1
fi

if [ ! -f "$PROFILE" ]; then
    echo "Error: provisioning profile not found at $PROFILE"
    echo "Download the Mac App Store profile from the developer portal and put it there, or set PROFILE."
    exit 1
fi

echo "Building $APP_NAME $VERSION ($BUILD_NUMBER)..."
cd "$PROJECT_DIR"

# The default build system records the deployment target (13.0) as the SDK the binary
# was built with, and App Store Connect checks that. The native one records the real SDK,
# so build each architecture with it and merge them.
BINARIES=()
for ARCH in arm64 x86_64; do
    swift build -c release --build-system native --triple "$ARCH-apple-macosx13.0"
    BINARIES+=("$(swift build -c release --build-system native --triple "$ARCH-apple-macosx13.0" --show-bin-path)/$APP_NAME")
done

echo "Creating app bundle..."
rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR/Contents/MacOS"
mkdir -p "$BUNDLE_DIR/Contents/Resources"

# Universal binary
lipo -create -output "$BUNDLE_DIR/Contents/MacOS/$APP_NAME" "${BINARIES[@]}"

# Copy Info.plist
cp "$PROJECT_DIR/$APP_NAME/Info.plist" "$BUNDLE_DIR/Contents/"

# Stamp the version, and the toolchain keys Xcode would add
PLIST="$BUNDLE_DIR/Contents/Info.plist"
SDK_VERSION="$(xcrun --sdk macosx --show-sdk-version)"
SDK_BUILD="$(xcrun --sdk macosx --show-sdk-build-version)"
XCODE_VERSION="$(xcodebuild -version | awk '/^Xcode/ { print $2 }')"
XCODE_BUILD="$(xcodebuild -version | awk '/^Build version/ { print $3 }')"
IFS=. read -r XCODE_MAJOR XCODE_MINOR XCODE_PATCH <<< "$XCODE_VERSION"

/usr/libexec/PlistBuddy \
    -c "Set :CFBundleShortVersionString $VERSION" \
    -c "Set :CFBundleVersion $BUILD_NUMBER" \
    -c "Add :BuildMachineOSBuild string $(sw_vers -buildVersion)" \
    -c "Add :DTCompiler string com.apple.compilers.llvm.clang.1_0" \
    -c "Add :DTPlatformBuild string $SDK_BUILD" \
    -c "Add :DTPlatformName string macosx" \
    -c "Add :DTPlatformVersion string $SDK_VERSION" \
    -c "Add :DTSDKBuild string $SDK_BUILD" \
    -c "Add :DTSDKName string macosx$SDK_VERSION" \
    -c "Add :DTXcode string $(printf "%02d%d%d" "$XCODE_MAJOR" "${XCODE_MINOR:-0}" "${XCODE_PATCH:-0}")" \
    -c "Add :DTXcodeBuild string $XCODE_BUILD" \
    "$PLIST"

# Copy app icon
cp "$PROJECT_DIR/AppIcon.icns" "$BUNDLE_DIR/Contents/Resources/"

# Copy menu bar icon
cp "$PROJECT_DIR/assets/MenuBarIconTemplate.png" "$PROJECT_DIR/assets/MenuBarIconTemplate@2x.png" "$BUNDLE_DIR/Contents/Resources/"

# Create PkgInfo
echo -n "APPL????" > "$BUNDLE_DIR/Contents/PkgInfo"

# Embed the provisioning profile
cp "$PROFILE" "$BUNDLE_DIR/Contents/embedded.provisionprofile"

echo "Signing..."
xattr -cr "$BUNDLE_DIR"
codesign --force --sign "$APP_IDENTITY" --entitlements "$ENTITLEMENTS" "$BUNDLE_DIR"
codesign --verify --strict --verbose=2 "$BUNDLE_DIR"

echo "Creating installer package..."
rm -f "$PKG"
productbuild --component "$BUNDLE_DIR" /Applications --sign "$INSTALLER_IDENTITY" "$PKG"

echo ""
echo "Done! Created $PKG"
echo ""
echo "Next steps:"
echo "  1. Validate: xcrun altool --validate-app -f \"$PKG\" -t macos --api-key <KEY_ID> --api-issuer <ISSUER_ID>"
echo "  2. Upload:   xcrun altool --upload-app -f \"$PKG\" -t macos --api-key <KEY_ID> --api-issuer <ISSUER_ID>"
echo "     (or drag the .pkg into the Transporter app)"
