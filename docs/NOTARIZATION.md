# Notarizing Hum

Notarization lets users open Hum without `--no-quarantine` or the "Open Anyway"
dance. It requires Apple credentials that only the account holder can create — so
this is a one-time setup you do, after which `scripts/notarize-release.sh` does
the rest.

The normal ad-hoc build is unchanged; the script overrides signing only when run.

## Cutting a release

Once the one-time prerequisites below are in place, a release is one command:

```bash
VERSION="1.4.0" scripts/release.sh
```

`scripts/release.sh` wraps `notarize-release.sh` and then performs every step
that used to be manual and order-sensitive:

1. **Preflight** — on `main`, clean tree, level with `origin/main`, `VERSION`
   matches `Info.plist`, a `## [VERSION]` section exists in the changelog, the
   tag is free, `sign_update` is present, `gh` is authenticated.
2. **Build** — Developer ID sign, notarize and staple (both the `.app` and the
   DMG), via `notarize-release.sh`.
3. **Verify** — the same checks a user's Mac performs: Gatekeeper on the DMG,
   on the app inside it, and a stapled ticket on both.
4. **Publish** — tag, push, create the GitHub release, then re-download the
   published asset and confirm its sha256 matches what was signed.
5. **Appcast** — generate the entry (changelog markdown is converted to the
   HTML Sparkle renders), validate the XML, commit and push. This runs *after*
   the asset is live, so no update check can hit a 404.
6. **Cask** — bump version and sha256 in `rzkarsyad/homebrew-hum`.

`main` is branch-protected and requires the `xcodebuild test` check. Admins can
still push directly, which is what step 5 does; if that push is ever refused the
script opens a PR instead and tells you Sparkle will not offer the update until
it is merged.

Rehearse without publishing anything:

```bash
VERSION="1.4.0" DRY_RUN=1 scripts/release.sh
```

Signing material never leaves this Mac — the Developer ID certificate, the
notarytool credentials and the Sparkle EdDSA private key are all read from the
local keychain. That is why this is a script rather than a CI workflow.
`.github/workflows/appcast.yml` covers the part that needs no secrets: it
checks every enclosure URL resolves and that each declared `length` matches the
real asset.

## One-time prerequisites

You already have a paid Apple Developer account (Team `HGD2NY6696`), but you need
two things you don't have yet.

### 1. A "Developer ID Application" certificate

You currently have *Apple Development* and *Apple Distribution* (App Store) certs.
Notarized **direct distribution** (DMG / Homebrew) needs the **Developer ID
Application** cert specifically.

- Xcode → **Settings → Accounts** → select your team → **Manage Certificates…**
  → **+** → **Developer ID Application**.
  (Requires the Account Holder role on the team.)
- Confirm it landed:
  ```bash
  security find-identity -v -p codesigning | grep "Developer ID Application"
  ```

### 2. A notarytool credential profile

Create an **app-specific password** at <https://appleid.apple.com> → Sign-In and
Security → App-Specific Passwords. Then store it once:

```bash
xcrun notarytool store-credentials "HumNotary" \
  --apple-id "you@example.com" \
  --team-id "HGD2NY6696" \
  --password "abcd-efgh-ijkl-mnop"   # the app-specific password
```

(Alternatively use an App Store Connect API key with `--key/--key-id/--issuer`.)

## Releasing a notarized build

```bash
DEVELOPER_ID="Developer ID Application: Rizki Arsyad (HGD2NY6696)" \
NOTARY_PROFILE="HumNotary" \
VERSION="1.3.0" \
scripts/notarize-release.sh
```

This archives a Release build with Developer-ID signing + Hardened Runtime,
signs the bundled MediaRemote adapter framework (a Resources folder reference
Xcode doesn't auto-sign), builds the DMG, submits to notarytool, waits, and
staples the ticket.

You rarely want to run this directly — `scripts/release.sh` calls it and then
finishes the release in the right order. Publish the GitHub release *before*
writing the appcast entry: an appcast pointing at an asset that is not live yet
404s for every client checking for updates.

## Notes / gotchas to validate on first run

- **Sparkle's nested code is NOT signed by the archive step.** `Updater.app`,
  `Autoupdate` and the two XPC services ship ad-hoc signed (`Signature=adhoc`)
  and Xcode does not descend into the framework, so notarization rejects them
  for lacking a Developer ID signature and a secure timestamp. `notarize-release.sh`
  signs them inside-out before re-sealing the app. If notarytool ever flags
  something else, `xcrun notarytool log <submission-id> --keychain-profile HumNotary`
  names the exact path.
- **`CFBundlePackageType` must be `APPL`.** Without it Gatekeeper assesses the
  bundle as "the code is valid but does not seem to be an app" and refuses it —
  notarization still succeeds, so this only shows up when someone opens the app.
- **Staple the `.app`, not just the DMG.** Stapling only the DMG leaves the copy
  a user drags to /Applications without a ticket, so its first launch needs an
  online check with Apple. The script notarizes and staples the app first, then
  wraps it.
- The MediaRemote adapter works because **/usr/bin/perl** (Apple-signed) loads
  the framework — the app's Hardened Runtime doesn't affect that separate
  process, so browser detection keeps working after notarization.
- First run in anger was v1.3.0 (2026-09-12). Apple accepted both submissions
  and the published DMG, the app inside it, and a copy dragged out all report
  `accepted / source=Notarized Developer ID` with a valid stapled ticket.
