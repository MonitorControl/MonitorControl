<div align="center">
        
<h2 align="center">MonitorControl - Now with Apple Silicon support!</h2>

<img src="./.github/Icon-1024.png" width="400" alt="App icon"/>
    
<p><b>Control your external display brightness, volume or contrast from a menulet or with keyboard native keys!</b></p>

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
    
<br/>
    
<p>Translations: :uk: :fr: :de: :it: :ru: :ukraine: :jp: :poland: :hungary:</p>
    
<hr>
    
</div>

<div align="center">
<img src="./.github/menulet.png" width="600" alt="menulet screenshot"/><br/>
<br/>
<img src="./.github/menugeneral.png" width="700" alt="general screenshot"/><br/>

<img src="./.github/osd1.png" width="290" align="center" alt="osd screenshot"/>&nbsp;&nbsp;&nbsp;
<img src="./.github/osd2.png" width="290" align="center" alt="osd screenshot"/><br>

<hr>
    
</div>

## Download the pre-release version

Go to [Releases](https://github.com/MonitorControl/MonitorControl/releases) and download the latest pre-release `.dmg`

## Compatibility

- macOS Mojave (`10.14`) and up.
- Works with monitors controllable via [DDC](https://en.wikipedia.org/wiki/Display_Data_Channel) (or any other display via software dimming)

## How to help

Open [issues](https://github.com/MonitorControl/MonitorControl/issues) if you have a question, an enhancement to suggest or a bug you've found. If you want you can fork the code yourself and submit a pull request to improve the app.

## How to donate or contribute

Check out our [Open Collecitve page, you can contribute](https://opencollective.com/monitorcontrol/donate) to the development of MonitorControl financially and follow the spendings in a transparent manner!

## How to build this *experimental branch*

### Required

- Xcode
- [Swiftlint](https://github.com/realm/SwiftLint)
- [SwiftFormat](https://github.com/nicklockwood/SwiftFormat)
- [BartyCrouch](https://github.com/Flinesoft/BartyCrouch) (for updating localizations)

Clone the project via this Terminal command:

```
git clone --single-branch --branch experimental/apple-silicon https://github.com/MonitorControl/MonitorControl.git
```

The dependencies will automatically get downloaded when opening the project, if they don't:

`File > Packages > Resolve Package Versions`

You're all set ! Now open the `MonitorControl.xcodeproj` with Xcode!

### Third party dependencies

- [MediaKeyTap](https://github.com/MonitorControl/MediaKeyTap)
- [Preferences](https://github.com/sindresorhus/Preferences)
- [DDC.swift](https://github.com/reitermarkus/DDC.swift)
- [SimplyCoreAudio](https://github.com/rnine/SimplyCoreAudio)

## Contributors

- [@the0neyouseek](https://github.com/the0neyouseek)
- [@JoniVR](https://github.com/JoniVR)
- [@waydabber](https://github.com/waydabber)

## Thanks

- [@bluejamesbond](https://github.com/bluejamesbond/) (original developer)
- [@Tyilo](https://github.com/Tyilo/) (fork)
- [@Bensge](https://github.com/Bensge/) - (used some code from his project [NativeDisplayBrightness](https://github.com/Bensge/NativeDisplayBrightness))
- [@nhurden](https://github.com/nhurden/) (for the original MediaKeyTap)
- [@kfix](https://github.com/kfix/ddcctl) (for ddcctl)
- [@reitermarkus](https://github.com/reitermarkus) (for DDC.Swift)
- [@zhuowei](https://github.com/zhuowei) (figured out M1 I²C communication)
- [@tao-j](https://github.com/tao-j) (figured out M1 I²C write)
- [@alin23](https://github.com/alin23) (generally spearheaded M1 DDC support and figured out a many of the caveats)
- [javierocasio](https://www.deviantart.com/javierocasio) (app icon background)
