//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import AudioToolbox
import Cocoa
import Foundation
import MediaKeyTap
import os.log

class MediaKeyTapManager: MediaKeyTapDelegate {
  var mediaKeyTap: MediaKeyTap?
  var keyRepeatTimers: [MediaKey: Timer] = [:]

  func handle(mediaKey: MediaKey, event: KeyEvent?, modifiers: NSEvent.ModifierFlags?) {
    let isPressed = event?.keyPressed ?? true
    let isRepeat = event?.keyRepeat ?? false
    let isControl = modifiers?.isSuperset(of: NSEvent.ModifierFlags([.control])) ?? false
    let isCommand = modifiers?.isSuperset(of: NSEvent.ModifierFlags([.command])) ?? false
    let isOption = modifiers?.isSuperset(of: NSEvent.ModifierFlags([.option])) ?? false
    let isShift = modifiers?.isSuperset(of: NSEvent.ModifierFlags([.shift])) ?? false
    if isPressed, isCommand, !isControl, mediaKey == .brightnessDown, DisplayManager.engageMirror() {
      return
    }
    guard app.sleepID == 0, app.reconfigureID == 0 else {
      self.showOSDLock(mediaKey)
      return
    }
    if isPressed, self.handleOpenPrefPane(mediaKey: mediaKey, event: event, modifiers: modifiers) {
      return
    }
    var isSmallIncrement = isOption && isShift
    let isContrast = isControl && isOption && isCommand
    if [.brightnessUp, .brightnessDown].contains(mediaKey), prefs.bool(forKey: PrefKey.useFineScaleBrightness.rawValue) {
      isSmallIncrement = !isSmallIncrement
    }
    if [.volumeUp, .volumeDown, .mute].contains(mediaKey), prefs.bool(forKey: PrefKey.useFineScaleVolume.rawValue) {
      isSmallIncrement = !isSmallIncrement
    }
    if isPressed, isControl, !isOption, mediaKey == .brightnessUp || mediaKey == .brightnessDown {
      self.handleDirectedBrightness(isCommandModifier: isCommand, isUp: mediaKey == .brightnessUp, isSmallIncrement: isSmallIncrement)
      return
    }
    let oppositeKey: MediaKey? = self.oppositeMediaKey(mediaKey: mediaKey)
    // If the opposite key to the one being held has an active timer, cancel it - we'll be going in the opposite direction
    if let oppositeKey = oppositeKey, let oppositeKeyTimer = self.keyRepeatTimers[oppositeKey], oppositeKeyTimer.isValid {
      oppositeKeyTimer.invalidate()
    } else if let mediaKeyTimer = self.keyRepeatTimers[mediaKey], mediaKeyTimer.isValid {
      // If there's already an active timer for the key being held down, let it run rather than executing it again
      if isRepeat {
        return
      }
      mediaKeyTimer.invalidate()
    }
    self.sendDisplayCommand(mediaKey: mediaKey, isRepeat: isRepeat, isSmallIncrement: isSmallIncrement, isPressed: isPressed, isContrast: isContrast)
  }

  func handleDirectedBrightness(isCommandModifier: Bool, isUp: Bool, isSmallIncrement: Bool) {
    if isCommandModifier {
      for otherDisplay in DisplayManager.shared.getOtherDisplays() {
        otherDisplay.stepBrightness(isUp: isUp, isSmallIncrement: isSmallIncrement)
      }
      for appleDisplay in DisplayManager.shared.getAppleDisplays() where !appleDisplay.isBuiltIn() {
        appleDisplay.stepBrightness(isUp: isUp, isSmallIncrement: isSmallIncrement)
      }
      return
    } else if let internalDisplay = DisplayManager.shared.getBuiltInDisplay() as? AppleDisplay {
      internalDisplay.stepBrightness(isUp: isUp, isSmallIncrement: isSmallIncrement)
      return
    }
  }

  private func showOSDLock(_ mediaKey: MediaKey) {
    if [.brightnessUp, .brightnessDown].contains(mediaKey) {
      OSDUtils.showOSDLockOnAllDisplays(osdImage: 1)
    }
    if [.volumeUp, .volumeDown, .mute].contains(mediaKey) {
      OSDUtils.showOSDLockOnAllDisplays(osdImage: 3)
    }
  }

  private func sendDisplayCommand(mediaKey: MediaKey, isRepeat: Bool, isSmallIncrement: Bool, isPressed: Bool, isContrast: Bool = false) {
    guard app.sleepID == 0, app.reconfigureID == 0, let affectedDisplays = DisplayManager.shared.getAffectedDisplays(isBrightness: [.brightnessUp, .brightnessDown].contains(mediaKey), isVolume: [.volumeUp, .volumeDown, .mute].contains(mediaKey)) else {
      return
    }
    var wasNotIsPressedVolumeSentAlready = false
    for display in affectedDisplays where !(display.readPrefAsBool(key: .isDisabled)) {
      switch mediaKey {
      case .brightnessUp:
        if isContrast, isPressed, let otherDisplay = display as? OtherDisplay {
          otherDisplay.stepContrast(isUp: mediaKey == .brightnessUp, isSmallIncrement: isSmallIncrement)
        } else {
          var isAnyDisplayInSwAfterBrightnessMode: Bool = false
          for display in affectedDisplays where ((display as? OtherDisplay)?.isSwBrightnessNotDefault() ?? false) && !((display as? OtherDisplay)?.isSw() ?? false) && prefs.bool(forKey: PrefKey.separateCombinedScale.rawValue) {
            isAnyDisplayInSwAfterBrightnessMode = true
          }
          if isPressed, !(isAnyDisplayInSwAfterBrightnessMode && !(((display as? OtherDisplay)?.isSwBrightnessNotDefault() ?? false) && !((display as? OtherDisplay)?.isSw() ?? false))) {
            display.stepBrightness(isUp: mediaKey == .brightnessUp, isSmallIncrement: isSmallIncrement)
          }
        }
      case .brightnessDown:
        if isContrast, isPressed, let otherDisplay = display as? OtherDisplay {
          otherDisplay.stepContrast(isUp: mediaKey == .brightnessUp, isSmallIncrement: isSmallIncrement)
        } else if isPressed {
          display.stepBrightness(isUp: mediaKey == .brightnessUp, isSmallIncrement: isSmallIncrement)
        }
      case .mute:
        // The mute key should not respond to press + hold or keyup
        if !isRepeat, isPressed, let display = display as? OtherDisplay {
          display.toggleMute()
          if !wasNotIsPressedVolumeSentAlready, display.readPrefAsInt(for: .audioMuteScreenBlank) != 1, !display.readPrefAsBool(key: .unavailableDDC, for: .audioSpeakerVolume) {
            display.playVolumeChangedSound()
            wasNotIsPressedVolumeSentAlready = true
          }
        }
      case .volumeUp, .volumeDown:
        // volume only matters for other displays
        if let display = display as? OtherDisplay {
          if isPressed {
            display.stepVolume(isUp: mediaKey == .volumeUp, isSmallIncrement: isSmallIncrement)
          } else if !wasNotIsPressedVolumeSentAlready, !display.readPrefAsBool(key: .unavailableDDC, for: .audioSpeakerVolume) {
            display.playVolumeChangedSound()
            wasNotIsPressedVolumeSentAlready = true
          }
        }
      default:
        return
      }
    }
  }

  private func oppositeMediaKey(mediaKey: MediaKey) -> MediaKey? {
    if mediaKey == .brightnessUp {
      return .brightnessDown
    } else if mediaKey == .brightnessDown {
      return .brightnessUp
    } else if mediaKey == .volumeUp {
      return .volumeDown
    } else if mediaKey == .volumeDown {
      return .volumeUp
    }
    return nil
  }

  func updateMediaKeyTap() {
    var keys: [MediaKey] = []
    if !prefs.bool(forKey: PrefKey.disableListenForBrightness.rawValue) {
      keys.append(contentsOf: [.brightnessUp, .brightnessDown])
    }
    if !prefs.bool(forKey: PrefKey.disableListenForVolume.rawValue) {
      keys.append(contentsOf: [.mute, .volumeUp, .volumeDown])
    }
    // Remove keys if no external displays are connected
    var isInternalDisplayOnly = true
    for display in DisplayManager.shared.getAllDisplays() where !display.isBuiltIn() {
      isInternalDisplayOnly = false
    }
    if isInternalDisplayOnly {
      let keysToDelete: [MediaKey] = [.volumeUp, .volumeDown, .mute, .brightnessUp, .brightnessDown]
      keys.removeAll { keysToDelete.contains($0) }
    }
    // Remove volume related keys if audio device is controllable
    if !isInternalDisplayOnly, let defaultAudioDevice = app.coreAudio.defaultOutputDevice {
      let keysToDelete: [MediaKey] = [.volumeUp, .volumeDown, .mute]
      if !prefs.bool(forKey: PrefKey.allScreensVolume.rawValue), prefs.bool(forKey: PrefKey.useAudioDeviceNameMatching.rawValue) {
        if DisplayManager.shared.updateAudioControlTargetDisplays(deviceName: defaultAudioDevice.name) == 0 {
          keys.removeAll { keysToDelete.contains($0) }
        }
      } else if defaultAudioDevice.canSetVirtualMasterVolume(scope: .output) == true {
        keys.removeAll { keysToDelete.contains($0) }
      }
    }
    self.mediaKeyTap?.stop()
    // returning an empty array listens for all mediakeys in MediaKeyTap
    if keys.count > 0 {
      self.mediaKeyTap = MediaKeyTap(delegate: self, on: KeyPressMode.keyDownAndUp, for: keys, observeBuiltIn: true)
      self.mediaKeyTap?.start()
    }
  }

  func handleOpenPrefPane(mediaKey: MediaKey, event: KeyEvent?, modifiers: NSEvent.ModifierFlags?) -> Bool {
    guard let modifiers = modifiers else { return false }
    if !(modifiers.contains(.option) && !modifiers.contains(.shift) && !modifiers.contains(.control) && !modifiers.contains(.command)) {
      return false
    }
    if event?.keyRepeat == true {
      return false
    }
    switch mediaKey {
    case .brightnessUp, .brightnessDown:
      NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/PreferencePanes/Displays.prefPane"))
    case .mute, .volumeUp, .volumeDown:
      NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/PreferencePanes/Sound.prefPane"))
    default:
      return false
    }
    return true
  }

  static func acquirePrivileges() {
    if !self.readPrivileges(prompt: true) {
      let alert = NSAlert()
      alert.messageText = NSLocalizedString("Shortcuts not available", comment: "Shown in the alert dialog")
      alert.informativeText = NSLocalizedString("You need to enable MonitorControl in System Preferences > Security and Privacy > Accessibility for the keyboard shortcuts to work", comment: "Shown in the alert dialog")
      alert.runModal()
    }
  }

  static func readPrivileges(prompt: Bool) -> Bool {
    let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: prompt]
    let status = AXIsProcessTrustedWithOptions(options)
    os_log("Reading Accessibility privileges - Current access status %{public}@", type: .info, String(status))
    return status
  }
}
