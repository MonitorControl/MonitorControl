---
title: Monitor Troubleshooting
layout: wiki
---

We often get issues like:
_"MonitorControl doesn't work with my monitor"_,  
so here are some troubleshooting steps and general information to try and help you.

## General Information

- MonitorControl **doesn't work with every monitor**, it all depends on how well your display/cable manufacturer implements the [DDC/CI spec](https://en.wikipedia.org/wiki/Display_Data_Channel).
- Some displays will only support certain features well (for example, they work well with brightness but not volume).
- It also depends a lot on your [hardware combination](https://github.com/the0neyouseek/MonitorControl/issues/82).

## Troubleshooting

### I can't control volume/brightness

#### Known incompatibilities

Mac Minis made after 2018 (including the M1 Mini) have trouble supporting DDC via the built-in HDMI port. Use the USB-C/Thunderbolt port instead!

#### Check if your monitor OSD has a setting for DDC

Some monitors have a ddc settings that can be enabled/disabled, make sure you check if your specific monitor has this setting and if it does, you should ensure DDC is enabled.

#### Try a different ddc tool

You can try a different ddc tool called [ddcctl](https://github.com/kfix/ddcctl) for Intel Macs.

For Apple Silicon macs you can try [m1ddc](https://github.com/waydabber/m1ddc)

This can help us isolate issues with MonitorControl vs other tools.

If your setup works with ddcctl or m1ddc it should also work with MonitorControl.

After installing ddcctl, try something like:

```sh
./ddcctl -d 1 -v 30
```

or for m1ddc:

```sh
./m1ddc set volume 30
```

(tries to set the volume of display 1 to value 30)
or

```sh
./ddcctl -d 1 -b 30
```

or for m1ddc:

```sh
./m1ddc set brightness 30
```

(tries to set the brightness of display 1 to value 30)

If these commands change your brightness or volume, you know that your display supports ddc (or at least the command that worked).

#### Try a different cable

Generally, people seem to have the highest success rates with DisplayPort and the lowest with HDMI.

### Mute does not actually mute the speakers

By default, we mute by lowering the volume all the way to 0, we do this because it's the approach that works with most displays.

If you are having issues with this, try:

1. Preferences > Displays > Toggle `Show advanced settings` at the bottom
2. Toggle `Enable Mute DDC command` for the display.

This approach uses the actuall DDC Mute command, which might work/behave better.

### I can't get accurate read values from the monitor

If the monitor is unable to read values from the display, it will default to the last known values.

To try and fix this, you can try checking the `Longer Delay` option in Advanced Preferences under Displays (requires enabling advanced preferences).  
See the [Advanced Preferences](https://github.com/the0neyouseek/MonitorControl/wiki/Advanced-Preferences#longer-delay) wiki page for more information.

### The app is slow on startup

This is usually because we poll the display to try and read its current volume/brightness on app launch.

You can lower or disable the `Polling Mode` in Advanced Preferences under Displays (requires enabling advanced preferences).  
See the [Advanced Preferences](https://github.com/the0neyouseek/MonitorControl/wiki/Advanced-Preferences#polling-mode) wiki page for more information.

### I get screen flickering when launching MonitorControl

This can be caused due to trying to poll (read) values from your display multiple times. Try setting `Polling Mode` to none in Advanced Preferences under Displays (requires enabling advanced preferences).
