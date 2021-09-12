//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Cocoa
import CoreGraphics
import os.log

class DisplayManager {
  public static let shared = DisplayManager()

  var displays: [Display] = []
  var audioControlTargetDisplays: [ExternalDisplay] = []

  func updateDisplays() {
    self.clearDisplays()
    var onlineDisplayIDs = [CGDirectDisplayID](repeating: 0, count: 16)
    var displayCount: UInt32 = 0
    guard CGGetOnlineDisplayList(16, &onlineDisplayIDs, &displayCount) == .success else {
      os_log("Unable to get display list.", type: .info)
      return
    }
    for onlineDisplayID in onlineDisplayIDs where onlineDisplayID != 0 {
      let name = DisplayManager.getDisplayNameByID(displayID: onlineDisplayID)
      let id = onlineDisplayID
      let vendorNumber = CGDisplayVendorNumber(onlineDisplayID)
      let modelNumber = CGDisplayModelNumber(onlineDisplayID)
      let display: Display
      var isVirtual: Bool = false
      if #available(macOS 11.0, *) {
        if let dictionary = ((CoreDisplay_DisplayCreateInfoDictionary(onlineDisplayID))?.takeRetainedValue() as NSDictionary?) {
          let isVirtualDevice = dictionary["kCGDisplayIsVirtualDevice"] as? Bool
          let displayIsAirplay = dictionary["kCGDisplayIsAirPlay"] as? Bool
          if isVirtualDevice ?? displayIsAirplay ?? false {
            isVirtual = true
          }
        }
      }
      if !app.debugSw, DisplayManager.isAppleDisplay(displayID: onlineDisplayID) { // MARK: (point of interest for testing)
        display = AppleDisplay(id, name: name, vendorNumber: vendorNumber, modelNumber: modelNumber, isVirtual: isVirtual)
      } else {
        display = ExternalDisplay(id, name: name, vendorNumber: vendorNumber, modelNumber: modelNumber, isVirtual: isVirtual)
      }
      self.addDisplay(display: display)
    }
  }

  func updateAudioControlTargetDisplays(deviceName: String) -> Int {
    self.audioControlTargetDisplays.removeAll()
    os_log("Detecting displays for audio control via audio device name matching...", type: .debug)
    var numOfAddedDisplays: Int = 0
    for ddcCapableDisplay in self.getDdcCapableDisplays() {
      var displayAudioDeviceName = ddcCapableDisplay.audioDeviceNameOverride
      if displayAudioDeviceName == "" {
        displayAudioDeviceName = DisplayManager.getDisplayRawNameByID(displayID: ddcCapableDisplay.identifier)
      }
      if displayAudioDeviceName == deviceName {
        self.audioControlTargetDisplays.append(ddcCapableDisplay)
        numOfAddedDisplays += 1
        os_log("Added display for audio control - %{public}@", type: .debug, ddcCapableDisplay.name)
      }
    }
    return numOfAddedDisplays
  }

  func refreshDisplaysBrightness() -> Bool {
    var refreshedSomething = false
    for display in self.displays {
      if display.refreshBrightness() {
        refreshedSomething = true
      }
    }
    return refreshedSomething
  }

  func getExternalDisplays() -> [ExternalDisplay] {
    return self.displays.compactMap { $0 as? ExternalDisplay }
  }

  func getAllDisplays() -> [Display] {
    return self.displays
  }

  func getAllNonVirtualDisplays() -> [Display] {
    return self.displays.compactMap { display -> Display? in
      if !display.isVirtual {
        return display
      } else { return nil }
    }
  }

  func getDdcCapableDisplays() -> [ExternalDisplay] {
    return self.displays.compactMap { display -> ExternalDisplay? in
      if let externalDisplay = display as? ExternalDisplay, !externalDisplay.isSw(), !externalDisplay.isVirtual {
        return externalDisplay
      } else { return nil }
    }
  }

  func getNonVirtualExternalDisplays() -> [ExternalDisplay] {
    return self.displays.compactMap { display -> ExternalDisplay? in
      if let externalDisplay = display as? ExternalDisplay, !externalDisplay.isVirtual {
        return externalDisplay
      } else { return nil }
    }
  }

  func getAppleDisplays() -> [AppleDisplay] {
    return self.displays.compactMap { $0 as? AppleDisplay }
  }

  func getBuiltInDisplay() -> Display? {
    return self.displays.first { CGDisplayIsBuiltin($0.identifier) != 0 }
  }

  func getCurrentDisplay(byFocus: Bool = false) -> Display? {
    if byFocus {
      guard let mainDisplayID = NSScreen.main?.displayID else {
        return nil
      }
      return self.displays.first { $0.identifier == mainDisplayID }
    } else {
      let mouseLocation = NSEvent.mouseLocation
      let screens = NSScreen.screens
      if let screenWithMouse = (screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }) {
        return self.displays.first { $0.identifier == screenWithMouse.displayID }
      }
      return nil
    }
  }

  func addDisplay(display: Display) {
    self.displays.append(display)
  }

  func clearDisplays() {
    self.displays = []
  }

  func addDisplayCounterSuffixes() {
    var nameDisplays: [String: [Display]] = [:]
    for display in self.displays {
      if nameDisplays[display.name] != nil {
        nameDisplays[display.name]?.append(display)
      } else {
        nameDisplays[display.name] = [display]
      }
    }
    for nameDisplayKey in nameDisplays.keys where nameDisplays[nameDisplayKey]?.count ?? 0 > 1 {
      for i in 0 ... (nameDisplays[nameDisplayKey]?.count ?? 1) - 1 {
        if let display = nameDisplays[nameDisplayKey]?[i] {
          display.name = "" + display.name + " (" + String(i + 1) + ")"
        }
      }
    }
  }

  func updateArm64AVServices() {
    if Arm64DDC.isArm64 {
      os_log("arm64 AVService update requested", type: .info)
      var displayIDs: [CGDirectDisplayID] = []
      for externalDisplay in self.getExternalDisplays() {
        displayIDs.append(externalDisplay.identifier)
      }
      for serviceMatch in Arm64DDC.getServiceMatches(displayIDs: displayIDs) {
        for externalDisplay in self.getExternalDisplays() where externalDisplay.identifier == serviceMatch.displayID && serviceMatch.service != nil {
          externalDisplay.arm64avService = serviceMatch.service
          os_log("Display service match successful for display %{public}@", type: .info, String(serviceMatch.displayID))
          if serviceMatch.isDiscouraged {
            os_log("Display %{public}@ is flagged as discouraged by Arm64DDC.", type: .info, String(serviceMatch.displayID))
            externalDisplay.isDiscouraged = serviceMatch.isDiscouraged
          } else {
            externalDisplay.arm64ddc = app.debugSw ? false : true // MARK: (point of interest when testing)
          }
        }
      }
      os_log("AVService update done", type: .info)
    }
  }

  // Semi-static functions (could be moved elsewhere easily)

  func resetSwBrightnessForAllDisplays(settingsOnly: Bool = false, async: Bool = false) {
    for externalDisplay in self.getNonVirtualExternalDisplays() {
      if !settingsOnly {
        _ = externalDisplay.setSwBrightness(value: 1, smooth: async)
      } else {
        externalDisplay.swBrightness = 1
      }
      if externalDisplay.isSw() {
        externalDisplay.savePrefValue(1, for: .brightness)
      }
    }
  }

  func restoreSwBrightnessForAllDisplays(async: Bool = false) {
    for externalDisplay in self.getExternalDisplays() {
      if externalDisplay.readPrefValue(for: .brightness) == 0 || externalDisplay.isSw() {
        let savedPrefValue = externalDisplay.swBrightness
        if externalDisplay.getSwBrightness() != savedPrefValue {
          OSDUtils.popEmptyOsd(displayID: externalDisplay.identifier, command: Command.brightness) // This will give the user a hint why is the brightness suddenly changes and also give screen activity to counter the 'no gamma change when there is no screen activity' issue on some macs
        }
        externalDisplay.swBrightness = externalDisplay.getSwBrightness()
        _ = externalDisplay.setSwBrightness(value: savedPrefValue, smooth: async)
        if !externalDisplay.isSw(), prefs.bool(forKey: PrefKey.lowerSwAfterBrightness.rawValue) {
          if savedPrefValue < 0.5 {
            DisplayManager.setBrightnessSliderValue(externalDisplay: externalDisplay, value: 0.5 * (savedPrefValue / 2))
          } else {
            DisplayManager.setBrightnessSliderValue(externalDisplay: externalDisplay, value: 0.5 + (externalDisplay.readPrefValue(for: .brightness) / 2))
          }
        } else if externalDisplay.isSw() {
          DisplayManager.setBrightnessSliderValue(externalDisplay: externalDisplay, value: savedPrefValue)
        }
      } else {
        _ = externalDisplay.setSwBrightness(value: 1)
        if externalDisplay.isSw() {
          DisplayManager.setBrightnessSliderValue(externalDisplay: externalDisplay, value: 1)
        }
      }
    }
  }

  func getAffectedDisplays(isBrightness: Bool = false, isVolume: Bool = false) -> [Display]? {
    var affectedDisplays: [Display]
    let allDisplays = self.getAllNonVirtualDisplays()
    var currentDisplay: Display?
    if isBrightness {
      if prefs.bool(forKey: PrefKey.allScreensBrightness.rawValue) {
        affectedDisplays = allDisplays
        return affectedDisplays
      }
      currentDisplay = self.getCurrentDisplay(byFocus: prefs.bool(forKey: PrefKey.useFocusInsteadOfMouse.rawValue))
    }
    if isVolume {
      if prefs.bool(forKey: PrefKey.allScreensVolume.rawValue) {
        affectedDisplays = allDisplays
        return affectedDisplays
      } else if prefs.bool(forKey: PrefKey.useAudioDeviceNameMatching.rawValue) {
        return self.audioControlTargetDisplays
      }
      currentDisplay = self.getCurrentDisplay(byFocus: false)
    }
    if let currentDisplay = currentDisplay {
      affectedDisplays = [currentDisplay]
      if CGDisplayIsInHWMirrorSet(currentDisplay.identifier) != 0 || CGDisplayIsInMirrorSet(currentDisplay.identifier) != 0, CGDisplayMirrorsDisplay(currentDisplay.identifier) == 0 {
        for display in allDisplays where CGDisplayMirrorsDisplay(display.identifier) == currentDisplay.identifier {
          affectedDisplays.append(display)
        }
      }
    } else {
      affectedDisplays = []
    }
    return affectedDisplays
  }

  static func engageMirror() -> Bool {
    var onlineDisplayIDs = [CGDirectDisplayID](repeating: 0, count: 16)
    var displayCount: UInt32 = 0
    guard CGGetOnlineDisplayList(16, &onlineDisplayIDs, &displayCount) == .success, displayCount > 1 else {
      return false
    }
    // Break display mirror if there is any
    var mirrorBreak = false
    var displayConfigRef: CGDisplayConfigRef?
    for onlineDisplayID in onlineDisplayIDs where onlineDisplayID != 0 {
      if CGDisplayIsInHWMirrorSet(onlineDisplayID) != 0 || CGDisplayIsInMirrorSet(onlineDisplayID) != 0 {
        if mirrorBreak == false {
          CGBeginDisplayConfiguration(&displayConfigRef)
        }
        CGConfigureDisplayMirrorOfDisplay(displayConfigRef, onlineDisplayID, kCGNullDirectDisplay)
        mirrorBreak = true
      }
    }
    if mirrorBreak {
      CGCompleteDisplayConfiguration(displayConfigRef, CGConfigureOption.permanently)
      return true
    }
    // Build display mirror
    var maestroDisplayId = kCGNullDirectDisplay // We use 'maestro' because 'master' does not feel inclusive to SwiftLint and posts a warning which is ridiculous. I write master, master, master here three times to counter doublespeak. :P But let's pretend to be woke for a minute and go on...
    for onlineDisplayID in onlineDisplayIDs where onlineDisplayID != 0 {
      if CGDisplayIsBuiltin(onlineDisplayID) == 0, maestroDisplayId == kCGNullDirectDisplay {
        maestroDisplayId = onlineDisplayID
      }
    }
    guard maestroDisplayId != kCGNullDirectDisplay else {
      return false
    }
    CGBeginDisplayConfiguration(&displayConfigRef)
    for onlineDisplayID in onlineDisplayIDs where onlineDisplayID != 0 && onlineDisplayID != maestroDisplayId {
      CGConfigureDisplayMirrorOfDisplay(displayConfigRef, onlineDisplayID, maestroDisplayId)
    }
    CGCompleteDisplayConfiguration(displayConfigRef, CGConfigureOption.permanently)
    return true
  }

  // Static functions (could be anywhere)

  static func setBrightnessSliderValue(externalDisplay: ExternalDisplay, value: Float) {
    if let slider = externalDisplay.brightnessSliderHandler?.slider {
      slider.floatValue = value
    }
  }

  static func isAppleDisplay(displayID: CGDirectDisplayID) -> Bool {
    var brightness: Float = -1
    let ret = DisplayServicesGetBrightness(displayID, &brightness)
    // If brightness read appears to be successful using DisplayServices then it should be an Apple display
    if ret == 0, brightness >= 0 {
      return true
    }
    // If built-in display then it should be Apple (except for hackintosh notebooks...)
    if CGDisplayIsBuiltin(displayID) != 0 {
      return true
    }
    /*
     // If Vendor ID is Anpple, then it is probably an Apple display
     if CGDisplayVendorNumber(displayID) == 0x05AC {
       return true
     }
     // If the display has a known Apple name, then it might be an Apple display. I am not sure about this one though
     let rawName = self.getDisplayRawNameByID(displayID: displayID)
     if rawName.contains("LG UltraFine") || rawName.contains("Thunderbolt") || rawName.contains("Cinema") || rawName.contains("Color LCD") {
        return true
     }
     */
    return false
  }

  static func getDisplayRawNameByID(displayID: CGDirectDisplayID) -> String {
    let defaultName: String = ""
    if #available(macOS 11.0, *) {
      if let dictionary = ((CoreDisplay_DisplayCreateInfoDictionary(displayID))?.takeRetainedValue() as NSDictionary?), let nameList = dictionary["DisplayProductName"] as? [String: String], let name = nameList["en_US"] ?? nameList.first?.value {
        return name
      }
    }
    if let screen = NSScreen.getByDisplayID(displayID: displayID) {
      return screen.displayName ?? defaultName
    }
    return defaultName
  }

  static func getDisplayNameByID(displayID: CGDirectDisplayID) -> String {
    let defaultName: String = NSLocalizedString("Unknown", comment: "Unknown display name")
    if #available(macOS 11.0, *) {
      if let dictionary = ((CoreDisplay_DisplayCreateInfoDictionary(displayID))?.takeRetainedValue() as NSDictionary?), let nameList = dictionary["DisplayProductName"] as? [String: String], var name = nameList[Locale.current.identifier] ?? nameList["en_US"] ?? nameList.first?.value {
        if CGDisplayIsInHWMirrorSet(displayID) != 0 || CGDisplayIsInMirrorSet(displayID) != 0 {
          let mirroredDisplayID = CGDisplayMirrorsDisplay(displayID)
          if mirroredDisplayID != 0, let dictionary = ((CoreDisplay_DisplayCreateInfoDictionary(mirroredDisplayID))?.takeRetainedValue() as NSDictionary?), let nameList = dictionary["DisplayProductName"] as? [String: String], let mirroredName = nameList[Locale.current.identifier] ?? nameList["en_US"] ?? nameList.first?.value {
            name.append("~" + mirroredName)
          }
        }
        return name
      }
    }
    if let screen = NSScreen.getByDisplayID(displayID: displayID) {
      if #available(OSX 10.15, *) {
        return screen.localizedName
      } else {
        return screen.displayName ?? defaultName
      }
    }
    return defaultName
  }
}
