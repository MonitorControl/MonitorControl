---
title: Advanced Preferences
---

To enable Advanced Preferences for monitors, toggle the "Show advanced settings under Displays" checkbox in the General Preferences and go to the Displays tab, where you'll now see advanced preferences for each display.

Inside the advanced preferences you can experiment and modify some more advanced settings.
Not all monitors are the same and some are better at implementing the [DDC/CI spec](https://en.wikipedia.org/wiki/Display_Data_Channel) than others.

## Polling Mode

Sets the amount of times MonitorControl will try polling the display.  
Polling the display essentially means that it tries to read information from the display.  
This can sometimes be unreliable and thus MonitorControl will try reading these values multiple times to increase success rates.  
Polling is used for reading current display volume and brightness values, which happens on app launch or when
coming out of sleep mode.  
Because we try to read the values multiple times (for example, 10 tries for volume and 10 tries for brightness on `Normal` mode), it can cause some slowdown on your system. The different polling modes indicate a different amount of times we try to poll the display for information.

### Polling Modes

- None: 0 tries
- Minimal: 5 tries
- Normal: 10 tries (default)
- High: 100 tries
- Custom: X tries (selecting this will allow you to set the polling count yourself in the `Polling Count` text field.)

In case the display is still unable to read the values through DDC (or you selected `None`), the last known values will be used instead.

**If you experience significant system slowdown when coming out of sleep mode or at startup, try lowering or disabling the Polling Mode setting.**

## Longer Delay

Some displays will require a longer `minReplyDelay` (referred to as `Longer Delay` in settings) to be able to read display information more reliably. This depends on a combination of different factors like Cable, Monitor, GPU.

If it takes a long time to read your volume and brightness settings, you can try enabling the `Longer Delay` settings to improve reliability. However, please be aware that this setting will not work for every system and **may cause your system to freeze after enabling it. Please use this at your own risk.**  
As a safety measure, automatic app startup will be disabled.

## Hide OSD

Tries to hide your display's native OSD (On-Screen Display) when changing volume or brightness.
This setting also depends on your monitor, so it may not work properly on every monitor.
