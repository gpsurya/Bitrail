#!/bin/bash
# package.sh — builds Bitrail and creates a distributable DMG
# Usage: bash package.sh
set -e

APP_NAME="Bitrail"
VERSION="${VERSION:-0.6.2}"
BUILD_DIR="$(pwd)/build"
APP="$BUILD_DIR/$APP_NAME.app"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
DMG_OUT="$(pwd)/$DMG_NAME"
STAGING="/tmp/${APP_NAME}_dmg_staging"
TMP_DMG="/tmp/${APP_NAME}_rw.dmg"

VERSION="$VERSION" bash build.sh

echo "→ Staging DMG content..."
rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -r "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

echo "→ Creating DMG..."
rm -f "$TMP_DMG" "$DMG_OUT"

hdiutil create \
  -volname "$APP_NAME $VERSION" \
  -srcfolder "$STAGING" \
  -ov -format UDRW \
  -size 40m \
  "$TMP_DMG" > /dev/null

hdiutil convert "$TMP_DMG" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "$DMG_OUT" > /dev/null

rm -f "$TMP_DMG"
rm -rf "$STAGING"

SIZE=$(du -sh "$DMG_OUT" | cut -f1)
echo ""
echo "✓ $DMG_NAME ($SIZE)"
echo "  Path: $DMG_OUT"
