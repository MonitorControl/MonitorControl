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

  @IBOutlet var multiKeyboardBrightness: NSPopUpButton!
  @IBOutlet var multiKeyboardVolume: NSPopUpButton!
  @IBOutlet var useFineScale: NSButton!
  @IBOutlet var useFineScaleVolume: NSButton!
  @IBOutlet var separateCombinedScale: NSButton!

  @IBOutlet var rowKeyboardBrightnessPopUp: NSGridRow!
  @IBOutlet var rowKeyboardBrightnessText: NSGridRow!
  @IBOutlet var rowDisableAltBrightnessKeysCheck: NSGridRow!
  @IBOutlet var rowDisableAltBrightnessKeysText: NSGridRow!
  @IBOutlet var rowCustomBrightnessShortcuts: NSGridRow!
  @IBOutlet var rowMultiKeyboardBrightness: NSGridRow!
  @IBOutlet var rowUseFocusText: NSGridRow!
  @IBOutlet var rowCustomAudioShortcuts: NSGridRow!
  @IBOutlet var rowUseAudioMouseText: NSGridRow!
  @IBOutlet var rowUseAudioNameText: NSGridRow!
  @IBOutlet var rowUseFineScaleCheck: NSGridRow!
  @IBOutlet var rowUseFineScaleText: NSGridRow!
  @IBOutlet var rowSeparateCombinedScaleCheck: NSGridRow!
  @IBOutlet var rowSeparateCombinedScaleText: NSGridRow!

  // swiftlint:disable cyclomatic_complexity
  func updateGridLayout() -> Bool {
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
      self.rowKeyboardBrightnessPopUp.bottomPadding = -6
      self.rowKeyboardBrightnessText.isHidden = true
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
      self.multiKeyboardBrightness.isEnabled = false
      self.useFineScale.isEnabled = false
      self.separateCombinedScale.isEnabled = false
    } else {
      self.multiKeyboardBrightness.isEnabled = true
      self.useFineScale.isEnabled = true
      self.separateCombinedScale.isEnabled = true
    }

    if [KeyboardVolume.custom.rawValue, KeyboardVolume.both.rawValue].contains(self.keyboardVolume.selectedTag()) {
      self.rowCustomAudioShortcuts.isHidden = false
    } else {
      self.rowCustomAudioShortcuts.isHidden = true
    }

    if self.keyboardVolume.selectedTag() == KeyboardVolume.disabled.rawValue {
      self.multiKeyboardVolume.isEnabled = false
      self.useFineScaleVolume.isEnabled = false
    } else {
      self.multiKeyboardVolume.isEnabled = true
      self.useFineScaleVolume.isEnabled = true
    }

    if self.multiKeyboardBrightness.selectedTag() == MultiKeyboardBrightness.focusInsteadOfMouse.rawValue {
      self.rowMultiKeyboardBrightness.bottomPadding = -10
      self.rowUseFocusText.isHidden = false
    } else {
      self.rowMultiKeyboardBrightness.bottomPadding = -6
      self.rowUseFocusText.isHidden = true
    }

    if self.multiKeyboardVolume.selectedTag() == MultiKeyboardVolume.audioDeviceNameMatching.rawValue {
      self.rowUseAudioNameText.isHidden = false
      self.rowUseAudioMouseText.isHidden = true
    } else {
      self.rowUseAudioNameText.isHidden = true
      self.rowUseAudioMouseText.isHidden = false
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
    let customBrightnessDownRecorder = KeyboardShortcuts.RecorderCocoa(for: .brightnessDown)
    let customContrastUpRecorder = KeyboardShortcuts.RecorderCocoa(for: .contrastUp)
    let customContrastDownRecorder = KeyboardShortcuts.RecorderCocoa(for: .contrastDown)
    let customVolumeUpRecorder = KeyboardShortcuts.RecorderCocoa(for: .volumeUp)
    let customVolumeDownRecorder = KeyboardShortcuts.RecorderCocoa(for: .volumeDown)
    let customMuteRecorder = KeyboardShortcuts.RecorderCocoa(for: .mute)

    customBrightnessUpRecorder.placeholderString = NSLocalizedString("Increase", comment: "Shown in record shortcut box")
    customContrastUpRecorder.placeholderString = customBrightnessUpRecorder.placeholderString
    customVolumeUpRecorder.placeholderString = customBrightnessUpRecorder.placeholderString
    customBrightnessDownRecorder.placeholderString = NSLocalizedString("Decrease", comment: "Shown in record shortcut box")
    customContrastDownRecorder.placeholderString = customBrightnessDownRecorder.placeholderString
    customVolumeDownRecorder.placeholderString = customBrightnessDownRecorder.placeholderString
    customMuteRecorder.placeholderString = NSLocalizedString("Mute", comment: "Shown in record shortcut box")

    self.customBrightnessUp.addSubview(customBrightnessUpRecorder)
    self.customBrightnessDown.addSubview(customBrightnessDownRecorder)
    self.customContrastUp.addSubview(customContrastUpRecorder)
    self.customContrastDown.addSubview(customContrastDownRecorder)
    self.customVolumeUp.addSubview(customVolumeUpRecorder)
    self.customVolumeDown.addSubview(customVolumeDownRecorder)
    self.customMute.addSubview(customMuteRecorder)

    self.populateSettings()
  }

  func populateSettings() {
    self.keyboardBrightness.selectItem(withTag: prefs.integer(forKey: PrefKey.keyboardBrightness.rawValue))
    self.keyboardVolume.selectItem(withTag: prefs.integer(forKey: PrefKey.keyboardVolume.rawValue))
    self.disableAltBrightnessKeys.state = prefs.bool(forKey: PrefKey.disableAltBrightnessKeys.rawValue) ? .on : .off
    self.multiKeyboardBrightness.selectItem(withTag: prefs.integer(forKey: PrefKey.multiKeyboardBrightness.rawValue))
    self.multiKeyboardVolume.selectItem(withTag: prefs.integer(forKey: PrefKey.multiKeyboardVolume.rawValue))
    self.useFineScale.state = prefs.bool(forKey: PrefKey.useFineScaleBrightness.rawValue) ? .on : .off
    self.useFineScaleVolume.state = prefs.bool(forKey: PrefKey.useFineScaleVolume.rawValue) ? .on : .off
    self.separateCombinedScale.state = prefs.bool(forKey: PrefKey.separateCombinedScale.rawValue) ? .on : .off
    _ = self.updateGridLayout()
  }

  @IBAction func multiKeyboardBrightness(_ sender: NSPopUpButton) {
    prefs.set(sender.selectedTag(), forKey: PrefKey.multiKeyboardBrightness.rawValue)
    app.updateMediaKeyTap()
    _ = self.updateGridLayout()
  }

  @IBAction func multiKeyboardVolume(_ sender: NSPopUpButton) {
    prefs.set(sender.selectedTag(), forKey: PrefKey.multiKeyboardVolume.rawValue)
    app.updateMediaKeyTap()
    _ = self.updateGridLayout()
  }

  @IBAction func useFineScaleClicked(_ sender: NSButton) {
    switch sender.state {
    case .on:
      prefs.set(true, forKey: PrefKey.useFineScaleBrightness.rawValue)
    case .off:
      prefs.set(false, forKey: PrefKey.useFineScaleBrightness.rawValue)
    default: break
    }
    _ = self.updateGridLayout()
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
    _ = self.updateGridLayout()
  }

  @IBAction func disableAltBrightnessKeys(_ sender: NSButton) {
    switch sender.state {
    case .on:
      prefs.set(true, forKey: PrefKey.disableAltBrightnessKeys.rawValue)
    case .off:
      prefs.set(false, forKey: PrefKey.disableAltBrightnessKeys.rawValue)
    default: break
    }
    _ = self.updateGridLayout()
    app.updateMediaKeyTap()
  }

  @IBAction func keyboardBrightness(_ sender: NSPopUpButton) {
    prefs.set(sender.selectedTag(), forKey: PrefKey.keyboardBrightness.rawValue)
    app.updateMenusAndKeys()
    _ = self.updateGridLayout()
  }

  @IBAction func keyboardVolume(_ sender: NSPopUpButton) {
    prefs.set(sender.selectedTag(), forKey: PrefKey.keyboardVolume.rawValue)
    app.updateMenusAndKeys()
    _ = self.updateGridLayout()
  }
}
