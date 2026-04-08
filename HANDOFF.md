# Handoff: XDRMonitorControl (MonitorControlXDR)

This document summarizes the changes made in this working session, the user-reported issues we debugged, and how they were resolved.

## What Changed

### Branding and Naming
- Renamed the app branding to **XDRMonitorControl** across the repo (README and UI strings).
- Updated README author/attribution from `@shayprasad` to `@shay2000`.
- Updated bundle identifiers to:
  - `com.shay2000.XDRMonitorControl`
  - `com.shay2000.XDRMonitorControlHelper`

Primary files:
- `README.md`
- `MonitorControl.xcodeproj/project.pbxproj`
- `MonitorControl/Info.plist`
- `MonitorControlHelper/Info.plist`

### App Icon Refresh
- Updated the app icon to a brighter “sun / XDR brightness” feel.
- Fixed the AppIcon asset catalog warnings by ensuring every icon PNG matches the exact pixel dimensions Xcode expects.
- Updated the README/social image to show the new icon.

Primary files:
- `MonitorControl/Assets.xcassets/AppIcon.appiconset/*`
- `.github/Icon-cropped.png`
- `README.md`

### Build/Distribution Improvements
- Updated the build script to consistently output `build/XDRMonitorControl.app`.
- Added robust handling for environments with **no valid Developer ID / Apple Development code signing identity**:
  - If a signing identity exists, prefer a properly signed build.
  - Otherwise, fall back to **ad-hoc signing** for local running/testing.
- Improved the copy/sign process to avoid macOS bundle metadata issues after copying:
  - Uses `ditto --norsrc` where appropriate.
  - Strips extended attributes recursively (xattrs) that can break app validity.

Primary file:
- `build/build.sh`

### Accessibility Prompt/Behavior Improvements
- Updated the accessibility permission prompt copy to reference the **actual app name** dynamically and guide users to remove/re-add the app if it was already enabled for a different build.

Primary file:
- `MonitorControl/Support/MediaKeyTapManager.swift`

## Issues Reported and How They Were Solved

### 1) “Accessibility is enabled but I still get the error”

Root cause:
- This machine has **no valid code signing identities** available, so builds are **ad-hoc signed**.
- On macOS, Accessibility trust can behave unexpectedly across rebuilds/copies when the app’s identity changes (common with ad-hoc signed bundles). Users often need to remove and re-add the exact app bundle they are running.

Fixes:
- Ensured bundle identifiers are correct and stable (`com.shay2000.*`) in `project.pbxproj`.
- Updated `MediaKeyTapManager.acquirePrivileges()` to:
  - Use the real app name in the alert.
  - Provide explicit guidance to remove/re-add the app in Accessibility.
- Ensured the actual runnable app is the one in `build/XDRMonitorControl.app` (not an older copy elsewhere).

Verification steps:
- Remove any prior Accessibility entry for the app.
- Add the exact `build/XDRMonitorControl.app` bundle.
- Quit/relaunch that same app bundle.

### 2) “Double-clicking the app does nothing”

There were two overlapping reasons:

1. The app is an **LSUIElement menu bar app**, so double-clicking will not open a normal window. The UI appears in the menu bar.

2. The app was **launching and immediately dying** due to Sparkle library validation on ad-hoc signed builds:
   - macOS logs showed Library Validation rejecting `Sparkle.framework` because the host process and the framework mapping did not satisfy AMFI/library validation requirements for that ad-hoc signed bundle.

Root cause:
- Debug already had an entitlements file that disables library validation, but Release did not.
- Release configuration was missing `CODE_SIGN_ENTITLEMENTS`, so the ad-hoc signed Release build didn’t carry `com.apple.security.cs.disable-library-validation`.

Fix:
- Added `CODE_SIGN_ENTITLEMENTS = MonitorControl/MonitorControlDebug.entitlements` to the Release build configuration in `MonitorControl.xcodeproj/project.pbxproj`.
- Updated build/sign steps so the final app bundle is signed (even ad-hoc) with entitlements applied.

How we validated:
- Confirmed the built app includes `com.apple.security.cs.disable-library-validation = true` via `codesign -d --entitlements :-`.
- Verified bundle integrity via `codesign --verify --deep --strict`.
- Launched with `open -n build/XDRMonitorControl.app` and confirmed it stays running.

## Operational Notes

### Ad-hoc Signing Caveat
If you rebuild often on a machine with no signing identities:
- The app remains ad-hoc signed.
- Accessibility permission may need to be removed/re-added after rebuilds, and you must add the **exact** app bundle you are running.

### Where the Build Output Goes
- The build script produces: `build/XDRMonitorControl.app`

## Files Modified in This Session (Tracked)
- `.github/Icon-cropped.png`
- `MonitorControl.xcodeproj/project.pbxproj`
- `MonitorControl/Assets.xcassets/AppIcon.appiconset/*`
- `MonitorControl/Enums/PrefKey.swift`
- `MonitorControl/Info.plist`
- `MonitorControl/Model/AppleDisplay.swift`
- `MonitorControl/Model/Display.swift`
- `MonitorControl/Support/AppDelegate.swift`
- `MonitorControl/Support/MediaKeyTapManager.swift`
- `MonitorControl/Support/MenuHandler.swift`
- `MonitorControl/Support/SliderHandler.swift`
- `MonitorControlHelper/Info.plist`
- `README.md`
- `build/build.sh`

## Files Not Intended for Commit
- `build/DerivedData/`
- `build/DerivedDataSigned/`
- `build/XDRMonitorControl.app/`
- `.vscode/`

