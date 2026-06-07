#!/usr/bin/env bash
#
# Build, Developer-ID sign, notarize, and staple a release DMG of Hum.
#
# This does NOT change the normal ad-hoc build — it overrides signing only at
# invocation time. Run it instead of the manual release steps once you have the
# prerequisites below.
#
# Prerequisites (one-time — see docs/NOTARIZATION.md):
#   1. A "Developer ID Application" certificate in your login keychain.
#   2. A stored notarytool credential profile, e.g.:
#        xcrun notarytool store-credentials "HumNotary" \
#          --apple-id "you@example.com" --team-id "HGD2NY6696" \
#          --password "<app-specific-password>"
#
# Usage:
#   DEVELOPER_ID="Developer ID Application: Rizki Arsyad (HGD2NY6696)" \
#   NOTARY_PROFILE="HumNotary" \
#   VERSION="1.3.0" \
#   scripts/notarize-release.sh
#
set -euo pipefail

: "${DEVELOPER_ID:?Set DEVELOPER_ID to your 'Developer ID Application: ...' identity}"
: "${NOTARY_PROFILE:?Set NOTARY_PROFILE to your stored notarytool keychain profile name}"
: "${VERSION:?Set VERSION, e.g. 1.3.0}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DIST="$ROOT/dist"
ARCHIVE="$DIST/Hum.xcarchive"
APP="$ARCHIVE/Products/Applications/Hum.app"
DMG="$DIST/Hum-$VERSION.dmg"
STAGE="$DIST/dmg-stage"
ENTITLEMENTS="$ROOT/Hum/Hum.entitlements"
FRAMEWORK="$APP/Contents/Resources/MediaRemoteAdapter/MediaRemoteAdapter.framework"

echo "==> Regenerating project"
xcodegen generate

echo "==> Archiving (Release · Developer ID · Hardened Runtime · secure timestamp)"
rm -rf "$ARCHIVE"
xcodebuild archive \
  -project Hum.xcodeproj -scheme Hum -configuration Release \
  -archivePath "$ARCHIVE" -destination 'generic/platform=macOS' \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$DEVELOPER_ID" \
  ENABLE_HARDENED_RUNTIME=YES \
  OTHER_CODE_SIGN_FLAGS="--timestamp"

# The MediaRemote adapter framework is bundled as a Resources folder reference,
# so Xcode does NOT sign it during archive. Sign it (inside-out), then re-seal
# the app so its signature covers the now-signed framework.
if [ -d "$FRAMEWORK" ]; then
  echo "==> Signing bundled MediaRemoteAdapter.framework"
  codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID" "$FRAMEWORK"
fi

echo "==> Re-sealing the app bundle"
codesign --force --options runtime --timestamp \
  --entitlements "$ENTITLEMENTS" \
  --sign "$DEVELOPER_ID" "$APP"

echo "==> Verifying signature + hardened runtime"
codesign --verify --strict --verbose=2 "$APP"
codesign --display --entitlements - "$APP" >/dev/null

echo "==> Building DMG"
rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/Hum.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "Hum" -srcfolder "$STAGE" -ov -format UDZO "$DMG"

echo "==> Submitting to notarytool (waits for the result — usually a few minutes)"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait

echo "==> Stapling the notarization ticket"
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

echo ""
echo "✅ Done: $DMG  (Developer-ID signed, notarized, stapled)"
echo "   Next: Sparkle-sign it (Sparkle/bin/sign_update), update appcast.xml, and"
echo "   create the GitHub release. Users no longer need --no-quarantine."
