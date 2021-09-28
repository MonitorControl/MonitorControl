//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Foundation
import KeyboardShortcuts
import os.log

class KeyboardShortcutsManager {

  var initialKeyRepeat = 0.35 // This should come from UserDefaults instead, but it's ok for now.
  var keyRepeat = 0.02 // This should come from UserDefaults instead, but it's ok for now.

  var currentCommand: KeyboardShortcuts.Name = KeyboardShortcuts.Name.none
  var isFirstKeypress = false
  var currentEventId = 0
  var isHold = false

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
    self.currentEventId += 1
    self.apply(shortcut, eventId: self.currentEventId)
  }

  func disengage() {
    self.isHold = false
    self.isFirstKeypress = false
    self.currentCommand = KeyboardShortcuts.Name.none
  }

  func apply(_ shortcut: KeyboardShortcuts.Name, eventId: Int) {
    guard app.sleepID == 0, app.reconfigureID == 0, prefs.integer(forKey: PrefKey.keyboardBrightness.rawValue) == KeyboardBrightness.custom.rawValue else {
      disengage()
      return
    }
    guard self.currentCommand == shortcut, self.isHold, eventId == self.currentEventId else {
      if [KeyboardShortcuts.Name.volumeUp, KeyboardShortcuts.Name.volumeDown].contains(shortcut) {
        self.volume(isUp: true, isPressed: false)
      }
      return
    }
    if self.isFirstKeypress {
      self.isFirstKeypress = false
      DispatchQueue.main.asyncAfter(deadline: .now() + initialKeyRepeat) {
        self.apply(shortcut, eventId: eventId)
      }
    } else {
      DispatchQueue.main.asyncAfter(deadline: .now() + keyRepeat) {
        self.apply(shortcut, eventId: eventId)
      }
    }
    switch shortcut {
    case KeyboardShortcuts.Name.brightnessUp: self.brightness(isUp: true)
    case KeyboardShortcuts.Name.brightnessDown: self.brightness(isUp: false)
    case KeyboardShortcuts.Name.contrastUp: self.contrast(isUp: true)
    case KeyboardShortcuts.Name.contrastDown: self.contrast(isUp: false)
    case KeyboardShortcuts.Name.volumeUp: self.volume(isUp: true, isPressed: true)
    case KeyboardShortcuts.Name.volumeDown: self.volume(isUp: false, isPressed: true)
    default: break
    }
  }

  func brightness(isUp: Bool) {
    guard let affectedDisplays = DisplayManager.shared.getAffectedDisplays(isBrightness: true, isVolume: false) else {
      return
    }
    for display in affectedDisplays where !(display.readPrefAsBool(key: .isDisabled)) {
      var isAnyDisplayInSwAfterBrightnessMode: Bool = false
      for display in affectedDisplays where ((display as? OtherDisplay)?.isSwBrightnessNotDefault() ?? false) && !((display as? OtherDisplay)?.isSw() ?? false) && prefs.bool(forKey: PrefKey.separateCombinedScale.rawValue) {
        isAnyDisplayInSwAfterBrightnessMode = true
      }
      if !(isAnyDisplayInSwAfterBrightnessMode && !(((display as? OtherDisplay)?.isSwBrightnessNotDefault() ?? false) && !((display as? OtherDisplay)?.isSw() ?? false))) {
        display.stepBrightness(isUp: isUp, isSmallIncrement: prefs.bool(forKey: PrefKey.useFineScaleBrightness.rawValue))
      }
    }
  }

  func contrast(isUp: Bool) {
    guard let affectedDisplays = DisplayManager.shared.getAffectedDisplays(isBrightness: true, isVolume: false) else {
      return
    }
    for display in affectedDisplays where !(display.readPrefAsBool(key: .isDisabled)) {
      if let otherDisplay = display as? OtherDisplay {
        otherDisplay.stepContrast(isUp: isUp, isSmallIncrement: prefs.bool(forKey: PrefKey.useFineScaleBrightness.rawValue))
      }
    }
  }

  func volume(isUp: Bool, isPressed: Bool) {
    guard let affectedDisplays = DisplayManager.shared.getAffectedDisplays(isBrightness: false, isVolume: true) else {
      return
    }
    var wasNotIsPressedVolumeSentAlready = false
    for display in affectedDisplays where !(display.readPrefAsBool(key: .isDisabled)) {
      if let display = display as? OtherDisplay {
        if isPressed {
          display.stepVolume(isUp: isUp, isSmallIncrement: prefs.bool(forKey: PrefKey.useFineScaleVolume.rawValue))
        } else if !wasNotIsPressedVolumeSentAlready, !display.readPrefAsBool(key: .unavailableDDC, for: .audioSpeakerVolume) {
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
