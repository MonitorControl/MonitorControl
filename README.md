## Experimental

This is an **experimental** fork of [MonitorControl](https://github.com/MonitorControl/MonitorControl) to provide full **M1 support**.

**Test it at your own risk!**

You need to have a *single*, *compatible* external display connected to your *M1 Mac* via *USB-C/DisplayPort*. The HDMI port of the M1 Mac Mini does not work - unfortunatelly there is no known way to circumvent this limitation.

Current state:

- [x] Make the app compile without complaints on ARM, fix the OSD.Framework problem.
- [x] Figure out how to do M1 DDC control in 100% Swift (MonitorControl seems to avoid C :))
- [x] Make it work with a single external display config on M1.
- [x] Make DDC writes work on M1 - results in a fundamentally working app on M1.
- [x] Make DDC read work on M1 (to set up initial brightness and volume on app start).
- [x] Add proper checks to safeguard things.
- [x] Fix issue with internal display brightness display control on M1 (relevant services moved to a different private framework)
- [ ] Proper multi monitor detection (this applies only for the M1 Mac Mini as of now, but its HDMI port does not pass through I2C commands anyway).
- [ ] Cleanup and make things tidy.

</div>

## Download

Sorry, no releases download for this experimental fork but you can easily build it. See the steps below.

## How to build and use this experimental version

### Required

* Install [Xcode](https://developer.apple.com/xcode/)

### Steps

* Clone the project (in Terminal): `git clone https://github.com/waydabber/MonitorControl.git`
* Open the `MonitorControl.xcodeproj` with Xcode
* Dependencies will automatically get downloaded by XCode, if they don't: `File > Swift Packages > Resolve Package Versions`
* Build the app: `Product > Build`
* See the product: `Product > Reveal Build Products Folder`
* Test the app
* Send a feedback. :)


