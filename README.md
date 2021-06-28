<h1 align="center"> MonitorControl </h1>

<!-- subtext -->
<div align="center">
Control your external monitor brightness, contrast or volume directly from a menulet or with keyboard native keys.
</div>

<br/>

<!-- Language emoji -->
<div align="center">
    <p>Translations: :uk: :fr: :de: :it: :ru: :ukraine: :jp: :poland: :taiwan: </p>
</div>

<br/>

<!-- shields -->
<div align="center">
    <!-- downloads -->
    <a href="https://github.com/MonitorControl/MonitorControl/releases">
        <img src="https://img.shields.io/github/downloads/MonitorControl/MonitorControl/total.svg" alt="downloads"/>
    </a>
    <!-- version -->
    <a href="https://github.com/MonitorControl/MonitorControl/releases/latest">
        <img src="https://img.shields.io/github/release/MonitorControl/MonitorControl.svg" alt="latest version"/>
    </a>
    <!-- license -->
    <a href="https://github.com/MonitorControl/MonitorControl/blob/master/License.txt">
        <img src="https://img.shields.io/github/license/MonitorControl/MonitorControl.svg" alt="license"/>
    </a>
    <!-- platform -->
    <a href="https://github.com/MonitorControl/MonitorControl">
        <img src="https://img.shields.io/badge/platform-macOS-lightgrey.svg" alt="platform"/>
    </a>
</div>

<br/>

<div align="center">
    <img src="./.github/menulet.png" width="200" alt="menulet screenshot"/>
    <br/><br/>
    <img src="./.github/menugeneral.png" width="299" alt="general screenshot"/><img src="./.github/menukeys.png" width="299" alt="keys screenshot"/>
    <img src="./.github/menudisplay.png" width="299" alt="display screenshot"/>
    <img src="./.github/menuadvanced.png" width="299" alt="advanced screenshot"/>

<br/>

_Bonus: Using keyboard keys displays the native osd_

<img src="./.github/osd.jpg" width="500" align="center" alt="osd screenshot"/>
</div>

## Download

Go to [Release](https://github.com/MonitorControl/MonitorControl/releases/latest) and download the latest `.dmg`

## Installing with Homebrew Cask

You can also install MonitorControl with [Homebrew Cask](https://github.com/Homebrew/homebrew-cask).

```bash
$ brew install --cask monitorcontrol
```

## How to help

Open [issues](https://github.com/MonitorControl/MonitorControl/issues) if you have a question, an enhancement to suggest or a bug you've found. If you want you can fork the code yourself and submit a pull request to improve the app.

## How to build

### Required

- Xcode
- [Swiftlint](https://github.com/realm/SwiftLint)
- [SwiftFormat](https://github.com/nicklockwood/SwiftFormat)
- [BartyCrouch](https://github.com/Flinesoft/BartyCrouch) (for updating localizations)

Clone the project

```sh
git clone https://github.com/MonitorControl/MonitorControl.git
```

Then dependencies will automatically get downloaded when opening the project, if they don't:

`File > Swift Packages > Resolve Package Versions`

You're all set ! Now open the `MonitorControl.xcodeproj` with Xcode

### Third party dependencies

- [MediaKeyTap](https://github.com/MonitorControl/MediaKeyTap)
- [Preferences](https://github.com/sindresorhus/Preferences)
- [DDC.swift](https://github.com/reitermarkus/DDC.swift)
- [SimplyCoreAudio](https://github.com/rnine/SimplyCoreAudio)

## Support

- macOS Sierra (`10.12`) and up.
- Works with monitors controllable via [DDC](https://en.wikipedia.org/wiki/Display_Data_Channel).

## Contributors

- [@the0neyouseek](https://github.com/the0neyouseek)
- [@reitermarkus](https://github.com/reitermarkus)
- [@JoniVR](https://github.com/JoniVR)

## Thanks

- [@bluejamesbond](https://github.com/bluejamesbond/) (Original developer)
- [@Tyilo](https://github.com/Tyilo/) (Fork)
- [@Bensge](https://github.com/Bensge/) - (Used some code from his project [NativeDisplayBrightness](https://github.com/Bensge/NativeDisplayBrightness))
- [@nhurden](https://github.com/nhurden/) (For the original MediaKeyTap)
- [@kfix](https://github.com/kfix/ddcctl) (For ddcctl)
