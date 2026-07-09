#!/bin/bash
# build.sh — builds Bitrail.app from the Swift Package, no Xcode project needed.
# Usage: bash build.sh
set -e

APP_NAME="Bitrail"
BUNDLE_ID="com.bitrail.app"
VERSION="${VERSION:-0.6.3}"
ARCH=$(uname -m)
BUILD_DIR="$(pwd)/build"
APP="$BUILD_DIR/$APP_NAME.app"
SPM_RELEASE_DIR=".build/${ARCH}-apple-macosx/release"

echo "→ Building $APP_NAME $VERSION ($ARCH)..."

swift build -c release

rm -rf "$BUILD_DIR"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

# ── Executable + dylibs (kept side by side, matches the @loader_path rpath SPM sets) ──
cp "$SPM_RELEASE_DIR/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
cp "$SPM_RELEASE_DIR"/*.dylib "$APP/Contents/MacOS/" 2>/dev/null || true

# ── Info.plist + icon ──
cp Info.plist "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
[ -f AppIcon.icns ] && cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# ── Ad-hoc sign (before adding the resource bundle below - codesign rejects
#    any loose item at the bundle root that isn't "Contents") ──
codesign --sign - --force --deep "$APP"

# ── mediaremote-adapter's resource bundle (run.pl) — its Bundle.module
#    accessor looks at Bundle.main.bundleURL, i.e. the .app root, not
#    Contents/Resources, so it must land here post-signing. ──
cp -R "$SPM_RELEASE_DIR"/*.bundle "$APP/" 2>/dev/null || true

echo ""
echo "✓ Built:   $APP"
echo "✓ Version: $VERSION"
echo ""
echo "  Launch: open \"$APP\""
echo ""
