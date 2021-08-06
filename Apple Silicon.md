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
- [x] Better handling of mirrored displays to prepare for proper external multi monitor support
- [ ] Proper external multi monitor support - 40%
