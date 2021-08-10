import Cocoa

class DisplayManager {
  public static let shared = DisplayManager()

  private var displays: [Display] {
    didSet {
      NotificationCenter.default.post(name: Notification.Name(Utils.PrefKeys.displayListUpdate.rawValue), object: nil)
    }
  }

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

  func getDdcCapableDisplays() -> [ExternalDisplay] {
    return self.displays.compactMap { display -> ExternalDisplay? in
      if let externalDisplay = display as? ExternalDisplay, externalDisplay.ddc != nil || externalDisplay.arm64ddc {
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
}
