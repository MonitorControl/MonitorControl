//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Cocoa

import Settings

extension Settings.PaneIdentifier {
  static let main = Self("Main")
  static let menusliders = Self("Menu & Sliders")
  static let keyboard = Self("Keyboard")
  static let mouse = Self("Mouse")
  static let displays = Self("Displays")
  static let about = Self("About")
}

public extension SettingsWindowController {
  override func keyDown(with event: NSEvent) {
    if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command, let key = event.charactersIgnoringModifiers {
      if key == "w" {
        self.close()
      }
    }
  }
}
