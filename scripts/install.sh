#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
DERIVED_DATA=/tmp/hum-release-build

echo "▶ Building Hum (Release)..."
cd "$REPO_DIR"
xcodegen generate
xcodebuild build \
  -scheme Hum \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA" \
  2>&1 | grep -E "(error:|BUILD)"

APP=$(find "$DERIVED_DATA/Build/Products" -name "Hum.app" -type d | head -1)
if [ -z "$APP" ]; then
  echo "❌ Hum.app not found in build output"
  exit 1
fi

echo "▶ Installing to /Applications..."
rm -rf /Applications/Hum.app
cp -R "$APP" /Applications/Hum.app

echo "✅ Installed: /Applications/Hum.app"
echo "   Run: open /Applications/Hum.app"
