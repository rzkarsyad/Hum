# Hum — Launch at Login + Standalone .app Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Hum installable as a standalone .app (no Xcode needed) and add a "Launch at Login" toggle in the status bar menu.

**Architecture:** Two independent tasks — (1) switch the Hum target to ad-hoc code signing, add `ServiceManagement` dependency, and create a `scripts/install.sh` that builds Release and copies to `/Applications`; (2) wrap `SMAppService.mainApp` in a thin `LaunchAtLoginManager` and wire a checkmark menu item into the existing `StatusBarController`.

**Tech Stack:** ServiceManagement framework (`SMAppService`, macOS 13+), xcodegen, Bash

---

## File Map

| Path | Change |
|------|--------|
| `project.yml` | Switch Hum target from `CODE_SIGNING_ALLOWED: NO` to ad-hoc signing; add `ServiceManagement.framework` dependency |
| `scripts/install.sh` | New: build Release + copy `Hum.app` to `/Applications` |
| `Hum/LaunchAtLogin/LaunchAtLoginManager.swift` | New: thin wrapper around `SMAppService.mainApp` |
| `Hum/StatusBar/StatusBarController.swift` | Add "Launch at Login" checkmark menu item + toggle action |

---

### Task 1: Ad-hoc signing + install script

**Files:**
- Modify: `project.yml`
- Create: `scripts/install.sh`

- [ ] **Step 1: Update `project.yml` — switch to ad-hoc signing and add ServiceManagement**

The current Hum target `settings.base` block (lines 12–17) uses `CODE_SIGNING_ALLOWED: "NO"`.
Replace it and add a `dependencies` key at the same level as `settings`:

```yaml
name: Hum
options:
  bundleIdPrefix: com.rzkarsyad
  deploymentTarget:
    macOS: "13.0"
targets:
  Hum:
    type: application
    platform: macOS
    sources:
      - Hum
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.rzkarsyad.Hum
        SWIFT_VERSION: "5.9"
        INFOPLIST_FILE: Hum/Info.plist
        CODE_SIGN_IDENTITY: "-"
        CODE_SIGN_STYLE: Manual
    entitlements:
      path: Hum/Hum.entitlements
      properties:
        com.apple.security.app-sandbox: false
        com.apple.security.automation.apple-events: true
        com.apple.security.network.client: true
    dependencies:
      - sdk: ServiceManagement.framework
  HumTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - HumTests
    dependencies:
      - target: Hum
    settings:
      base:
        MACOSX_DEPLOYMENT_TARGET: "13.0"
        SWIFT_VERSION: "5.9"
        CODE_SIGNING_ALLOWED: "NO"
```

Key changes to the Hum target:
- `CODE_SIGNING_ALLOWED: "NO"` → `CODE_SIGN_IDENTITY: "-"` (ad-hoc) + `CODE_SIGN_STYLE: Manual`
- Added `dependencies: [sdk: ServiceManagement.framework]`
- `HumTests` is unchanged

- [ ] **Step 2: Regenerate project and verify build**

```bash
cd /Users/rzkarsyad/Documents/Codes/Hum
xcodegen generate
xcodebuild build -scheme Hum -configuration Release -destination 'platform=macOS' 2>&1 | grep -E "(error:|BUILD)"
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Create `scripts/install.sh`**

```bash
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
```

- [ ] **Step 4: Make executable and run**

```bash
chmod +x scripts/install.sh
bash scripts/install.sh
```

Expected output ends with: `✅ Installed: /Applications/Hum.app`

- [ ] **Step 5: Verify the installed app launches without Xcode**

```bash
# Quit any running Hum first (click menu bar icon → Quit Hum)
open /Applications/Hum.app
```

Expected: music note icon appears in menu bar within 2 seconds, without Xcode running.

- [ ] **Step 6: Commit**

```bash
git add project.yml Hum.xcodeproj/ scripts/install.sh
git commit -m "feat: ad-hoc signing and install script for standalone distribution"
```

---

### Task 2: Launch at Login

**Files:**
- Create: `Hum/LaunchAtLogin/LaunchAtLoginManager.swift`
- Modify: `Hum/StatusBar/StatusBarController.swift`

- [ ] **Step 1: Create `Hum/LaunchAtLogin/` directory and `LaunchAtLoginManager.swift`**

```swift
import ServiceManagement

@MainActor
final class LaunchAtLoginManager {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Fails silently when running outside /Applications — expected in development
        }
    }
}
```

- [ ] **Step 2: Add "Launch at Login" menu item to `buildMenu()` in `StatusBarController.swift`**

In `buildMenu()`, find the current closing block:

```swift
        menu.addItem(.separator())
        menu.addItem(
            NSMenuItem(title: "Quit Hum", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        )

        statusItem.menu = menu
```

Replace with:

```swift
        menu.addItem(.separator())

        let loginItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin(_:)),
            keyEquivalent: ""
        )
        loginItem.state = LaunchAtLoginManager.isEnabled ? .on : .off
        loginItem.target = self
        menu.addItem(loginItem)

        menu.addItem(.separator())
        menu.addItem(
            NSMenuItem(title: "Quit Hum", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        )

        statusItem.menu = menu
```

- [ ] **Step 3: Add `toggleLaunchAtLogin` action to `StatusBarController`**

Add this method directly after `offsetChanged`:

```swift
    @objc private func toggleLaunchAtLogin(_ item: NSMenuItem) {
        LaunchAtLoginManager.setEnabled(!LaunchAtLoginManager.isEnabled)
        item.state = LaunchAtLoginManager.isEnabled ? .on : .off
    }
```

- [ ] **Step 4: Regenerate project and build**

```bash
mkdir -p Hum/LaunchAtLogin
xcodegen generate
xcodebuild build -scheme Hum -destination 'platform=macOS' 2>&1 | grep -E "(error:|BUILD)"
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Re-install and manually verify**

```bash
bash scripts/install.sh
open /Applications/Hum.app
```

Manual checks:
- Click menu bar icon → "Launch at Login" item appears below the stepper
- Click "Launch at Login" → checkmark toggles on
- Open **System Settings → General → Login Items & Extensions** → Hum should appear in the list
- Click "Launch at Login" again → checkmark toggles off → Hum disappears from Login Items
- Quit and relaunch → checkmark state is restored correctly

- [ ] **Step 6: Commit**

```bash
git add Hum/LaunchAtLogin/LaunchAtLoginManager.swift Hum/StatusBar/StatusBarController.swift Hum.xcodeproj/
git commit -m "feat: Launch at Login toggle using SMAppService"
```
