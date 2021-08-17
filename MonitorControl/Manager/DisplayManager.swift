import Cocoa
import CoreMedia
import DDC

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

  func getBuiltInDisplay() -> Display? {
    return self.displays.first { $0 is InternalDisplay }
  }

  func getCurrentDisplay() -> Display? {
    guard let mainDisplayID = NSScreen.main?.displayID else {
      return nil
    }
    return self.displays.first { $0.identifier == mainDisplayID }
  }

  func addDisplay(display: Display) {
    self.displays.append(display)
  }

  func updateDisplay(display updatedDisplay: Display) {
    if let indexToUpdate = self.displays.firstIndex(of: updatedDisplay) {
      self.displays[indexToUpdate] = updatedDisplay
    }
  }

  func clearDisplays() {
    self.displays = []
  }

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

  func setBrightnessSliderValue(externalDisplay: ExternalDisplay, value: Int32) {
    if let slider = externalDisplay.brightnessSliderHandler?.slider {
      slider.intValue = value
    }
  }

  func getBrightnessSliderMaxValue(externalDisplay: ExternalDisplay) -> Double {
    if let slider = externalDisplay.brightnessSliderHandler?.slider {
      return slider.maxValue
    }
    return 0
  }

  func restoreSwBrightnessForAllDisplays(async: Bool = false) {
    for externalDisplay in self.getExternalDisplays() {
      let sliderMax = self.getBrightnessSliderMaxValue(externalDisplay: externalDisplay)
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
            self.setBrightnessSliderValue(externalDisplay: externalDisplay, value: Int32(Float(sliderMax / 2) * (Float(savedPrefValue) / Float(externalDisplay.getSwMaxBrightness()))))
          } else {
            self.setBrightnessSliderValue(externalDisplay: externalDisplay, value: Int32(sliderMax / 2) + Int32(externalDisplay.getValue(for: DDC.Command.brightness)))
          }
        } else if externalDisplay.isSw() {
          self.setBrightnessSliderValue(externalDisplay: externalDisplay, value: Int32(Float(sliderMax) * (Float(savedPrefValue) / Float(externalDisplay.getSwMaxBrightness()))))
        }
      } else {
        _ = externalDisplay.setSwBrightness(value: externalDisplay.getSwMaxBrightness())
        if externalDisplay.isSw() {
          self.setBrightnessSliderValue(externalDisplay: externalDisplay, value: Int32(sliderMax))
        }
      }
    }
  }

  func getDisplayNameByID(displayID: CGDirectDisplayID) -> String {
    let defaultName: String = NSLocalizedString("Unknown", comment: "Unknown display name") // + String(CGDisplaySerialNumber(displayID))
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
