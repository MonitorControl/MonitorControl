import Cocoa

class DisplayManager {
  public static let shared = DisplayManager()

  private var displays: [Display]

  init() {
    self.displays = []
  }

  func updateDisplays(displays: [Display]) {
    self.displays = displays
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

  func getCurrentDisplay() -> Display? {
    let mouseLocation = NSEvent.mouseLocation
    let screens = NSScreen.screens
    if let screenWithMouse = (screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }) {
      return self.displays.first { $0.identifier == screenWithMouse.displayID }
    }
    return nil
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

  // Semi-static functions (could be moved elsewhere easily)

  func resetSwBrightnessForAllDisplays(settingsOnly: Bool = false, async: Bool = false) {
    for externalDisplay in self.getNonVirtualExternalDisplays() {
      if !settingsOnly {
        _ = externalDisplay.setSwBrightness(value: externalDisplay.getSwMaxBrightness(), smooth: async)
      } else {
        externalDisplay.saveSwBirghtnessPrefValue(Int(externalDisplay.getSwMaxBrightness()))
      }
      if externalDisplay.isSw() {
        externalDisplay.saveValue(Int(externalDisplay.getSwMaxBrightness()), for: .brightness)
      }
    }
  }

  func restoreSwBrightnessForAllDisplays(async: Bool = false) {
    for externalDisplay in self.getExternalDisplays() {
      let sliderMax = DisplayManager.getBrightnessSliderMaxValue(externalDisplay: externalDisplay)
      if externalDisplay.getValue(for: .brightness) == 0 || externalDisplay.isSw() {
        let savedPrefValue = externalDisplay.getSwBrightnessPrefValue()
        if externalDisplay.getSwBrightness() != savedPrefValue {
          if let manager = OSDManager.sharedManager() as? OSDManager { // This will give the user a hint why is the brightness suddenly changes and also give screen activity to counter the 'no gamma change when there is no screen activity' issue on some macs
            manager.showImage(OSDImage.brightness.rawValue, onDisplayID: externalDisplay.identifier, priority: 0x1F4, msecUntilFade: 0)
          }
        }
        externalDisplay.saveSwBirghtnessPrefValue(Int(externalDisplay.getSwBrightness()))
        _ = externalDisplay.setSwBrightness(value: UInt8(savedPrefValue), smooth: async)
        if !externalDisplay.isSw(), prefs.bool(forKey: Utils.PrefKeys.lowerSwAfterBrightness.rawValue) {
          if savedPrefValue < externalDisplay.getSwMaxBrightness() {
            DisplayManager.setBrightnessSliderValue(externalDisplay: externalDisplay, value: Int32(Float(sliderMax / 2) * (Float(savedPrefValue) / Float(externalDisplay.getSwMaxBrightness()))))
          } else {
            DisplayManager.setBrightnessSliderValue(externalDisplay: externalDisplay, value: Int32(sliderMax / 2) + Int32(externalDisplay.getValue(for: .brightness)))
          }
        } else if externalDisplay.isSw() {
          DisplayManager.setBrightnessSliderValue(externalDisplay: externalDisplay, value: Int32(Float(sliderMax) * (Float(savedPrefValue) / Float(externalDisplay.getSwMaxBrightness()))))
        }
      } else {
        _ = externalDisplay.setSwBrightness(value: externalDisplay.getSwMaxBrightness())
        if externalDisplay.isSw() {
          DisplayManager.setBrightnessSliderValue(externalDisplay: externalDisplay, value: Int32(sliderMax))
        }
      }
    }
  }

  func getAffectedDisplays() -> [Display]? {
    var affectedDisplays: [Display]
    let allDisplays = self.getAllNonVirtualDisplays()
    guard let currentDisplay = self.getCurrentDisplay() else {
      return nil
    }
    // let allDisplays = prefs.bool(forKey: Utils.PrefKeys.allScreens.rawValue) ? displays : [currentDisplay]
    if prefs.bool(forKey: Utils.PrefKeys.allScreens.rawValue) {
      affectedDisplays = allDisplays
    } else {
      affectedDisplays = [currentDisplay]
      if CGDisplayIsInHWMirrorSet(currentDisplay.identifier) != 0 || CGDisplayIsInMirrorSet(currentDisplay.identifier) != 0, CGDisplayMirrorsDisplay(currentDisplay.identifier) == 0 {
        for display in allDisplays where CGDisplayMirrorsDisplay(display.identifier) == currentDisplay.identifier {
          affectedDisplays.append(display)
        }
      }
    }
    return affectedDisplays
  }

  // Static functions (could be anywhere)

  static func setBrightnessSliderValue(externalDisplay: ExternalDisplay, value: Int32) {
    if let slider = externalDisplay.brightnessSliderHandler?.slider {
      slider.intValue = value
    }
  }

  static func getBrightnessSliderMaxValue(externalDisplay: ExternalDisplay) -> Double {
    if let slider = externalDisplay.brightnessSliderHandler?.slider {
      return slider.maxValue
    }
    return 0
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
