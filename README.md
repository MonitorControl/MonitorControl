<h1 align="center"> MonitorControl </h1>

<!-- subtext -->
<div align="center">
Control your external monitor brightness, contrast or volume directly from a menulet or with keyboard native keys.
</div>

<br/>

<!-- shields -->
<div align="center">
    <!-- downloads -->
    <a href="https://github.com/the0neyouseek/MonitorControl/releases">
        <img src="https://img.shields.io/github/downloads/the0neyouseek/MonitorControl/total.svg" alt="downloads"/>
    </a>
    <!-- version -->
    <a href="https://github.com/the0neyouseek/MonitorControl/releases/latest">
        <img src="https://img.shields.io/github/release/the0neyouseek/MonitorControl.svg" alt="latest version"/>
    </a>
    <!-- license -->
    <a href="https://github.com/the0neyouseek/MonitorControl/blob/master/License.txt">
        <img src="https://img.shields.io/github/license/the0neyouseek/MonitorControl.svg" alt="license"/>
    </a>
    <!-- platform -->
    <a href="https://github.com/the0neyouseek/MonitorControl">
        <img src="https://img.shields.io/badge/platform-macOS-lightgrey.svg" alt="platform"/>
    </a>
</div>

<br/>

<div align="center">
    <img src="./.github/menulet.png"  alt="menulet screenshot"/>
    <br/><br/>
    <img src="./.github/menugeneral.png" width="299" alt="general screenshot"/><img src="./.github/menukeys.png" width="299" alt="keys screenshot"/><img src="./.github/menudisplay.png" width="299" alt="display screenshot"/>

<br/>

*Bonus: Using keyboard keys displays the native osd*

<img src="./.github/osd.jpg" width="500" align="center" alt="osd screenshot"/>
</div>

## Download

Go to [Release](https://github.com/the0neyouseek/MonitorControl/releases/latest) and download the latest `.dmg`

## How to help

Open [issues](https://github.com/the0neyouseek/MonitorControl/issues) if you have a question, an enhancement to suggest or a bug you've found. If you want you can fork the code yourself and submit a pull request to improve the app.

## How to build

### Required

- Xcode
- [Cocoapods](https://cocoapods.org/)
- [Swiftlint](https://github.com/realm/SwiftLint)

Clone the project
```sh
git clone https://github.com/the0neyouseek/MonitorControl.git --recurse-submodules
```
Then download the dependencies with Cocoapods
```sh
$ pod install
```

You're all set ! Now open the `MonitorControl.xcworkspace` with Xcode

### Third party dependencies

- [MediaKeyTap](https://github.com/the0neyouseek/MediaKeyTap)
- [MASPreferences](https://github.com/shpakovski/MASPreferences)
- [ddcctl](https://github.com/kfix/ddcctl)
- [AMCoreAudio](https://github.com/rnine/AMCoreAudio)

## Support
- macOS Sierra (`10.12`) and up.
- Works with monitors compatible with [@kfix/ddcctl](https://github.com/kfix/ddcctl)

## Thanks
- [@bluejamesbond](https://github.com/bluejamesbond/) (Original developer)
- [@Tyilo](https://github.com/Tyilo/) (Fork)
- [@Bensge](https://github.com/Bensge/) - (Used some code from his project [NativeDisplayBrightness](https://github.com/Bensge/NativeDisplayBrightness))
- [@nhurden](https://github.com/nhurden/) (For the original MediaKeyTap)
- [@kfix](https://github.com/kfix/ddcctl) (For ddcctl)
