#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/codex-menu-quota.xcodeproj"
SCHEME="codex-menu-quota"
DERIVED_DATA="$ROOT_DIR/.build/dmg-derived-data"
OUTPUT_DIR="$ROOT_DIR/dist"

VERSION="${VERSION:-$(xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration Release \
  -showBuildSettings 2>/dev/null | awk '/MARKETING_VERSION =/ { print $3; exit }')}"

DMG_PATH="$OUTPUT_DIR/codex-menu-quota-${VERSION}.dmg"
APP_SOURCE="$DERIVED_DATA/Build/Products/Release/codex-menu-quota.app"
STAGING_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

echo "Building Release app…"
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -derivedDataPath "$DERIVED_DATA" \
  build

mkdir -p "$OUTPUT_DIR"
ditto "$APP_SOURCE" "$STAGING_DIR/codex-menu-quota.app"
ln -s /Applications "$STAGING_DIR/Applications"

echo "Creating DMG…"
hdiutil create \
  -volname "codex-menu-quota" \
  -srcfolder "$STAGING_DIR" \
  -format UDZO \
  -ov \
  "$DMG_PATH"

echo "DMG created: $DMG_PATH"
