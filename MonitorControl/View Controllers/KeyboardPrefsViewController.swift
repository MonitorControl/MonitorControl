//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Cocoa
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

  @IBOutlet var listenForBrightness: NSButton!
  @IBOutlet var disableAltBrightnessKeys: NSButton!
  @IBOutlet var listenForVolume: NSButton!

  @IBOutlet var allScreens: NSButton!
  @IBOutlet var useFocusInsteadOfMouse: NSButton!
  @IBOutlet var allScreensVolume: NSButton!
  @IBOutlet var useAudioDeviceNameMatching: NSButton!
  @IBOutlet var useFineScale: NSButton!
  @IBOutlet var useFineScaleVolume: NSButton!
  @IBOutlet var separateCombinedScale: NSButton!

  @IBOutlet var rowDisableAltBrightnessKeysCheck: NSGridRow!
  @IBOutlet var rowDisableAltBrightnessKeysText: NSGridRow!
  @IBOutlet var rowUseFocusCheck: NSGridRow!
  @IBOutlet var rowUseFocusText: NSGridRow!
  @IBOutlet var rowUseAudioNameCheck: NSGridRow!
  @IBOutlet var rowUseAudioNameText: NSGridRow!
  @IBOutlet var rowUseFineScaleCheck: NSGridRow!
  @IBOutlet var rowUseFineScaleText: NSGridRow!
  @IBOutlet var rowSeparateCombinedScaleCheck: NSGridRow!
  @IBOutlet var rowSeparateCombinedScaleText: NSGridRow!

  func showAdvanced() -> Bool {
    let hide = !prefs.bool(forKey: PKey.showAdvancedSettings.rawValue)
    if self.disableAltBrightnessKeys.state == .on {
      self.rowDisableAltBrightnessKeysCheck.isHidden = false
      self.rowDisableAltBrightnessKeysText.isHidden = false
    } else {
      self.rowDisableAltBrightnessKeysCheck.isHidden = hide
      self.rowDisableAltBrightnessKeysText.isHidden = hide
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

  override func viewDidLoad() {
    super.viewDidLoad()
    self.populateSettings()
  }

  func populateSettings() {
    self.listenForBrightness.state = prefs.bool(forKey: PKey.disableListenForBrightness.rawValue) ? .off : .on
    self.disableAltBrightnessKeys.state = prefs.bool(forKey: PKey.disableAltBrightnessKeys.rawValue) ? .on : .off
    self.listenForVolume.state = prefs.bool(forKey: PKey.disableListenForVolume.rawValue) ? .off : .on
    self.allScreens.state = prefs.bool(forKey: PKey.allScreensBrightness.rawValue) ? .on : .off
    self.useFocusInsteadOfMouse.state = prefs.bool(forKey: PKey.useFocusInsteadOfMouse.rawValue) ? .on : .off
    self.allScreensVolume.state = prefs.bool(forKey: PKey.allScreensVolume.rawValue) ? .on : .off
    self.useAudioDeviceNameMatching.state = prefs.bool(forKey: PKey.useAudioDeviceNameMatching.rawValue) ? .on : .off
    self.useFineScale.state = prefs.bool(forKey: PKey.useFineScaleBrightness.rawValue) ? .on : .off
    self.useFineScaleVolume.state = prefs.bool(forKey: PKey.useFineScaleVolume.rawValue) ? .on : .off
    self.separateCombinedScale.state = prefs.bool(forKey: PKey.separateCombinedScale.rawValue) ? .on : .off
    self.allScreensClicked(self.allScreens)
    self.allScreensVolumeClicked(self.allScreensVolume)
    _ = self.showAdvanced()
  }

  @IBAction func allScreensClicked(_ sender: NSButton) {
    switch sender.state {
    case .on:
      prefs.set(true, forKey: PKey.allScreensBrightness.rawValue)
      self.useFocusInsteadOfMouse.state = .off
      self.useFocusInsteadOfMouse.isEnabled = false
    case .off:
      prefs.set(false, forKey: PKey.allScreensBrightness.rawValue)
      self.useFocusInsteadOfMouse.isEnabled = true
      self.useFocusInsteadOfMouse.state = prefs.bool(forKey: PKey.useFocusInsteadOfMouse.rawValue) ? .on : .off
    default: break
    }
  }

  @IBAction func useFocusInsteadOfMouseClicked(_ sender: NSButton) {
    switch sender.state {
    case .on:
      prefs.set(true, forKey: PKey.useFocusInsteadOfMouse.rawValue)
    case .off:
      prefs.set(false, forKey: PKey.useFocusInsteadOfMouse.rawValue)
    default: break
    }
    _ = self.showAdvanced()
  }

  @IBAction func allScreensVolumeClicked(_ sender: NSButton) {
    switch sender.state {
    case .on:
      prefs.set(true, forKey: PKey.allScreensVolume.rawValue)
      self.useAudioDeviceNameMatching.state = .off
      self.useAudioDeviceNameMatching.isEnabled = false
    case .off:
      prefs.set(false, forKey: PKey.allScreensVolume.rawValue)
      self.useAudioDeviceNameMatching.isEnabled = true
      self.useAudioDeviceNameMatching.state = prefs.bool(forKey: PKey.useAudioDeviceNameMatching.rawValue) ? .on : .off
    default: break
    }
    app.updateMediaKeyTap()
  }

  @IBAction func useAudioDeviceNameMatchingClicked(_ sender: NSButton) {
    switch sender.state {
    case .on:
      prefs.set(true, forKey: PKey.useAudioDeviceNameMatching.rawValue)
    case .off:
      prefs.set(false, forKey: PKey.useAudioDeviceNameMatching.rawValue)
    default: break
    }
    app.updateMediaKeyTap()
    _ = self.showAdvanced()
  }

  @IBAction func useFineScaleClicked(_ sender: NSButton) {
    switch sender.state {
    case .on:
      prefs.set(true, forKey: PKey.useFineScaleBrightness.rawValue)
    case .off:
      prefs.set(false, forKey: PKey.useFineScaleBrightness.rawValue)
    default: break
    }
    _ = self.showAdvanced()
  }

  @IBAction func useFineScaleVolumeClicked(_ sender: NSButton) {
    switch sender.state {
    case .on:
      prefs.set(true, forKey: PKey.useFineScaleVolume.rawValue)
    case .off:
      prefs.set(false, forKey: PKey.useFineScaleVolume.rawValue)
    default: break
    }
  }

  @IBAction func separateCombinedScale(_ sender: NSButton) {
    switch sender.state {
    case .on:
      prefs.set(true, forKey: PKey.separateCombinedScale.rawValue)
    case .off:
      prefs.set(false, forKey: PKey.separateCombinedScale.rawValue)
    default: break
    }
    _ = self.showAdvanced()
  }

  @IBAction func listenForBrightness(_ sender: NSButton) {
    switch sender.state {
    case .on:
      prefs.set(false, forKey: PKey.disableListenForBrightness.rawValue)
    case .off:
      prefs.set(true, forKey: PKey.disableListenForBrightness.rawValue)
    default: break
    }
    app.handleListenForChanged()
  }

  @IBAction func disableAltBrightnessKeys(_ sender: NSButton) {
    switch sender.state {
    case .on:
      prefs.set(true, forKey: PKey.disableAltBrightnessKeys.rawValue)
    case .off:
      prefs.set(false, forKey: PKey.disableAltBrightnessKeys.rawValue)
    default: break
    }
    _ = self.showAdvanced()
    app.updateMediaKeyTap()
  }

  @IBAction func listenForVolume(_ sender: NSButton) {
    switch sender.state {
    case .on:
      prefs.set(false, forKey: PKey.disableListenForVolume.rawValue)
    case .off:
      prefs.set(true, forKey: PKey.disableListenForVolume.rawValue)
    default: break
    }
    app.handleListenForChanged()
  }
}
