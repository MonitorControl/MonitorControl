//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

// UserDefault Keys for the app prefs
enum PrefKey: String {
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

  // Display enabled
  case state

  // Force software mode for display
  case forceSw

  // Software brightness for display
  case SwBrightness

  // Build number
  case buildNumber

  // Was the app launched once
  case appAlreadyLaunched

  // Does the app start when plugged to an external monitor
  case startWhenExternal

  // Hide menu icon
  case menuIcon

  // Keys listened for (Brightness/Volume)
  case listenFor

  // Hide brightness sliders
  case hideBrightness

  // Show volume sliders
  case showContrast

  // Show volume sliders
  case showVolume

  // Lower via software after brightness
  case lowerSwAfterBrightness

  // Fallback to software control for external displays with no DDC
  case fallbackSw

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

  // Prefs Reset
  case preferenceReset

  // Used for notification when displays are updated in DisplayManager
  case displayListUpdate

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

  // Use fine OSD scale for brightness TODO: PrefPane OK, Implementation MISSING
  case separateSwAfterScale
}
