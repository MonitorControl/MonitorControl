# Modern volume OSD experiment

This is an opt-in, volume-only prototype based on upstream commit 84ac2d7.
It draws a small horizontal capsule with AppKit's public NSGlassEffectView
on macOS 26+. It is inspired by Tahoe's feedback, not Apple's system OSD.
The standalone demo does not change audio, DDC, permissions or preferences.

## Standalone demo (Command Line Tools, macOS 26+)

From the repository root:

```sh
swiftc -swift-version 5 MonitorControl/Support/ModernVolumeOSD.swift Prototype/main.swift -o /tmp/modern-volume-demo
/tmp/modern-volume-demo --self-test
/tmp/modern-volume-demo --lifecycle-test
/tmp/modern-volume-demo
```

The checks cover normalized levels, invalid inputs, missing-display fallback,
a new key event during fade-out, auto-dismiss, mute display and cleanup.
Use the demo buttons and display picker for visual inspection.

## Integration experiment (full Xcode and macOS 26 SDK required)

The existing DDC and mute implementations are unchanged. OSDUtils routes
volume/mute feedback to the new renderer only when modernVolumeOSD is true,
on macOS 26+, and the display/value are usable. Classic feedback remains
the default. Brightness, contrast, locked and unavailable states remain classic.

Enable the flag only for a separately built development copy:

```sh
defaults write <development-bundle-id> modernVolumeOSD -bool true
```

Use an isolated bundle identifier/preferences domain for that copy, so the
working installed release stays unaffected. Remove the experimental flag to
restore classic feedback. This prototype intentionally has no settings UI
until the maintainer agrees on the scope.

## Validation completed

- Full isolated Debug build with Xcode 26.5 and pinned dependencies: passed.
- Real keyboard volume up/down and mute with a Dell S2725QC: user confirmed.
- Standalone normalization and lifecycle checks: passed for this prototype.
- Targeted Intel macOS 10.14 type-check: passed; older-system execution untested.

The custom black capsule was not accepted by the user during visual review.
The original release was restored, and the user confirmed only the desired
Mac indicator appears. This draft is for maintainer discussion, not a finished
solution to the user's native-indicator request. The embedded demo view is a
static appearance preview; the floating HUD uses a timed fade.

## Validation and design decisions still required

- Project lint/format tools and full Intel/older-macOS build/runtime checks.
- Confirm no duplicate system HUD and test disabled/hidden feedback paths.
- Light/dark mode, Reduce Motion/Transparency, VoiceOver and full-screen Spaces.
- Disconnect/reconnect while visible, multiple simultaneous volume targets.
- Maintainer-approved placement/style and preference/localization design.

NSGlassEffectView requires the macOS 26 SDK even though runtime access is
availability guarded. Retaining the older deployment target does not make
this buildable with older Xcode SDKs. This is a maintenance tradeoff for review.
