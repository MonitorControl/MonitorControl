//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Cocoa
import KeyboardShortcuts
import Preferences
import ServiceManagement

class KeyboardPrefsViewController: NSViewController, PreferencePane {
  let preferencePaneIdentifier = Preferences.PaneIdentifier.keyboard
  let preferencePaneTitle: String = NSLocalizedString("Keyboard", comment: "Shown in the main prefs window")

  var toolbarItemIcon: NSImage {
    if !DEBUG_MACOS10, #available(macOS 11.0, *) {
      return NSImage(systemSymbolName: "keyboard", accessibilityDescription: "Keyboard")!
    } else {
      return NSImage(named: NSImage.infoName)!
    }
  }

  @IBOutlet var customBrightnessUp: NSView!
  @IBOutlet var customBrightnessDown: NSView!
  @IBOutlet var customContrastUp: NSView!
  @IBOutlet var customContrastDown: NSView!
  @IBOutlet var customVolumeUp: NSView!
  @IBOutlet var customVolumeDown: NSView!
  @IBOutlet var customMute: NSView!

  @IBOutlet var keyboardBrightness: NSPopUpButton!
  @IBOutlet var keyboardVolume: NSPopUpButton!
  @IBOutlet var disableAltBrightnessKeys: NSButton!

  @IBOutlet var allScreens: NSButton!
  @IBOutlet var useFocusInsteadOfMouse: NSButton!
  @IBOutlet var allScreensVolume: NSButton!
  @IBOutlet var useAudioDeviceNameMatching: NSButton!
  @IBOutlet var useFineScale: NSButton!
  @IBOutlet var useFineScaleVolume: NSButton!
  @IBOutlet var separateCombinedScale: NSButton!

  @IBOutlet var rowKeyboardBrightnessPopUp: NSGridRow!
  @IBOutlet var rowKeyboardBrightnessText: NSGridRow!
  @IBOutlet var rowDisableAltBrightnessKeysCheck: NSGridRow!
  @IBOutlet var rowDisableAltBrightnessKeysText: NSGridRow!
  @IBOutlet var rowCustomBrightnessShortcuts: NSGridRow!
  @IBOutlet var rowUseFocusCheck: NSGridRow!
  @IBOutlet var rowUseFocusText: NSGridRow!
  @IBOutlet var rowCustomAudioShortcuts: NSGridRow!
  @IBOutlet var rowUseAudioNameCheck: NSGridRow!
  @IBOutlet var rowUseAudioNameText: NSGridRow!
  @IBOutlet var rowUseFineScaleCheck: NSGridRow!
  @IBOutlet var rowUseFineScaleText: NSGridRow!
  @IBOutlet var rowSeparateCombinedScaleCheck: NSGridRow!
  @IBOutlet var rowSeparateCombinedScaleText: NSGridRow!

  // swiftlint:disable cyclomatic_complexity
  func showAdvanced() -> Bool {
    let hide = !prefs.bool(forKey: PrefKey.showAdvancedSettings.rawValue)

    if self.keyboardBrightness.selectedTag() == KeyboardBrightness.media.rawValue {
      self.rowKeyboardBrightnessPopUp.bottomPadding = hide ? -6 : -13
      self.rowKeyboardBrightnessText.isHidden = hide
      if self.disableAltBrightnessKeys.state == .on {
        self.rowDisableAltBrightnessKeysCheck.isHidden = false
        self.rowDisableAltBrightnessKeysText.isHidden = false
      } else {
        self.rowDisableAltBrightnessKeysCheck.isHidden = hide
        self.rowDisableAltBrightnessKeysText.isHidden = hide
      }
      self.rowCustomBrightnessShortcuts.isHidden = true
    } else if self.keyboardBrightness.selectedTag() == KeyboardBrightness.custom.rawValue {
      self.rowKeyboardBrightnessPopUp.bottomPadding = -6
      self.rowKeyboardBrightnessText.isHidden = true
      self.rowDisableAltBrightnessKeysCheck.isHidden = true
      self.rowDisableAltBrightnessKeysText.isHidden = true
      self.rowCustomBrightnessShortcuts.isHidden = false
    } else if self.keyboardBrightness.selectedTag() == KeyboardBrightness.both.rawValue {
      self.rowKeyboardBrightnessPopUp.bottomPadding = hide ? -6 : -13
      self.rowKeyboardBrightnessText.isHidden = hide
      if self.disableAltBrightnessKeys.state == .on {
        self.rowDisableAltBrightnessKeysCheck.isHidden = false
        self.rowDisableAltBrightnessKeysText.isHidden = false
      } else {
        self.rowDisableAltBrightnessKeysCheck.isHidden = hide
        self.rowDisableAltBrightnessKeysText.isHidden = hide
      }
      self.rowCustomBrightnessShortcuts.isHidden = false
    } else {
      self.rowKeyboardBrightnessPopUp.bottomPadding = -6
      self.rowKeyboardBrightnessText.isHidden = true
      self.rowDisableAltBrightnessKeysCheck.isHidden = true
      self.rowDisableAltBrightnessKeysText.isHidden = true
      self.rowCustomBrightnessShortcuts.isHidden = true
    }

    if self.keyboardBrightness.selectedTag() == KeyboardBrightness.disabled.rawValue {
      self.allScreens.isEnabled = false
      self.useFocusInsteadOfMouse.isEnabled = false
      self.useFineScale.isEnabled = false
      self.separateCombinedScale.isEnabled = false
    } else {
      self.allScreens.isEnabled = true
      self.useFocusInsteadOfMouse.isEnabled = self.allScreens.state == .off ? true : false
      self.useFineScale.isEnabled = true
      self.separateCombinedScale.isEnabled = true
    }

    if [KeyboardVolume.custom.rawValue, KeyboardVolume.both.rawValue].contains(self.keyboardVolume.selectedTag()) {
      self.rowCustomAudioShortcuts.isHidden = false
    } else {
      self.rowCustomAudioShortcuts.isHidden = true
    }

    if self.keyboardVolume.selectedTag() == KeyboardVolume.disabled.rawValue {
      self.allScreensVolume.isEnabled = false
      self.useAudioDeviceNameMatching.isEnabled = false
      self.useFineScaleVolume.isEnabled = false
    } else {
      self.allScreensVolume.isEnabled = true
      self.useAudioDeviceNameMatching.isEnabled = self.allScreensVolume.state == .off ? true : false
      self.useFineScaleVolume.isEnabled = true
    }

    if self.useFocusInsteadOfMouse.state == .on {
      self.rowUseFocusCheck.isHidden = false
      self.rowUseFocusText.isHidden = false
    } else {
      self.rowUseFocusCheck.isHidden = hide
      self.rowUseFocusText.isHidden = hide
    }
    if self.useAudioDeviceNameMatching.state == .on {
      self.rowUseAudioNameCheck.isHidden = false
      self.rowUseAudioNameText.isHidden = false
    } else {
      self.rowUseAudioNameCheck.isHidden = hide
      self.rowUseAudioNameText.isHidden = hide
    }

    if self.useFineScale.state == .on {
      self.rowUseFineScaleCheck.isHidden = false
      self.rowUseFineScaleText.isHidden = false
    } else {
      self.rowUseFineScaleCheck.isHidden = hide
      self.rowUseFineScaleText.isHidden = hide
    }

    if self.separateCombinedScale.state == .on {
      self.rowSeparateCombinedScaleCheck.isHidden = false
      self.rowSeparateCombinedScaleText.isHidden = false
    } else {
      self.rowSeparateCombinedScaleCheck.isHidden = hide
      self.rowSeparateCombinedScaleText.isHidden = hide
    }

    return !hide
  }

  // swiftlint:enable cyclomatic_complexity

  override func viewDidLoad() {
    super.viewDidLoad()

    let customBrightnessUpRecorder = KeyboardShortcuts.RecorderCocoa(for: .brightnessUp)
    self.customBrightnessUp.addSubview(customBrightnessUpRecorder)
    let customBrightnessDownRecorder = KeyboardShortcuts.RecorderCocoa(for: .brightnessDown)
    self.customBrightnessDown.addSubview(customBrightnessDownRecorder)
    let customContrastUpRecorder = KeyboardShortcuts.RecorderCocoa(for: .contrastUp)
    self.customContrastUp.addSubview(customContrastUpRecorder)
    let customContrastDownRecorder = KeyboardShortcuts.RecorderCocoa(for: .contrastDown)
    self.customContrastDown.addSubview(customContrastDownRecorder)
    let customVolumeUpRecorder = KeyboardShortcuts.RecorderCocoa(for: .volumeUp)
    self.customVolumeUp.addSubview(customVolumeUpRecorder)
    let customVolumeDownRecorder = KeyboardShortcuts.RecorderCocoa(for: .volumeDown)
    self.customVolumeDown.addSubview(customVolumeDownRecorder)
    let customMuteRecorder = KeyboardShortcuts.RecorderCocoa(for: .mute)
    self.customMute.addSubview(customMuteRecorder)
    self.populateSettings()
  }

  func populateSettings() {
    self.keyboardBrightness.selectItem(withTag: prefs.integer(forKey: PrefKey.keyboardBrightness.rawValue))
    self.keyboardVolume.selectItem(withTag: prefs.integer(forKey: PrefKey.keyboardVolume.rawValue))
    self.disableAltBrightnessKeys.state = prefs.bool(forKey: PrefKey.disableAltBrightnessKeys.rawValue) ? .on : .off
    self.allScreens.state = prefs.bool(forKey: PrefKey.allScreensBrightness.rawValue) ? .on : .off
    self.useFocusInsteadOfMouse.state = prefs.bool(forKey: PrefKey.useFocusInsteadOfMouse.rawValue) ? .on : .off
    self.allScreensVolume.state = prefs.bool(forKey: PrefKey.allScreensVolume.rawValue) ? .on : .off
    self.useAudioDeviceNameMatching.state = prefs.bool(forKey: PrefKey.useAudioDeviceNameMatching.rawValue) ? .on : .off
    self.useFineScale.state = prefs.bool(forKey: PrefKey.useFineScaleBrightness.rawValue) ? .on : .off
    self.useFineScaleVolume.state = prefs.bool(forKey: PrefKey.useFineScaleVolume.rawValue) ? .on : .off
    self.separateCombinedScale.state = prefs.bool(forKey: PrefKey.separateCombinedScale.rawValue) ? .on : .off
    self.allScreensClicked(self.allScreens)
    self.allScreensVolumeClicked(self.allScreensVolume)
    _ = self.showAdvanced()
  }

  @IBAction func allScreensClicked(_ sender: NSButton) {
    switch sender.state {
    case .on:
      prefs.set(true, forKey: PrefKey.allScreensBrightness.rawValue)
      self.useFocusInsteadOfMouse.state = .off
      self.useFocusInsteadOfMouse.isEnabled = false
    case .off:
      prefs.set(false, forKey: PrefKey.allScreensBrightness.rawValue)
      self.useFocusInsteadOfMouse.isEnabled = true
      self.useFocusInsteadOfMouse.state = prefs.bool(forKey: PrefKey.useFocusInsteadOfMouse.rawValue) ? .on : .off
    default: break
    }
  }

  @IBAction func useFocusInsteadOfMouseClicked(_ sender: NSButton) {
    switch sender.state {
    case .on:
      prefs.set(true, forKey: PrefKey.useFocusInsteadOfMouse.rawValue)
    case .off:
      prefs.set(false, forKey: PrefKey.useFocusInsteadOfMouse.rawValue)
    default: break
    }
    _ = self.showAdvanced()
  }

  @IBAction func allScreensVolumeClicked(_ sender: NSButton) {
    switch sender.state {
    case .on:
      prefs.set(true, forKey: PrefKey.allScreensVolume.rawValue)
      self.useAudioDeviceNameMatching.state = .off
      self.useAudioDeviceNameMatching.isEnabled = false
    case .off:
      prefs.set(false, forKey: PrefKey.allScreensVolume.rawValue)
      self.useAudioDeviceNameMatching.isEnabled = true
      self.useAudioDeviceNameMatching.state = prefs.bool(forKey: PrefKey.useAudioDeviceNameMatching.rawValue) ? .on : .off
    default: break
    }
    app.updateMediaKeyTap()
  }

  @IBAction func useAudioDeviceNameMatchingClicked(_ sender: NSButton) {
    switch sender.state {
    case .on:
      prefs.set(true, forKey: PrefKey.useAudioDeviceNameMatching.rawValue)
    case .off:
      prefs.set(false, forKey: PrefKey.useAudioDeviceNameMatching.rawValue)
    default: break
    }
    app.updateMediaKeyTap()
    _ = self.showAdvanced()
  }

  @IBAction func useFineScaleClicked(_ sender: NSButton) {
    switch sender.state {
    case .on:
      prefs.set(true, forKey: PrefKey.useFineScaleBrightness.rawValue)
    case .off:
      prefs.set(false, forKey: PrefKey.useFineScaleBrightness.rawValue)
    default: break
    }
    _ = self.showAdvanced()
  }

  @IBAction func useFineScaleVolumeClicked(_ sender: NSButton) {
    switch sender.state {
    case .on:
      prefs.set(true, forKey: PrefKey.useFineScaleVolume.rawValue)
    case .off:
      prefs.set(false, forKey: PrefKey.useFineScaleVolume.rawValue)
    default: break
    }
  }

  @IBAction func separateCombinedScale(_ sender: NSButton) {
    switch sender.state {
    case .on:
      prefs.set(true, forKey: PrefKey.separateCombinedScale.rawValue)
    case .off:
      prefs.set(false, forKey: PrefKey.separateCombinedScale.rawValue)
    default: break
    }
    _ = self.showAdvanced()
  }

  @IBAction func disableAltBrightnessKeys(_ sender: NSButton) {
    switch sender.state {
    case .on:
      prefs.set(true, forKey: PrefKey.disableAltBrightnessKeys.rawValue)
    case .off:
      prefs.set(false, forKey: PrefKey.disableAltBrightnessKeys.rawValue)
    default: break
    }
    _ = self.showAdvanced()
    app.updateMediaKeyTap()
  }

  @IBAction func keyboardBrightness(_ sender: NSPopUpButton) {
    prefs.set(sender.selectedTag(), forKey: PrefKey.keyboardBrightness.rawValue)
    app.updateMenusAndKeys()
    _ = self.showAdvanced()
  }

  @IBAction func keyboardVolume(_ sender: NSPopUpButton) {
    prefs.set(sender.selectedTag(), forKey: PrefKey.keyboardVolume.rawValue)
    app.updateMenusAndKeys()
    _ = self.showAdvanced()
  }
}
