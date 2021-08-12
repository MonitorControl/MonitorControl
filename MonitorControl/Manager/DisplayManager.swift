import Cocoa
import CoreMedia

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

  func resetSwBrightness() {
    for externalDisplay in self.getNonVirtualExternalDisplays() {
      guard externalDisplay.setSwBrightness(value: externalDisplay.getSwMaxBrightness()) else {
        continue
      }
      if externalDisplay.isSw() {
        externalDisplay.saveValue(Int(externalDisplay.getSwMaxBrightness()), for: .brightness)
      }
    }
  }

  func restoreSwBrightness() {
    for externalDisplay in self.getExternalDisplays() {
      if externalDisplay.getValue(for: .brightness) == 0 || externalDisplay.isSw() {
        // Out of caution we won't let it restore to complete darkness, not to interfere with login, etc. This is how Apple devices work as well.
        _ = externalDisplay.setSwBrightness(value: UInt8(max(externalDisplay.getSwBrightnessPrefValue(), 20)))
      } else {
        _ = externalDisplay.setSwBrightness(value: externalDisplay.getSwMaxBrightness())
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
