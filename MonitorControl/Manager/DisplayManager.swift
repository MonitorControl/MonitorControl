import Foundation

class DisplayManager {
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

  func getAllDisplays() -> [Display] {
    return self.displays
  }

  func getDdcCapableDisplays() -> [Display] {
    let filteredDisplays = self.displays.filter { (display) -> Bool in
      !display.isBuiltin && display.ddc != nil
    }
    return filteredDisplays
  }

  func getBuiltInDisplay() -> Display? {
    return self.displays.first { $0.isBuiltin }
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
