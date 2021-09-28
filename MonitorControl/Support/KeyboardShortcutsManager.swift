//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Foundation
import KeyboardShortcuts
import os.log

class KeyboardShortcutsManager {

  init() {
    KeyboardShortcuts.onKeyDown(for: .brightnessUp) { [self] in
      self.handleBrightness(isUp: true)
    }
    KeyboardShortcuts.onKeyDown(for: .brightnessDown) { [self] in
      self.handleBrightness(isUp: false)
    }
    KeyboardShortcuts.onKeyDown(for: .contrastUp) { [self] in
      self.handleContrast(isUp: true)
    }
    KeyboardShortcuts.onKeyDown(for: .contrastDown) { [self] in
      self.handleContrast(isUp: false)
    }
    KeyboardShortcuts.onKeyDown(for: .volumeUp) { [self] in
      self.handleVolume(isUp: true)
    }
    KeyboardShortcuts.onKeyDown(for: .volumeDown) { [self] in
      self.handleVolume(isUp: false)
    }
    KeyboardShortcuts.onKeyDown(for: .mute) { [self] in
      self.handleMute()
    }
  }

  func handleBrightness(isUp: Bool) {
    guard app.sleepID == 0, app.reconfigureID == 0, prefs.integer(forKey: PrefKey.keyboardBrightness.rawValue) == KeyboardBrightness.custom.rawValue, let affectedDisplays = DisplayManager.shared.getAffectedDisplays(isBrightness: true, isVolume: false) else {
      return
    }
    for display in affectedDisplays where !(display.readPrefAsBool(key: .isDisabled)) {
      var isAnyDisplayInSwAfterBrightnessMode: Bool = false
      for display in affectedDisplays where ((display as? OtherDisplay)?.isSwBrightnessNotDefault() ?? false) && !((display as? OtherDisplay)?.isSw() ?? false) && prefs.bool(forKey: PrefKey.separateCombinedScale.rawValue) {
        isAnyDisplayInSwAfterBrightnessMode = true
      }
      if !(isAnyDisplayInSwAfterBrightnessMode && !(((display as? OtherDisplay)?.isSwBrightnessNotDefault() ?? false) && !((display as? OtherDisplay)?.isSw() ?? false))) {
        display.stepBrightness(isUp: isUp, isSmallIncrement: false)
      }
    }
  }

  func handleContrast(isUp: Bool) {
    guard app.sleepID == 0, app.reconfigureID == 0, prefs.integer(forKey: PrefKey.keyboardBrightness.rawValue) == KeyboardBrightness.custom.rawValue, let affectedDisplays = DisplayManager.shared.getAffectedDisplays(isBrightness: true, isVolume: false) else {
      return
    }
    for display in affectedDisplays where !(display.readPrefAsBool(key: .isDisabled)) {
      if let otherDisplay = display as? OtherDisplay {
        otherDisplay.stepContrast(isUp: isUp, isSmallIncrement: false)
      }
    }
  }

  func handleVolume(isUp: Bool) {
    guard app.sleepID == 0, app.reconfigureID == 0, prefs.integer(forKey: PrefKey.keyboardVolume.rawValue) == KeyboardVolume.custom.rawValue, let affectedDisplays = DisplayManager.shared.getAffectedDisplays(isBrightness: false, isVolume: true) else {
      return
    }
    var wasNotIsPressedVolumeSentAlready = false
    for display in affectedDisplays where !(display.readPrefAsBool(key: .isDisabled)) {
      if let display = display as? OtherDisplay {
        display.stepVolume(isUp: isUp, isSmallIncrement: false)
        if !wasNotIsPressedVolumeSentAlready, !display.readPrefAsBool(key: .unavailableDDC, for: .audioSpeakerVolume) {
          display.playVolumeChangedSound()
          wasNotIsPressedVolumeSentAlready = true
        }
      }
    }
  }

  func handleMute() {
    guard app.sleepID == 0, app.reconfigureID == 0, prefs.integer(forKey: PrefKey.keyboardVolume.rawValue) == KeyboardVolume.custom.rawValue, let affectedDisplays = DisplayManager.shared.getAffectedDisplays(isBrightness: false, isVolume: true) else {
      return
    }
    var wasNotIsPressedVolumeSentAlready = false
    for display in affectedDisplays where !(display.readPrefAsBool(key: .isDisabled)) {
      if let display = display as? OtherDisplay {
        display.toggleMute()
        if !wasNotIsPressedVolumeSentAlready, display.readPrefAsInt(for: .audioMuteScreenBlank) != 1, !display.readPrefAsBool(key: .unavailableDDC, for: .audioSpeakerVolume) {
          display.playVolumeChangedSound()
          wasNotIsPressedVolumeSentAlready = true
        }
      }
    }
  }
}
