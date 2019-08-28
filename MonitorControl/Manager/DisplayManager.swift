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

  func getDisplays() -> [Display] {
    return self.displays
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
