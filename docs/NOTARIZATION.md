# Notarizing Hum

Notarization lets users open Hum without `--no-quarantine` or the "Open Anyway"
dance. It requires Apple credentials that only the account holder can create — so
this is a one-time setup you do, after which `scripts/notarize-release.sh` does
the rest.

The normal ad-hoc build is unchanged; the script overrides signing only when run.

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

After it succeeds, finish the release as usual:
1. Sparkle-sign the DMG: `…/Sparkle/bin/sign_update dist/Hum-<version>.dmg`
2. Add the `appcast.xml` entry with that signature.
3. `gh release create v<version> dist/Hum-<version>.dmg …`

## Then drop `--no-quarantine`

Once notarized, update the install instructions:
- `README.md` — remove the `--no-quarantine` flag and the "Open Anyway" note.
- The Homebrew cask (`rzkarsyad/homebrew-hum`) — drop `--no-quarantine` from the
  caveats; a notarized cask installs cleanly.

## Notes / gotchas to validate on first run

- **Sparkle** has nested XPC services and helper apps; the archive step signs
  them with your Developer ID. If notarytool flags any unsigned nested code, run
  `xcrun notarytool log <submission-id> --keychain-profile HumNotary` to see
  exactly which item, and add an explicit `codesign` step for it before the DMG.
- The MediaRemote adapter works because **/usr/bin/perl** (Apple-signed) loads
  the framework — the app's Hardened Runtime doesn't affect that separate
  process, so browser detection keeps working after notarization.
- This script has not been run yet (no Developer ID cert exists at authoring
  time). Validate end-to-end on the first real run and adjust if notarytool
  reports a nested-signing issue.
