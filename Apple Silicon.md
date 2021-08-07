## Experimental

This is an **experimental** version of MonitorControl with full **Apple Silicon support**.

**Test it at your own risk!**

You need to have *compatible* external display (aside from the internal display if present) connected to your *Apple Silicon Mac* via the *USB-C port*. The HDMI port of the M1 Mac mini does not work - unfortunatelly there is no known way to circumvent this limitation at the moment.

### Current state

- [x] Make the app compile without complaints on Apple Silicon, fix the OSD.Framework problem. - 100%
- [x] Figure out how to do M1 DDC control using Swift - 100%
- [x] Make DDC writes work on Apple Silicon - 100%
- [x] Make DDC read work on Apple Silicon (to set up initial brightness and volume during app start). - 100%
- [x] Add proper checks to safeguard things. - 100%
- [x] Fix issue with internal display brightness display control on Apple Slicon (relevant services moved to a different private framework) - 100%
- [x] Better handling of mirrored displays to prepare for proper external multi monitor support - 100%
- [x] Proper external multi monitor support - 100%

_Note: current pre-release version might not relfect this state._
