## Experimental

This is an **experimental** fork of [MonitorControl](https://github.com/MonitorControl/MonitorControl) to provide full **M1 support**.

**Test it at your own risk!**

You need to have a *single*, *compatible* external display (aside from the internal display if present) connected to your *M1 Mac* via *USB-C/DisplayPort*. The HDMI port of the M1 Mac mini does not work - unfortunatelly there is no known way to circumvent this limitation.

Current state:

- [x] Make the app compile without complaints on ARM, fix the OSD.Framework problem.
- [x] Figure out how to do M1 DDC control in 100% Swift (MonitorControl seems to avoid C :))
- [x] Make DDC writes work on M1
- [x] Make DDC read work on M1 (to set up initial brightness and volume on app start).
- [x] Add proper checks to safeguard things.
- [x] Fix issue with internal display brightness display control on M1 (relevant services moved to a different private framework)
- [ ] Proper external multi monitor handling for DDC - **Sorry, not going to happen anytime soon, see below**

About Multiple external displays:

Unfortunatelly proper external multi monitor support is super difficult to achieve for several reasons (needs a complicated display matching logic based on various properties). It is doable but needs lots of work and testing to work really well. Also other changes are needed (like fixing how MonitorControl handles mirrored displays). So I just give up on this now, others can fix this. This must be resolved eventually for future Apple devices, but for the M1 class devices this only affects the Mac mini when both HDMI and DP is connected. Even then the HDMI port will not work (which is a hard limitation as of now) so such users probably won't want use MonitorControl anyway.

As of now if you have a Mac mini and both displays are connected, most likely the USB-C/DP display will be controlled as this seems to be the default behavior, which is good. I tested the app on an M1 mini with multiple physical displays attached (via HDMI and USB-C/DP) and had no issues. If not, then you need to connect/reconnect displays in a different order until the OS thinks the DP display is the the default one to hand over when the app requests its services. If you don't succeed because your MacOS is too brainish about this, you might need to delete `com.apple.windowserver.displays.plist` from `/Library/Preferences`, reboot with the DP display connected first then connect the HDMI display, this will set things straight.

This issue does not affect MonitorControl's ability to handle the internal display alongside a single external display connected through USB-C.

## Download

No releases download for this experimental fork but you can easily build it. See the steps below.

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


