//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

enum PrefKey: String {
  /* -- App-wide settings -- */

  // Sparkle automatic checks
  case SUEnableAutomaticChecks

  // Receive beta updates?
  case isBetaChannel // This is not added to Preferences yet as it will be needed in the future only.

  // Build number
  case buildNumber

  // Was the app launched once
  case appAlreadyLaunched

  // Hide menu icon
  case menuIcon

  // Menu item style
  case menuItemStyle

  // Keys listened for
  case keyboardBrightness

  // Keys listened for
  case keyboardVolume

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

  // Do not show sliders for Apple displays (including built-in display) in menu
  case hideAppleFromMenu

  // Disable slider snapping
  case enableSliderSnap

  // Disable slider snapping
  case enableSliderPercent

  // Show tick marks for sliders
  case showTickMarks

  // Instead of assuming default values, enable read or write upon startup (according to readDDCInsteadOfRestoreValues)
  case startupAction

  // Show advanced options under Displays tab in Preferences
  case showAdvancedSettings

  // Allow zero software brightness
  case allowZeroSwBrightness

  // Keyboard brightness control for multiple displays
  case multiKeyboardBrightness

  // Keyboard volume control for multiple devices
  case multiKeyboardVolume

  // Use fine OSD scale for brightness
  case useFineScaleBrightness

  // Use fine OSD scale for volume
  case useFineScaleVolume

  // Use smoothBrightness
  case disableSmoothBrightness

  // Synchronize brightness from sync source displays among all other displays
  case enableBrightnessSync

  // Sliders for multiple displays
  case multiSliders

  /* -- Display specific settings */

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

  // Display should avoid gamma table manipulation and use shades instead (to coexist with other apps doing gamma manipulation)
  case avoidGamma

  // User assigned audio device name for display
  case audioDeviceNameOverride

  // Display disabled for keyboard control
  case isDisabled

  // Force software mode for display
  case forceSw

  // Software brightness for display
  case SwBrightness

  // Combined brightness switching point
  case combinedBrightnessSwitchingPoint

  // Friendly name
  case friendlyName

  /* -- Display+Command specific settings -- */

  // Command value display
  case value

  // Was the setting ever changed by the user?
  case isTouched

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
}

enum MultiKeyboardBrightness: Int {
  case mouse = 0
  case allScreens = 1
  case focusInsteadOfMouse = 2
}

enum MultiKeyboardVolume: Int {
  case mouse = 0
  case allScreens = 1
  case audioDeviceNameMatching = 2
}

enum StartupAction: Int {
  case doNothing = 0
  case write = 1
  case read = 2
}

enum MultiSliders: Int {
  case separate = 0
  case relevant = 1
  case combine = 2
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

enum KeyboardBrightness: Int {
  case media = 0
  case custom = 1
  case both = 2
  case disabled = 3
}

enum KeyboardVolume: Int {
  case media = 0
  case custom = 1
  case both = 2
  case disabled = 3
}
