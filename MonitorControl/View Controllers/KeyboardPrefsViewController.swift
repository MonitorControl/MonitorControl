//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Cocoa
import Preferences
import ServiceManagement

class KeyboardPrefsViewController: NSViewController, PreferencePane {
  let preferencePaneIdentifier = Preferences.PaneIdentifier.keyboard
  let preferencePaneTitle: String = NSLocalizedString("Keyboard", comment: "Shown in the main prefs window")

  var toolbarItemIcon: NSImage {
    if #available(macOS 11.0, *) {
      return NSImage(systemSymbolName: "keyboard", accessibilityDescription: "Keyboard")!
    } else {
      return NSImage(named: NSImage.infoName)!
    }
  }

  let prefs = UserDefaults.standard

  @IBOutlet var listenFor: NSPopUpButton!
  @IBOutlet var allScreens: NSButton!
  @IBOutlet var useFocusInsteadOfMouse: NSButton!
  @IBOutlet var allScreensVolume: NSButton!
  @IBOutlet var useAudioDeviceNameMatching: NSButton!
  @IBOutlet var useFineScale: NSButton!
  @IBOutlet var useFineScaleVolume: NSButton!

  @IBOutlet var rowUseFocusCheck: NSGridRow!
  @IBOutlet var rowUseFocusText: NSGridRow!
  @IBOutlet var rowUseAudioNameCheck: NSGridRow!
  @IBOutlet var rowUseAudioNameText: NSGridRow!
  @IBOutlet var rowUseFineScaleCheck: NSGridRow!
  @IBOutlet var rowUseFineScaleText: NSGridRow!

  func showAdvanced() -> Bool {
    let hide = !self.prefs.bool(forKey: PrefKey.showAdvancedSettings.rawValue)
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

    return !hide
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    self.populateSettings()
  }

  func populateSettings() {
    self.listenFor.selectItem(at: self.prefs.integer(forKey: PrefKey.listenFor.rawValue))
    self.allScreens.state = self.prefs.bool(forKey: PrefKey.allScreensBrightness.rawValue) ? .on : .off
    self.useFocusInsteadOfMouse.state = self.prefs.bool(forKey: PrefKey.useFocusInsteadOfMouse.rawValue) ? .on : .off
    self.allScreensVolume.state = self.prefs.bool(forKey: PrefKey.allScreensVolume.rawValue) ? .on : .off
    self.useAudioDeviceNameMatching.state = self.prefs.bool(forKey: PrefKey.useAudioDeviceNameMatching.rawValue) ? .on : .off
    self.useFineScale.state = self.prefs.bool(forKey: PrefKey.useFineScaleBrightness.rawValue) ? .on : .off
    self.useFineScaleVolume.state = self.prefs.bool(forKey: PrefKey.useFineScaleVolume.rawValue) ? .on : .off
    self.allScreensClicked(self.allScreens)
    self.allScreensVolumeClicked(self.allScreensVolume)
    _ = self.showAdvanced()
  }

  @IBAction func allScreensClicked(_ sender: NSButton) {
    switch sender.state {
    case .on:
      self.prefs.set(true, forKey: PrefKey.allScreensBrightness.rawValue)
      self.useFocusInsteadOfMouse.state = .off
      self.useFocusInsteadOfMouse.isEnabled = false
    case .off:
      self.prefs.set(false, forKey: PrefKey.allScreensBrightness.rawValue)
      self.useFocusInsteadOfMouse.isEnabled = true
      self.useFocusInsteadOfMouse.state = self.prefs.bool(forKey: PrefKey.useFocusInsteadOfMouse.rawValue) ? .on : .off
    default: break
    }
  }

  @IBAction func useFocusInsteadOfMouseClicked(_ sender: NSButton) {
    switch sender.state {
    case .on:
      self.prefs.set(true, forKey: PrefKey.useFocusInsteadOfMouse.rawValue)
    case .off:
      self.prefs.set(false, forKey: PrefKey.useFocusInsteadOfMouse.rawValue)
    default: break
    }
    _ = self.showAdvanced()
  }

  @IBAction func allScreensVolumeClicked(_ sender: NSButton) {
    switch sender.state {
    case .on:
      self.prefs.set(true, forKey: PrefKey.allScreensVolume.rawValue)
      self.useAudioDeviceNameMatching.state = .off
      self.useAudioDeviceNameMatching.isEnabled = false
    case .off:
      self.prefs.set(false, forKey: PrefKey.allScreensVolume.rawValue)
      self.useAudioDeviceNameMatching.isEnabled = true
      self.useAudioDeviceNameMatching.state = self.prefs.bool(forKey: PrefKey.useAudioDeviceNameMatching.rawValue) ? .on : .off
    default: break
    }
    app.updateMediaKeyTap()
  }

  @IBAction func useAudioDeviceNameMatchingClicked(_ sender: NSButton) {
    switch sender.state {
    case .on:
      self.prefs.set(true, forKey: PrefKey.useAudioDeviceNameMatching.rawValue)
    case .off:
      self.prefs.set(false, forKey: PrefKey.useAudioDeviceNameMatching.rawValue)
    default: break
    }
    app.updateMediaKeyTap()
    _ = self.showAdvanced()
  }

  @IBAction func useFineScaleClicked(_ sender: NSButton) {
    switch sender.state {
    case .on:
      self.prefs.set(true, forKey: PrefKey.useFineScaleBrightness.rawValue)
    case .off:
      self.prefs.set(false, forKey: PrefKey.useFineScaleBrightness.rawValue)
    default: break
    }
    _ = self.showAdvanced()
  }

  @IBAction func useFineScaleVolumeClicked(_ sender: NSButton) {
    switch sender.state {
    case .on:
      self.prefs.set(true, forKey: PrefKey.useFineScaleVolume.rawValue)
    case .off:
      self.prefs.set(false, forKey: PrefKey.useFineScaleVolume.rawValue)
    default: break
    }
  }

  @IBAction func listenForChanged(_ sender: NSPopUpButton) {
    self.prefs.set(sender.selectedTag(), forKey: PrefKey.listenFor.rawValue)
    NotificationCenter.default.post(name: Notification.Name(PrefKey.listenFor.rawValue), object: nil)
  }
}
