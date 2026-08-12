//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Foundation
import KeyboardShortcuts
import os.log

class KeyboardShortcutsManager {
  private let brightnessShortcuts: [KeyboardShortcuts.Name] = [.brightnessUp, .brightnessDown, .contrastUp, .contrastDown]
  private let volumeShortcuts: [KeyboardShortcuts.Name] = [.volumeUp, .volumeDown, .mute]
  // The preset shortcuts stay on whichever way the brightness keys are set.
  // Most users keep the media keys, and a preset must still work for them.
  private let presetShortcuts: [KeyboardShortcuts.Name] = BrightnessPreset.allCases.map(\.shortcutName)

  var initialKeyRepeat = 0.21
  var keyRepeat = 0.028
  var keyRepeatCount = 0

  var currentCommand = KeyboardShortcuts.Name.none
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
    // A preset sets one level, so it uses no key repeat. This follows the mute
    // shortcut, not the brightness ones.
    for preset in BrightnessPreset.allCases {
      KeyboardShortcuts.onKeyDown(for: preset.shortcutName) {
        preset.apply()
      }
    }
    KeyboardShortcuts.onKeyUp(for: .brightnessUp) { [self] in
      self.disengage()
    }
    KeyboardShortcuts.onKeyUp(for: .brightnessDown) { [self] in
      self.disengage()
    }
    KeyboardShortcuts.onKeyUp(for: .contrastUp) { [self] in
      self.disengage()
    }
    KeyboardShortcuts.onKeyUp(for: .contrastDown) { [self] in
      self.disengage()
    }
    KeyboardShortcuts.onKeyUp(for: .volumeUp) { [self] in
      self.disengage()
    }
    KeyboardShortcuts.onKeyUp(for: .volumeDown) { [self] in
      self.disengage()
    }
    self.updateRegistrations()
  }

  func updateRegistrations() {
    let brightnessEnabled = [KeyboardBrightness.custom.rawValue, KeyboardBrightness.both.rawValue].contains(prefs.integer(forKey: PrefKey.keyboardBrightness.rawValue))
    let volumeEnabled = [KeyboardVolume.custom.rawValue, KeyboardVolume.both.rawValue].contains(prefs.integer(forKey: PrefKey.keyboardVolume.rawValue))
    let enabledShortcuts = (brightnessEnabled ? self.brightnessShortcuts : []) + (volumeEnabled ? self.volumeShortcuts : []) + self.presetShortcuts
    let disabledShortcuts = (brightnessEnabled ? [] : self.brightnessShortcuts) + (volumeEnabled ? [] : self.volumeShortcuts)

    self.disengage()
    for shortcut in enabledShortcuts {
      KeyboardShortcuts.enable(shortcut)
    }
    for shortcut in disabledShortcuts {
      guard let assignedShortcut = KeyboardShortcuts.getShortcut(for: shortcut), !enabledShortcuts.contains(where: { KeyboardShortcuts.getShortcut(for: $0) == assignedShortcut }) else {
        continue
      }
      KeyboardShortcuts.disable(shortcut)
    }
  }

  func engage(_ shortcut: KeyboardShortcuts.Name) {
    guard self.isEnabled(shortcut) else {
      return
    }
    self.initialKeyRepeat = max(15, UserDefaults.standard.double(forKey: "InitialKeyRepeat")) * 0.014
    self.keyRepeat = max(2, UserDefaults.standard.double(forKey: "KeyRepeat")) * 0.014
    self.currentCommand = shortcut
    self.isFirstKeypress = true
    self.isHold = true
    self.currentEventId += 1
    self.keyRepeatCount = 0
    self.apply(shortcut, eventId: self.currentEventId)
  }

  private func isEnabled(_ shortcut: KeyboardShortcuts.Name) -> Bool {
    if self.brightnessShortcuts.contains(shortcut) {
      return [KeyboardBrightness.custom.rawValue, KeyboardBrightness.both.rawValue].contains(prefs.integer(forKey: PrefKey.keyboardBrightness.rawValue))
    }
    if self.volumeShortcuts.contains(shortcut) {
      return [KeyboardVolume.custom.rawValue, KeyboardVolume.both.rawValue].contains(prefs.integer(forKey: PrefKey.keyboardVolume.rawValue))
    }
    if self.presetShortcuts.contains(shortcut) {
      return true
    }
    return false
  }

  func disengage() {
    self.isHold = false
    self.isFirstKeypress = false
    self.currentCommand = KeyboardShortcuts.Name.none
    self.keyRepeatCount = 0
  }

  func apply(_ shortcut: KeyboardShortcuts.Name, eventId: Int) {
    guard app.sleepID == 0, app.reconfigureID == 0, self.keyRepeatCount <= 100 else {
      self.disengage()
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
      DispatchQueue.main.asyncAfter(deadline: .now() + self.initialKeyRepeat) {
        self.apply(shortcut, eventId: eventId)
      }
    } else {
      DispatchQueue.main.asyncAfter(deadline: .now() + self.keyRepeat) {
        self.apply(shortcut, eventId: eventId)
      }
    }
    self.keyRepeatCount += 1
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
    guard let affectedDisplays = DisplayManager.shared.getAffectedDisplays(isBrightness: true, isVolume: false), [KeyboardBrightness.custom.rawValue, KeyboardBrightness.both.rawValue].contains(prefs.integer(forKey: PrefKey.keyboardBrightness.rawValue)) else {
      self.disengage()
      return
    }
    for display in affectedDisplays where !display.readPrefAsBool(key: .isDisabled) {
      var isAnyDisplayInSwAfterBrightnessMode = false
      for display in affectedDisplays where ((display as? OtherDisplay)?.isSwBrightnessNotDefault() ?? false) && !((display as? OtherDisplay)?.isSw() ?? false) && prefs.bool(forKey: PrefKey.separateCombinedScale.rawValue) {
        isAnyDisplayInSwAfterBrightnessMode = true
      }
      if !(isAnyDisplayInSwAfterBrightnessMode && !(((display as? OtherDisplay)?.isSwBrightnessNotDefault() ?? false) && !((display as? OtherDisplay)?.isSw() ?? false))) {
        display.stepBrightness(isUp: isUp, isSmallIncrement: prefs.bool(forKey: PrefKey.useFineScaleBrightness.rawValue))
      }
    }
  }

  func contrast(isUp: Bool) {
    guard let affectedDisplays = DisplayManager.shared.getAffectedDisplays(isBrightness: true, isVolume: false), [KeyboardBrightness.custom.rawValue, KeyboardBrightness.both.rawValue].contains(prefs.integer(forKey: PrefKey.keyboardBrightness.rawValue)) else {
      self.disengage()
      return
    }
    for display in affectedDisplays where !display.readPrefAsBool(key: .isDisabled) {
      if let otherDisplay = display as? OtherDisplay {
        otherDisplay.stepContrast(isUp: isUp, isSmallIncrement: prefs.bool(forKey: PrefKey.useFineScaleBrightness.rawValue))
      }
    }
  }

  func volume(isUp: Bool, isPressed: Bool) {
    guard let affectedDisplays = DisplayManager.shared.getAffectedDisplays(isBrightness: false, isVolume: true), [KeyboardVolume.custom.rawValue, KeyboardVolume.both.rawValue].contains(prefs.integer(forKey: PrefKey.keyboardVolume.rawValue)) else {
      self.disengage()
      return
    }
    var wasNotIsPressedVolumeSentAlready = false
    for display in affectedDisplays where !display.readPrefAsBool(key: .isDisabled) {
      if let display = display as? OtherDisplay {
        if isPressed {
          display.stepVolume(isUp: isUp, isSmallIncrement: prefs.bool(forKey: PrefKey.useFineScaleVolume.rawValue))
        } else if !wasNotIsPressedVolumeSentAlready, !display.readPrefAsBool(key: .unavailableDDC, for: .audioSpeakerVolume) {
          app.playVolumeChangedSound()
          wasNotIsPressedVolumeSentAlready = true
        }
      }
    }
  }

  func mute() {
    guard app.sleepID == 0, app.reconfigureID == 0, [KeyboardVolume.custom.rawValue, KeyboardVolume.both.rawValue].contains(prefs.integer(forKey: PrefKey.keyboardVolume.rawValue)), let affectedDisplays = DisplayManager.shared.getAffectedDisplays(isBrightness: false, isVolume: true) else {
      return
    }
    var wasNotIsPressedVolumeSentAlready = false
    for display in affectedDisplays where !display.readPrefAsBool(key: .isDisabled) {
      if let display = display as? OtherDisplay {
        display.toggleMute()
        if !wasNotIsPressedVolumeSentAlready, display.readPrefAsInt(for: .audioMuteScreenBlank) != 1, !display.readPrefAsBool(key: .unavailableDDC, for: .audioSpeakerVolume) {
          app.playVolumeChangedSound()
          wasNotIsPressedVolumeSentAlready = true
        }
      }
    }
  }
}
