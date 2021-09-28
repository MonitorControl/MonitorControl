//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Foundation
import KeyboardShortcuts
import os.log

// Please note that I understand that the level of redundancy in this class is astonishing. I'll make it professional l8r! :) - @waydabber
class KeyboardShortcutsManager {

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
      self.isBrightnessUpFirstKeypress = true
      self.isBrightnessUpHold = true
      self.brightnessUp()
    }
    KeyboardShortcuts.onKeyDown(for: .brightnessDown) { [self] in
      self.isBrightnessDownFirstKeypress = true
      self.isBrightnessDownHold = true
      self.brightnessDown()
    }
    KeyboardShortcuts.onKeyDown(for: .contrastUp) { [self] in
      self.isContrastUpFirstKeypress = true
      self.isContrastUpHold = true
      self.contrastUp()
    }
    KeyboardShortcuts.onKeyDown(for: .contrastDown) { [self] in
      self.isContrastDownFirstKeypress = true
      self.isContrastDownHold = true
      self.contrastDown()
    }
    KeyboardShortcuts.onKeyDown(for: .volumeUp) { [self] in
      self.isVolumeUpFirstKeypress = true
      self.isVolumeUpHold = true
      self.volumeUp()
    }
    KeyboardShortcuts.onKeyDown(for: .volumeDown) { [self] in
      self.isVolumeDownFirstKeypress = true
      self.isVolumeDownHold = true
      self.volumeDown()
    }
    KeyboardShortcuts.onKeyDown(for: .mute) { [self] in
      self.mute()
    }
    KeyboardShortcuts.onKeyUp(for: .brightnessUp) { [self] in
      self.isBrightnessUpHold = false
    }
    KeyboardShortcuts.onKeyUp(for: .brightnessDown) { [self] in
      self.isBrightnessDownHold = false
    }
    KeyboardShortcuts.onKeyUp(for: .contrastUp) { [self] in
      self.isContrastUpHold = false
    }
    KeyboardShortcuts.onKeyUp(for: .contrastDown) { [self] in
      self.isContrastDownHold = false
    }
    KeyboardShortcuts.onKeyUp(for: .volumeUp) { [self] in
      self.isVolumeUpHold = false
    }
    KeyboardShortcuts.onKeyUp(for: .volumeDown) { [self] in
      self.isVolumeDownHold = false
    }
  }

  func resetAllHolds() {
    self.isBrightnessUpHold = false
    self.isBrightnessDownHold = false
    self.isContrastUpHold = false
    self.isContrastDownHold = false
    self.isVolumeUpHold = false
    self.isVolumeDownHold = false
  }

  func brightnessUp() {
    guard isBrightnessUpHold else {
      return
    }
    if self.isBrightnessUpFirstKeypress {
      self.isBrightnessUpFirstKeypress = false
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        self.brightnessUp()
      }
    } else {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
        self.brightnessUp()
      }
    }
    brightness(isUp: true)
  }

  func brightnessDown() {
    guard isBrightnessDownHold else {
      return
    }
    if self.isBrightnessDownFirstKeypress {
      self.isBrightnessDownFirstKeypress = false
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        self.brightnessDown()
      }
    } else {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
        self.brightnessDown()
      }
    }
    brightness(isUp: false)
  }

  func contrastUp() {
    guard isContrastUpHold else {
      return
    }
    if self.isContrastUpFirstKeypress {
      self.isContrastUpFirstKeypress = false
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        self.contrastUp()
      }
    } else {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
        self.contrastUp()
      }
    }
    contrast(isUp: true)
  }

  func contrastDown() {
    guard isContrastDownHold else {
      return
    }
    if self.isContrastDownFirstKeypress {
      self.isContrastDownFirstKeypress = false
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        self.contrastDown()
      }
    } else {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
        self.contrastDown()
      }
    }
    contrast(isUp: false)
  }

  func volumeUp() {
    guard isVolumeUpHold else {
      return
    }
    if self.isVolumeUpFirstKeypress {
      self.isVolumeUpFirstKeypress = false
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        self.volumeUp()
      }
    } else {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
        self.volumeUp()
      }
    }
    volume(isUp: true)
  }

  func volumeDown() {
    guard isVolumeDownHold else {
      return
    }
    if self.isVolumeDownFirstKeypress {
      self.isVolumeDownFirstKeypress = false
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
        self.volumeDown()
      }
    } else {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
        self.volumeDown()
      }
    }
    volume(isUp: false)
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
