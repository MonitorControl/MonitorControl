<img src=".github/Icon-cropped.png" width="200" alt="App icon" align="left"/>

<div>
<h3>MonitorControl - for Apple Silicon and Intel</h3>
<p>Controls your external display brightness and volume and shows native OSD.
Use menubar extra sliders or the keyboard, including native Apple keys!</p>
<a href="https://github.com/MonitorControl/MonitorControl/releases"><img src=".github/macos_badge_noborder.png" width="175" alt="Download for macOS"/></a>
</div>

<br/><br/>

<div align="center">
<!-- shields -->
<!-- downloads -->
<a href="https://github.com/MonitorControl/MonitorControl/releases">
<img src="https://img.shields.io/github/downloads/MonitorControl/MonitorControl/total.svg?style=flat" alt="downloads"/>
</a>
<!-- version -->
<a href="https://github.com/MonitorControl/MonitorControl/releases">
<img src="https://img.shields.io/github/release-pre/MonitorControl/MonitorControl.svg?style=flat" alt="latest version"/>
</a>
<!-- license -->
<a href="https://github.com/MonitorControl/MonitorControl/blob/master/License.txt">
<img src="https://img.shields.io/github/license/MonitorControl/MonitorControl.svg?style=flat" alt="license"/>
</a>
<!-- platform -->
<a href="https://github.com/MonitorControl/MonitorControl">
<img src="https://img.shields.io/badge/platform-macOS-lightgrey.svg?style=flat" alt="platform"/>
</a>
<!-- backers -->
<a href="https://opencollective.com/monitorcontrol">
<img src="https://opencollective.com/monitorcontrol/tiers/badge.svg" alt="backers"/>
</a>

<br/>
<br/>

<img src=".github/screenshot.png" width="824" alt="Screenshot"/><br/>

</div>

<hr>

## Download

Go to [Releases](https://github.com/MonitorControl/MonitorControl/releases) and download the latest `.dmg`, or you can install via Homebrew:
```shell
brew install MonitorControl
```

## Major features

- Control your display's brightness, volume and contrast!
- Shows native OSD for brightness and volume.
- Supports multiple protocols to adjust brightness: DDC for external displays (brightness, contrast, volume), native Apple protocol for Apple and built-in displays, Gamma table control for software dimming, shade control for AirPlay, Sidecar and Display Link devices and other virtual screens.
- Supports smooth brightness transitions.
- Seamlessly combined hardware and software dimming extends dimming beyond the minimum brightness available on your display.
- Synchronize brightness from built-in and Apple screens - replicate Ambient light sensor and touch bar induced changes to a non-Apple external display!
- Sync up all your displays using a single slider or keyboard shortcuts.
- Allows dimming to full black.
- Support for custom keyboard shortcuts as well as standard brightness and media keys on Apple keyboards.
- Dozens of customization options to tweak the inner workings of the app to suit your hardware and needs (don't forget to enable `Show advanced settings` in app Preferences).
- Simple, unobtrusive UI to blend in to the general aesthetics of macOS.
- **One of the best app of its kind, completely FREE.**

## How to install and use the app

1. [Download the app](https://github.com/MonitorControl/MonitorControl/releases)
2. Copy the MonitorControl app file from the .DMG to your Applications folder
3. Click on the `MonitorControl` app file
4. Add the app to `Accessibility` under `System Settings` » `Privacy & Security` as prompted (this is required only if you wish to use the native Apple keyboard brightness and media keys - if this is not the case, you can safely skip this step).
5. Use your keyboard or the sliders in the app menu (a brightness symbol in the macOS menubar as shown on the screenshot above) to control your displays.
6. Open `Preferences…` for customization options (enable `Show advanced settings` for even more options).
7. You can set up custom keyboard shortcuts under the `Keyboard` in Preferences (the app uses Apple media keys by default).
8. If you have any questions, go to [Discussions](https://github.com/MonitorControl/MonitorControl/discussions)!

## Screenshots (Preferences)

<div align="center">
<img src=".github/pref_1.png" width="392" alt="Screenshot"/>
<img src=".github/pref_2.png" width="392" alt="Screenshot"/>
<img src=".github/pref_3.png" width="392" alt="Screenshot"/>
<img src=".github/pref_4.png" width="392" alt="Screenshot"/>
</div>

## macOS compatibility

| MonitorControl version | macOS version     |
| ---------------------- | ----------------- |
| v4.0.0                 | Catalina 10.15*   |
| v3.1.1                 | Mojave 10.14      |
| v2.1.0                 | Sierra 10.12      |

_* With some limitations - full functionality available on macOS 11 Big Sur or newer._

## Supported displays

- Most modern LCD displays from all major manufacturers supported implemented DDC/CI protocol via USB-C, DisplayPort, HDMI, DVI or VGA to allow for hardware backlight and volume control.
- Apple displays and built-in displays are supported using native protocols.
- LCD and LED Televisions usually do not implement DDC, these are supported using software alternatives to dim the image.
- DisplayLink, Airplay, Sidecar and other virtual screens are supported via shade (overlay) control.

Notable exceptions for hardware control compatibility:

- DDC control using the built-in HDMI port of the 2018 Intel Mac mini, the built-in HDMI port of all M1 Macs (MacBook Pro 14" and 16", Mac Mini, Mac Studio) and the built-in HDMI port of the entry level M2 Mac mini are not supported. Use USB-C instead or get [BetterDisplay](https://betterdisplay.pro) for full DDC control over HDMI with these Macs as well for free. Software-only dimming is still available for these connections.
- Some displays (notably EIZO) use MCCS over USB or an entirely custom protocol for control. These displays are supported with software dimming only.
- DisplayLink docks and dongles do not allow for DDC control on Macs, only software dimming is available for these connections.

Compatibility with 

- f.lux users: please activate `Avoid gamma table manipulation` under `Preferences` » `Displays`! This step is not needed if you use Night Shift.
- [BetterDisplay](https://betterdisplay.pro/) users: either activate `Avoid gamma table manipulation` in MonitorControl or turn off `Allow color adjustments` in BetterDisplay (under Settings/Displays/Overview). You might want to disable native keyboard control either in MonitorControl or BetterDisplay, depending on which app you want to use for brightness control and dimming.

## How to help

- You can greatly help out [by financing the project with your donation or by being a Sponsor](https://opencollective.com/monitorcontrol)!
- Open [issues](https://github.com/MonitorControl/MonitorControl/issues) if you have a question, an enhancement to suggest or a bug you've found.
- If you want, you can fork the code yourself and submit a pull request to improve the app (Note: accepting a PR is solely in the collective hands of the maintainers).

## Localizations

MonitorControl supports localization. We gladly welcome your contribution with a new language! See the [opening post of the relevant discussion](https://github.com/MonitorControl/MonitorControl/discussions/637) on how to add your translation!

## How to build

### Required

- Xcode
- [Swiftlint](https://github.com/realm/SwiftLint)
- [SwiftFormat](https://github.com/nicklockwood/SwiftFormat)
- [BartyCrouch](https://github.com/Flinesoft/BartyCrouch) (for updating localizations)

### Build steps

- Clone the project via this Terminal command:

```sh
git clone https://github.com/MonitorControl/MonitorControl.git
```

- If you want to clone one of the branches, add `--single-branch --branch [branchname]` after the `clone` option.
- You're all set! Now open the `MonitorControl.xcodeproj` with Xcode! The dependencies will automatically get downloaded once you open the project. If they don't: `File > Packages > Resolve Package Versions`

### Third party dependencies

- [MediaKeyTap](https://github.com/MonitorControl/MediaKeyTap)
- [Preferences](https://github.com/sindresorhus/Preferences)
- [SimplyCoreAudio](https://github.com/rnine/SimplyCoreAudio)
- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts)
- [Sparkle](https://github.com/sparkle-project/Sparkle)

## Maintainers

- [@the0neyouseek](https://github.com/the0neyouseek)
- [@JoniVR](https://github.com/JoniVR)
- [@waydabber](https://github.com/waydabber)

## Thanks

- [@mathew-kurian](https://github.com/mathew-kurian/) (original developer)
- [@Tyilo](https://github.com/Tyilo/) (fork)
- [@Bensge](https://github.com/Bensge/) - (used some code from his project [NativeDisplayBrightness](https://github.com/Bensge/NativeDisplayBrightness))
- [@nhurden](https://github.com/nhurden/) (for the original MediaKeyTap)
- [@kfix](https://github.com/kfix/ddcctl) (for ddcctl)
- [@reitermarkus](https://github.com/reitermarkus) (for Intel DDC support)
- [@alin23](https://github.com/alin23) (generally spearheaded M1 DDC support and figured out a many of the caveats)
- [javierocasio](https://www.deviantart.com/javierocasio) (app icon background)
