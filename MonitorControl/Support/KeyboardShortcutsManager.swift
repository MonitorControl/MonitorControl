//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Foundation
import KeyboardShortcuts
import os.log

class KeyboardShortcutsManager {

  init() {
    KeyboardShortcuts.onKeyUp(for: .brightnessUp) { [self] in
      self.handleBrightness(isUp: true)
    }
    KeyboardShortcuts.onKeyUp(for: .brightnessDown) { [self] in
      self.handleBrightness(isUp: false)
    }
    KeyboardShortcuts.onKeyUp(for: .contrastUp) { [self] in
      self.handleContrast(isUp: true)
    }
    KeyboardShortcuts.onKeyUp(for: .contrastDown) { [self] in
      self.handleContrast(isUp: false)
    }
    KeyboardShortcuts.onKeyUp(for: .volumeUp) { [self] in
      self.handleVolume(isUp: true)
    }
    KeyboardShortcuts.onKeyUp(for: .volumeDown) { [self] in
      self.handleVolume(isUp: false)
    }
    KeyboardShortcuts.onKeyUp(for: .mute) { [self] in
      self.handleMute()
    }
  }

  func handleBrightness(isUp: Bool) {
    os_log("Pressed brightness custom shortcut.", type: .debug)
    // TODO: Something is missing here...
  }

  func handleContrast(isUp: Bool) {
    os_log("Pressed contrast custom shortcut.", type: .debug)
    // TODO: Something is missing here...
  }

  func handleVolume(isUp: Bool) {
    os_log("Pressed volume custom shortcut.", type: .debug)
    // TODO: Something is missing here...
  }

  func handleMute() {
    os_log("Pressed mute custom shortcut.", type: .debug)
    // TODO: Something is missing here...
  }

}
