# Changelog

## MonitorControl v4.0.0-beta2 (Thu, 07 Oct 2021)

### Enhancements

- Added Internet Access Policy
- Don't relinquish control over brightness keys with no external display connected if fine brightness OSD scale is active
- Changed icon order in menu (when icon mode is enabled)
- Gear shape icon is used for preferences + stands a little bit apart to help user focus.
- Changed default to a minimum software dimming of 15% for safety reasons.
- Added advanced option to enable zero brightness with software dimming.
- Added 'Avoid gamma table manipulation' option for coexistence with f.lux.
- Set relevant options to disabled when keyboard control is disabled.
- Added <kbd>Command</kbd> + <kbd>Q</kbd> shortcut in menu when it is in standard text mode (not icon mode).
- Made preferences more spacious + more room for verbose languages

### Updated translations:

- English - base language
- Chinese (Traditional, Taiwan) - thanks to @stiiveo, @dororojames
- Dutch - thanks to @JoniVR
- French - thanks to @the0neyouseek
- German - thanks to @jajoho
- Hungarian - thanks to @waydabber
- Italian - thanks to @picov
- Korean - thanks to @zzulu
- Turkish - thanks to @mennan

### Under the hood changes & fixes

- Register DDC command touched status. When write on startup enabled, apply only touched command values.
- Reorganised PrefKey list to be less confusing.
- Disengage custom shortcut keyboard after 100 key repeat to prevent possibly endless loop if keyUp event never arrives due to any circumstance.
- Fixed text for external display brightness control keyboard shortcut.
- Fix cumulative darkening bug upon toggling 'Disable dimming as fallback'.
- Make sure that key repeat speed for custom shortcuts do not go below a certain threshold.
- Fixes text clipping issues for various languages
- Added beta channel update backend
- Fixed layout issue at brightness custom shortcuts.
- Fixed custom key shortcuts going runaway when menu was opened during a key repeat streak.

## MonitorControl v4.0.0-beta1 (Thu, 30 Sept 2021)

### Enhancements

- Automatic & manual updates through the app, no more manual downloads 🎉
- Added proper support for controlling Apple displays.
- Added option to show/hide brightness slider.
- Added option to show brightness slider for internal display and apple displays (enabled by default).
- Replication of built-in and Apple display brightness to corresponding brightness slider.
- Added suffix to similarly named displays for better differentiation.
- Option to disable slider snapping for finer control + disable slider snapping by default.
- Added option to show slider tick marks for better accuracy.
- Added option to use window focus instead of mouse to determine which display to control.
- <kbd>control</kbd> + <kbd>command</kbd> + <kbd>brightness</kbd> now controls external displays only (<kbd>control</kbd> + <kbd>Brightness</kbd> continues to control internal display only)
- Added separate tab for menu options.
- Added option to restore last saved values upon startup.
- Added option for audio device name matching for display volume control selection.
- Separated option to change all screens for brightness and volume.
- Added option for keyboard fine scale for brightness.
- Added option for keyboard fine scale for volume.
- Added version check upon startup for mandatory preferences reset upon downgrade or incompatible previous version + notification about this.
- Added implementation for <kbd>command</kbd> + <kbd>f1</kbd> macOS shortcut to enable/disable mirroring.
- Added safer 'Assume last saved settings are valid' option as default instead of startup DDC read (or restore).
- Streamlined preference panes, 'Show advanced settings' now affect all tabs. This leads to a better and safer first timer experience (especially because of the influx of many new features).
- Added a Quit button to Preferences if menu is hidden (it was not passible to quit the application until this time in this mode only by re-enabling the menu).
- Lowered default first-run volume DDC default from 75% to 15% if read is not possible or disabled to prevent unexpectedly loud sound.
- Added slider skew setting on a per control basis to have the ability to manipulate DDC slider balance and OSD scale if display control is not linear.
- Added the ability to set min. and max. DDC bounds on a per display, per control basis.
- Audio device name override option for a display (manually assign a specific audio device to a display).
- Advanced setting to invert DDC control range (some displays have the scale reversed).
- Advanced setting to remap DDC control code (some displays have contrast and brightness mixed up).
- Ability to mark a DDC control as available or unavailable in advanced settings under Displays.
- Ability to automatically hide menu icon if there is no slider present in the menu.
- Option to show slider percentage for more precision.
- Option to set combined or separate OSD scale when combined hardware+software brightness is used.
- Apple like smooth brightness change (both for software, hardware, mixed and DisplayServices).
- Added support for DisplayLink, AirPlay, Sidecar, screen sharing etc. using window shades (this is an inferior technique to the existing software implementation - gamma control - but still better than nothing). Disabled for any kind of mirroring setups. [^1]
- Brightness change synchronisation from Built-In and Apple displays to other displays. This makes Touch Bar, Ambient light sensor, Control Center and System Preferences induced changes affect all displays. Synchronisation uses a sophisticated indirect delta method + the user can intervene and adjust individual screen brightness at any time to easily compensate mismatching native brightness levels.
- Preferences pane tab selector has a simpler look on Catalina.
- All menu sliders are now scrollable using a magic mouse/trackpad swipes or mouse wheel.
- Added option for menu to show only items that are relevant to display which shows the menu currently.
- Added option to enable combined sliders (note: this option combined with enabled Apple/built-in display syncing and enabled 'change all' keyboard settings finally provides full synchronised control of all displays).
- Combined sliders can now display multiple displays when keyboard and brightness syncing is not enabled. [^1]
- Redesigned sliders to look like Big Sur/Monterey Control Center's sliders. [^1]
- Quit and Preferences... are now icons for a much cleaner look. [^1]
- Added option to change additional menu options style or hide them. [^1]
- Multiple displays are now in nice Big Sur styled blocks - no more ugly separators. [^1]
- Added customisable gamma/ddc switchover point for combined brightness in the advanced section of Displays.
- Added comma separated list for control code override to enable edge cases like controlling Brightness and Contrast at the same time (use VCP list entry `10, 12` for that)
- Contrast can now be controlled from keyboard via <kbd>control</kbd> + <kbd>option</kbd> + <kbd>command</kbd> + <kbd>brightness up/down</kbd>.
- Custom keyboard shortcuts for brightness, contrast, volume and mute

### Other under the hood changes and bug fixes

- Standardised internal scale among various displays and DDC ranges for ranged controls.
- Uses the new internal scale for combined hardware-software brightness mode.
- Migrated scales to internal float representation to prevent loss of fine detail on transformations.
- Fixed double sound when muting multiple external displays at the same time.
- Fixed lack of initial volume configuration if slider is not shown in menu.
- Fixed wrong settings being applied to a display when replaced on Apple Silicon (UserDefaults preferences are now tied to specific display strings instead of CGDirectDisplayID - which is no longer semi-unique on arm64).
- A lot of refactoring, streamlining and general optimisations.
