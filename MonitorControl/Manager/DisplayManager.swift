import Foundation

protocol DisplayDelegate: AnyObject {
  func didUpdateDisplays(displays _: [Display])
}

class DisplayManager {
  private var displays: [Display]
  weak var displayDelegate: DisplayDelegate?

  init() {
    self.displays = []
  }

  func updateDisplays(displays: [Display]) {
    self.displays = displays
    self.displayDelegate?.didUpdateDisplays(displays: self.displays)
  }

  func getDisplays() -> [Display] {
    return self.displays
  }

  func addDisplay(display: Display) {
    self.displays.append(display)
    self.displayDelegate?.didUpdateDisplays(displays: self.displays)
  }

  func updateDisplay(display updatedDisplay: Display) {
    if let indexToUpdate = self.displays.firstIndex(of: updatedDisplay) {
      self.displays[indexToUpdate] = updatedDisplay
      self.displayDelegate?.didUpdateDisplays(displays: self.displays)
    }
  }

  func clearDisplays() {
    self.displays = []
    self.displayDelegate?.didUpdateDisplays(displays: self.displays)
  }
}
