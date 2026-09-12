#!/usr/bin/env bash
#
# Publish a Hum release, end to end, in one command.
#
# Wraps notarize-release.sh and then performs every step that used to be manual
# and order-sensitive: tag, GitHub release, appcast entry, Homebrew cask. The
# order matters — the appcast must only point at a DMG that is already
# downloadable, or Sparkle clients get a 404 — so the script enforces it.
#
# Signing material never leaves this Mac: the Developer ID certificate, the
# notarytool credentials and the Sparkle EdDSA private key are all read from
# the local keychain. That is why this is a local script and not a CI workflow.
#
# Prerequisites (one-time — see docs/NOTARIZATION.md):
#   1. A "Developer ID Application" certificate in your login keychain.
#   2. A stored notarytool credential profile (see notarize-release.sh).
#   3. The Sparkle EdDSA private key in your keychain (generate_keys).
#   4. `gh` authenticated with push access to Hum and homebrew-hum.
#
# Usage:
#   VERSION="1.4.0" scripts/release.sh
#   VERSION="1.4.0" DRY_RUN=1 scripts/release.sh     # rehearse, publish nothing
#
set -euo pipefail

VERSION="${VERSION:?Set VERSION, e.g. 1.4.0}"
DEVELOPER_ID="${DEVELOPER_ID:-Developer ID Application: Rizki Arsyad (HGD2NY6696)}"
NOTARY_PROFILE="${NOTARY_PROFILE:-HumNotary}"
TAP_REPO="${TAP_REPO:-rzkarsyad/homebrew-hum}"
DRY_RUN="${DRY_RUN:-}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DMG="$ROOT/dist/Hum-$VERSION.dmg"
TAG="v$VERSION"
REPO_SLUG="$(gh repo view --json nameWithOwner -q .nameWithOwner)"

say()  { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
fail() { printf '\033[31merror: %s\033[0m\n' "$*" >&2; exit 1; }
run()  { if [ -n "$DRY_RUN" ]; then printf '   [dry-run] %s\n' "$*"; else eval "$@"; fi; }

# ---------------------------------------------------------------- preflight
# Every check that can fail cheaply runs before anything is published, so a
# mistake costs seconds rather than a half-published release.
say "Preflight"

[ -n "$DRY_RUN" ] && echo "   DRY RUN — nothing will be tagged, pushed or published"

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
[ "$BRANCH" = "main" ] || [ -n "$DRY_RUN" ] || fail "on branch '$BRANCH' — release from main"

if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
  [ -n "$DRY_RUN" ] || fail "working tree has uncommitted changes to tracked files"
  echo "   note: working tree is dirty (ignored in dry run)"
fi

git fetch -q origin main
if [ "$(git rev-parse HEAD)" != "$(git rev-parse origin/main)" ] && [ -z "$DRY_RUN" ]; then
  fail "HEAD is not level with origin/main — push or pull first"
fi

PLIST_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Hum/Info.plist)"
[ "$PLIST_VERSION" = "$VERSION" ] || fail "Info.plist says $PLIST_VERSION but VERSION is $VERSION"
BUILD_NUMBER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' Hum/Info.plist)"

grep -q "^## \[$VERSION\]" CHANGELOG.md || fail "CHANGELOG.md has no '## [$VERSION]' section"

if git rev-parse "$TAG" >/dev/null 2>&1; then
  [ -n "$DRY_RUN" ] || fail "tag $TAG already exists"
  echo "   note: tag $TAG already exists (ignored in dry run)"
fi

SIGN_UPDATE="$(find "$HOME/Library/Developer/Xcode/DerivedData" \
  -path '*/artifacts/sparkle/Sparkle/bin/sign_update' -type f 2>/dev/null | head -1)"
[ -n "$SIGN_UPDATE" ] || fail "sign_update not found — build the project once so SPM fetches Sparkle"

gh auth status >/dev/null 2>&1 || fail "gh is not authenticated"

echo "   repo          $REPO_SLUG"
echo "   version       $VERSION (build $BUILD_NUMBER)"
echo "   tag           $TAG"
echo "   identity      $DEVELOPER_ID"
echo "   notary        $NOTARY_PROFILE"

# ------------------------------------------------------------------- build
say "Build, sign, notarize, staple"
if [ -n "$DRY_RUN" ] && [ -f "$DMG" ]; then
  echo "   [dry-run] reusing existing $DMG"
else
  DEVELOPER_ID="$DEVELOPER_ID" NOTARY_PROFILE="$NOTARY_PROFILE" VERSION="$VERSION" \
    bash scripts/notarize-release.sh
fi
[ -f "$DMG" ] || fail "expected $DMG"

# ------------------------------------------------------------------ verify
# The same checks a user's Mac performs, run here so a bad build is caught
# before it is published rather than by whoever downloads it.
say "Verify the artifact"

spctl -a -t open --context context:primary-signature "$DMG" >/dev/null 2>&1 \
  || fail "Gatekeeper rejected the DMG"
xcrun stapler validate "$DMG" >/dev/null || fail "DMG has no stapled ticket"

MOUNT="$(hdiutil attach "$DMG" -nobrowse -readonly | grep -o '/Volumes/.*' | head -1)"
trap '[ -n "${MOUNT:-}" ] && hdiutil detach "$MOUNT" -quiet 2>/dev/null || true' EXIT
spctl -a -t exec "$MOUNT/Hum.app" >/dev/null 2>&1 \
  || fail "Gatekeeper rejected Hum.app inside the DMG"
xcrun stapler validate "$MOUNT/Hum.app" >/dev/null \
  || fail "Hum.app inside the DMG has no stapled ticket (it must work offline)"
hdiutil detach "$MOUNT" -quiet; MOUNT=""

SHA256="$(shasum -a 256 "$DMG" | awk '{print $1}')"
LENGTH="$(stat -f%z "$DMG")"
ED_SIGNATURE="$("$SIGN_UPDATE" "$DMG" | sed -n 's/.*sparkle:edSignature="\([^"]*\)".*/\1/p')"
[ -n "$ED_SIGNATURE" ] || fail "sign_update produced no signature"

echo "   sha256        $SHA256"
echo "   length        $LENGTH"
echo "   edSignature   ${ED_SIGNATURE:0:24}…"

# ---------------------------------------------------------------- publish
say "Tag and publish the GitHub release"

NOTES="$(awk -v v="$VERSION" '
  $0 ~ "^## \\[" v "\\]" {found=1; next}
  found && /^## \[/ {exit}
  found {print}
' CHANGELOG.md)"
[ -n "$NOTES" ] || fail "could not extract release notes for $VERSION from CHANGELOG.md"

run "git tag -a '$TAG' -m 'Hum $TAG'"
run "git push -q origin '$TAG'"
run "gh release create '$TAG' '$DMG' --title 'Hum $TAG' --notes \"\$(printf '%s' \"\$NOTES\")\""

# The appcast may only point at an asset that is already downloadable.
if [ -z "$DRY_RUN" ]; then
  say "Confirm the published asset matches what was signed"
  TMP="$(mktemp -d)"
  gh release download "$TAG" --repo "$REPO_SLUG" --pattern '*.dmg' --dir "$TMP"
  PUBLISHED_SHA="$(shasum -a 256 "$TMP/Hum-$VERSION.dmg" | awk '{print $1}')"
  rm -rf "$TMP"
  [ "$PUBLISHED_SHA" = "$SHA256" ] || fail "published asset sha256 $PUBLISHED_SHA != $SHA256"
  echo "   published asset matches"
fi

# ---------------------------------------------------------------- appcast
say "Appcast entry"

PUB_DATE="$(date -u '+%a, %d %b %Y %H:%M:%S +0000')"

APPCAST_TARGET="appcast.xml"
if [ -n "$DRY_RUN" ]; then
  APPCAST_TARGET="$(mktemp -d)/appcast.xml"
  cp appcast.xml "$APPCAST_TARGET"
fi

APPCAST="$APPCAST_TARGET" NOTES="$NOTES" VERSION="$VERSION" \
BUILD_NUMBER="$BUILD_NUMBER" PUB_DATE="$PUB_DATE" REPO_SLUG="$REPO_SLUG" \
TAG="$TAG" ED_SIGNATURE="$ED_SIGNATURE" LENGTH="$LENGTH" \
PRINT_ENTRY="$DRY_RUN" \
  python3 scripts/appcast-entry.py

run "git add appcast.xml"
run "git commit -q -m 'chore: appcast entry for $TAG'"

# main is branch-protected. An admin can still push directly (that is why
# enforce_admins is off), but if the push is refused — protection tightened,
# or this is not an admin's machine — fall back to a PR rather than leaving
# the release published with no matching feed entry.
if [ -n "$DRY_RUN" ]; then
  echo "   [dry-run] git push origin main"
elif git push -q origin main 2>/dev/null; then
  echo "   appcast pushed to main"
else
  APPCAST_BRANCH="chore/appcast-$TAG"
  git push -q origin "HEAD:$APPCAST_BRANCH"
  PR_URL="$(gh pr create --head "$APPCAST_BRANCH" \
    --title "chore: appcast entry for $TAG" \
    --body "Generated by scripts/release.sh for $TAG. Merging this publishes the update feed.")"
  git reset -q --hard origin/main
  echo "   main is protected — opened $PR_URL"
  echo "   NOTE: Sparkle will not offer $TAG until that PR is merged."
fi

# -------------------------------------------------------------------- tap
say "Homebrew cask"

if [ -n "$DRY_RUN" ]; then
  echo "   [dry-run] would set $TAP_REPO Casks/hum.rb to $VERSION / $SHA256"
else
  TAP_DIR="$(mktemp -d)"
  gh repo clone "$TAP_REPO" "$TAP_DIR" -- -q
  python3 - "$TAP_DIR/Casks/hum.rb" "$VERSION" "$SHA256" <<'PY'
import io, re, sys
path, version, sha = sys.argv[1], sys.argv[2], sys.argv[3]
s = io.open(path, encoding="utf-8").read()
s = re.sub(r'version "[^"]+"', 'version "%s"' % version, s, count=1)
s = re.sub(r'sha256 "[0-9a-f]{64}"', 'sha256 "%s"' % sha, s, count=1)
io.open(path, "w", encoding="utf-8").write(s)
PY
  git -C "$TAP_DIR" add Casks/hum.rb
  git -C "$TAP_DIR" commit -q -m "hum $VERSION"
  git -C "$TAP_DIR" push -q
  rm -rf "$TAP_DIR"
  echo "   cask updated to $VERSION"
fi

say "Done"
echo "   release   https://github.com/$REPO_SLUG/releases/tag/$TAG"
echo "   appcast   https://raw.githubusercontent.com/$REPO_SLUG/main/appcast.xml"
