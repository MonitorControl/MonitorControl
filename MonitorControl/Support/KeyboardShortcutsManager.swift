//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Foundation
import KeyboardShortcuts
import os.log

// Please note that I understand that the level of redundancy in this class is astonishing. I'll make it professional l8r! :) - @waydabber
class KeyboardShortcutsManager {

  var currentCommand: KeyboardShortcuts.Name = KeyboardShortcuts.Name.none
  var isFirstKeypress = false
  var isHold = false

  var isBrightnessUpFirstKeypress = false
  var isBrightnessDownFirstKeypress = false
  var isContrastUpFirstKeypress = false
  var isContrastDownFirstKeypress = false
  var isVolumeUpFirstKeypress = false
  var isVolumeDownFirstKeypress = false

  var isBrightnessUpHold = false
  var isBrightnessDownHold = false
  var isContrastUpHold = false
  var isContrastDownHold = false
  var isVolumeUpHold = false
  var isVolumeDownHold = false

  init() {
    KeyboardShortcuts.onKeyDown(for: .brightnessUp) { [self] in
      self.engage(KeyboardShortcuts.Name.brightnessUp)
    }
    KeyboardShortcuts.onKeyDown(for: .brightnessDown) { [self] in
      self.engage(KeyboardShortcuts.Name.brightnessDown)
    }
    KeyboardShortcuts.onKeyDown(for: .contrastUp) { [self] in
      self.engage(KeyboardShortcuts.Name.contrastUp)
    }
    KeyboardShortcuts.onKeyDown(for: .contrastDown) { [self] in
      self.engage(KeyboardShortcuts.Name.contrastDown)
    }
    KeyboardShortcuts.onKeyDown(for: .volumeUp) { [self] in
      self.engage(KeyboardShortcuts.Name.volumeUp)
    }
    KeyboardShortcuts.onKeyDown(for: .volumeDown) { [self] in
      self.engage(KeyboardShortcuts.Name.volumeDown)
    }
    KeyboardShortcuts.onKeyDown(for: .mute) { [self] in
      self.mute()
    }
    KeyboardShortcuts.onKeyUp(for: .brightnessUp) { [self] in
      disengage()
    }
    KeyboardShortcuts.onKeyUp(for: .brightnessDown) { [self] in
      disengage()
    }
    KeyboardShortcuts.onKeyUp(for: .contrastUp) { [self] in
      disengage()
    }
    KeyboardShortcuts.onKeyUp(for: .contrastDown) { [self] in
      disengage()
    }
    KeyboardShortcuts.onKeyUp(for: .volumeUp) { [self] in
      disengage()
    }
    KeyboardShortcuts.onKeyUp(for: .volumeDown) { [self] in
      disengage()
    }
  }

  func engage(_ shortcut: KeyboardShortcuts.Name) {
    self.currentCommand = shortcut
    self.isFirstKeypress = true
    self.isHold = true
    self.apply(shortcut)
  }

  func disengage() {
    self.isHold = false
    self.isFirstKeypress = false
    self.currentCommand = KeyboardShortcuts.Name.none
  }

  func apply(_ shortcut: KeyboardShortcuts.Name) {
    guard self.currentCommand == shortcut, self.isHold else {
      return
    }
    if self.isFirstKeypress {
      self.isFirstKeypress = false
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        self.apply(shortcut)
      }
    } else {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
        self.apply(shortcut)
      }
    }
    switch shortcut {
    case KeyboardShortcuts.Name.brightnessUp: self.brightness(isUp: true)
    case KeyboardShortcuts.Name.brightnessDown: self.brightness(isUp: false)
    case KeyboardShortcuts.Name.contrastUp: self.contrast(isUp: true)
    case KeyboardShortcuts.Name.contrastDown: self.contrast(isUp: false)
    case KeyboardShortcuts.Name.volumeUp: self.volume(isUp: true)
    case KeyboardShortcuts.Name.volumeDown: self.volume(isUp: false)
    default: break
    }
  }

  func brightness(isUp: Bool) {
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

  func contrast(isUp: Bool) {
    guard app.sleepID == 0, app.reconfigureID == 0, prefs.integer(forKey: PrefKey.keyboardBrightness.rawValue) == KeyboardBrightness.custom.rawValue, let affectedDisplays = DisplayManager.shared.getAffectedDisplays(isBrightness: true, isVolume: false) else {
      return
    }
    for display in affectedDisplays where !(display.readPrefAsBool(key: .isDisabled)) {
      if let otherDisplay = display as? OtherDisplay {
        otherDisplay.stepContrast(isUp: isUp, isSmallIncrement: false)
      }
    }
  }

  func volume(isUp: Bool) {
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

  func mute() {
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
