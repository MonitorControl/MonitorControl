## Experimental

This is an **experimental** version of [MonitorControl](https://github.com/MonitorControl/MonitorControl) to provide full **Apple Silicon support**.

**Test it at your own risk!**

You need to have a *single*, *compatible* external display (aside from the internal display if present) connected to your *Apple Silicon Mac* via *USB-C/DisplayPort*. The HDMI port of the M1 Mac mini does not work - unfortunatelly there is no known way to circumvent this limitation.

### Current state

- [x] Make the app compile without complaints on Apple Silicon, fix the OSD.Framework problem.
- [x] Figure out how to do M1 DDC control in 100% Swift
- [x] Make DDC writes work on Apple Silicon
- [x] Make DDC read work on Apple Silicon (to set up initial brightness and volume during app start).
- [x] Add proper checks to safeguard things.
- [x] Fix issue with internal display brightness display control on Apple Slicon (relevant services moved to a different private framework)
- [ ] Proper external multi monitor support

### About multiple external displays

Unfortunatelly proper external multi monitor support is rather difficult to achieve for several reasons (needs a complicated display matching logic based on various properties). It is doable but needs lots of work and testing to work really well. Also other changes are needed (like fixing how MonitorControl handles mirrored displays). For the M1 class devices this only affects the Mac mini when both HDMI and DP is connected. Even then the HDMI port will not work (which is a hard limitation as of now) so such users probably won't want use MonitorControl anyway. This issue will have to be resolved though for future Apple Silicon devices

This does not affect MonitorControl's ability to handle the internal display alongside a single external display connected via USB-C.

## How to build and use this experimental version

### Required

* Install [Xcode](https://developer.apple.com/xcode/)

### Steps

1. Clone the project (in Terminal): `git clone https://github.com/waydabber/MonitorControl.git`
1. Open the `MonitorControl.xcodeproj` with Xcode
1. Dependencies will automatically get downloaded by XCode, if they don't: `File > Swift Packages > Resolve Package Versions`
1. Build the app: `Product > Build`
1. See the product: `Product > Reveal Build Products Folder`
1. Test the app
1. Send a feedback. :)
