//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

enum PKey: String {
  // Enable mute DDC for display
  case enableMuteUnmute

  // Hide OSD for display
  case hideOsd

  // Longer delay DDC for display
  case longerDelay

  // DDC polling mode for display
  case pollingMode

  // DDC polling count for display
  case pollingCount

  // Command value display
  case value

  // Min command value display
  case minDDCOverride

  // Max command value display
  case maxDDC

  // Max user override command value display
  case maxDDCOverride

  // Max command value display
  case curveDDC

  // Is the specific control is set as unavailable for display?
  case unavailableDDC

  // Invert DDC scale?
  case invertDDC

  // Override DDC control command code
  case remapDDC

  // User assigned audio device name for display
  case audioDeviceNameOverride

  // Display disabled for keyboard control
  case isDisabled

  // Force software mode for display
  case forceSw

  // Software brightness for display
  case SwBrightness

  // Build number
  case buildNumber

  // Was the app launched once
  case appAlreadyLaunched

  // Hide menu icon
  case menuIcon

  // Menu item style
  case menuItemStyle

  // Keys listened for
  case disableListenForBrightness

  // Keys listened for
  case disableListenForVolume

  // Don't listen to F14/F15
  case disableAltBrightnessKeys

  // Hide brightness sliders
  case hideBrightness

  // Show volume sliders
  case showContrast

  // Show volume sliders
  case hideVolume

  // Lower via software after brightness
  case disableCombinedBrightness

  // Use separated OSD scale for combined brightness
  case separateCombinedScale

  // Fallback to software control for other displays with no DDC
  case disableSoftwareFallback

  // Do not show sliders for Apple displays (including built-in display) in menu
  case hideAppleFromMenu

  // Disable slider snapping
  case enableSliderSnap

  // Disable slider snapping
  case enableSliderPercent

  // Show tick marks for sliders
  case showTickMarks

  // Friendly name changed
  case friendlyName

  // Instead of assuming default values, enable read or write upon startup (according to readDDCInsteadOfRestoreValues)
  case enableDDCDuringStartup

  // Restore last saved values upon startup or wake
  case readDDCInsteadOfRestoreValues

  // Show advanced options under Displays tab in Preferences
  case showAdvancedSettings

  // Change Brightness for all screens
  case allScreensBrightness

  // Use focus instead of mouse position to determine which display to control for brightness
  case useFocusInsteadOfMouse

  // Change Volume for all screens
  case allScreensVolume

  // Use audio device name matching to determine display to control for volume
  case useAudioDeviceNameMatching

  // Use fine OSD scale for brightness
  case useFineScaleBrightness

  // Use fine OSD scale for volume
  case useFineScaleVolume

  // Use smoothBrightness
  case disableSmoothBrightness

  // Synchronize brightness from sync source displays among all other displays
  case enableBrightnessSync

  // Show only relevant slider for menu (depending on which display shows the menu)
  case slidersRelevant

  // Combine sliders for all displays
  case slidersCombine
}

enum PollingMode: Int {
  case none = -2
  case minimal = -1
  case normal = 0
  case heavy = 1
  case custom = 2
}

enum MenuIcon: Int {
  case show = 0
  case sliderOnly = 1
  case hide = 2
}

enum MenuItemStyle: Int {
  case text = 0
  case icon = 1
  case hide = 2
}
