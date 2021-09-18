//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Cocoa
import os.log
import Preferences
import ServiceManagement

class MainPrefsViewController: NSViewController, PreferencePane {
  let preferencePaneIdentifier = Preferences.PaneIdentifier.main
  let preferencePaneTitle: String = NSLocalizedString("General", comment: "Shown in the main prefs window")

  var toolbarItemIcon: NSImage {
    if #available(macOS 11.0, *) {
      return NSImage(systemSymbolName: "switch.2", accessibilityDescription: "Display")!
    } else {
      return NSImage(named: NSImage.infoName)!
    }
  }

  @IBOutlet var startAtLogin: NSButton!
  @IBOutlet var disableSoftwareFallback: NSButton!
  @IBOutlet var combinedBrightness: NSButton!
  @IBOutlet var enableSmooth: NSButton!
  @IBOutlet var showAdvancedDisplays: NSButton!
  @IBOutlet var notEnableDDCDuringStartup: NSButton!
  @IBOutlet var writeDDCOnStartup: NSButton!
  @IBOutlet var readDDCOnStartup: NSButton!
  @IBOutlet var rowStartupSeparator: NSGridRow!
  @IBOutlet var rowDoNothingStartupCheck: NSGridRow!
  @IBOutlet var rowDoNothingStartupText: NSGridRow!
  @IBOutlet var rowWriteStartupCheck: NSGridRow!
  @IBOutlet var rowWriteStartupText: NSGridRow!
  @IBOutlet var rowReadStartupCheck: NSGridRow!
  @IBOutlet var rowReadStartupText: NSGridRow!
  @IBOutlet var rowSafeModeText: NSGridRow!
  @IBOutlet var rowResetButton: NSGridRow!
  @IBOutlet var rowDisableSoftwareFallbackCheck: NSGridRow!
  @IBOutlet var rowDisableSoftwareFallbackText: NSGridRow!

  func showAdvanced() -> Bool {
    let hide = !prefs.bool(forKey: PrefKey.showAdvancedSettings.rawValue)
    if self.notEnableDDCDuringStartup.state == .on {
      self.rowStartupSeparator.isHidden = hide
      self.rowDoNothingStartupCheck.isHidden = hide
      self.rowDoNothingStartupText.isHidden = hide
      self.rowWriteStartupCheck.isHidden = hide
      self.rowWriteStartupText.isHidden = hide
      self.rowReadStartupCheck.isHidden = hide
      self.rowReadStartupText.isHidden = hide
      self.rowSafeModeText.isHidden = hide
    } else {
      self.rowStartupSeparator.isHidden = false
      self.rowDoNothingStartupCheck.isHidden = false
      self.rowDoNothingStartupText.isHidden = false
      if self.writeDDCOnStartup.state == .on {
        self.rowWriteStartupCheck.isHidden = false
        self.rowWriteStartupText.isHidden = false
        self.rowReadStartupCheck.isHidden = hide
        self.rowReadStartupText.isHidden = hide
      } else {
        self.rowWriteStartupCheck.isHidden = hide
        self.rowWriteStartupText.isHidden = hide
        self.rowReadStartupCheck.isHidden = false
        self.rowReadStartupText.isHidden = false
      }
      self.rowSafeModeText.isHidden = false
    }
    if self.disableSoftwareFallback.state == .on {
      self.rowDisableSoftwareFallbackCheck.isHidden = false
      self.rowDisableSoftwareFallbackText.isHidden = false
    } else {
      self.rowDisableSoftwareFallbackCheck.isHidden = hide
      self.rowDisableSoftwareFallbackText.isHidden = hide
    }
    self.rowResetButton.isHidden = hide
    return !hide
  }

  @available(macOS, deprecated: 10.10)
  override func viewDidLoad() {
    super.viewDidLoad()
    self.populateSettings()
  }

  @available(macOS, deprecated: 10.10)
  func populateSettings() {
    // This is marked as deprectated but according to the function header it still does not have a replacement as of macOS 12 Monterey and is valid to use.
    let startAtLogin = (SMCopyAllJobDictionaries(kSMDomainUserLaunchd).takeRetainedValue() as? [[String: AnyObject]])?.first { $0["Label"] as? String == "\(Bundle.main.bundleIdentifier!)Helper" }?["OnDemand"] as? Bool ?? false
    self.startAtLogin.state = startAtLogin ? .on : .off
    self.combinedBrightness.state = prefs.bool(forKey: PrefKey.disableCombinedBrightness.rawValue) ? .off : .on
    self.disableSoftwareFallback.state = prefs.bool(forKey: PrefKey.disableSoftwareFallback.rawValue) ? .on : .off
    self.enableSmooth.state = prefs.bool(forKey: PrefKey.disableSmoothBrightness.rawValue) ? .off : .on
    self.showAdvancedDisplays.state = prefs.bool(forKey: PrefKey.showAdvancedSettings.rawValue) ? .on : .off
    self.notEnableDDCDuringStartup.state = !prefs.bool(forKey: PrefKey.enableDDCDuringStartup.rawValue) ? .on : .off
    self.writeDDCOnStartup.state = !prefs.bool(forKey: PrefKey.readDDCInsteadOfRestoreValues.rawValue) && prefs.bool(forKey: PrefKey.enableDDCDuringStartup.rawValue) ? .on : .off
    self.readDDCOnStartup.state = prefs.bool(forKey: PrefKey.readDDCInsteadOfRestoreValues.rawValue) && prefs.bool(forKey: PrefKey.enableDDCDuringStartup.rawValue) ? .on : .off
    // Preload Display preferences to some extent to properly set up size in orther that animation won't fail
    menuslidersPrefsVc?.view.layoutSubtreeIfNeeded()
    keyboardPrefsVc?.view.layoutSubtreeIfNeeded()
    displaysPrefsVc?.view.layoutSubtreeIfNeeded()
    aboutPrefsVc?.view.layoutSubtreeIfNeeded()
    _ = self.showAdvanced()
  }

  @IBAction func startAtLoginClicked(_ sender: NSButton) {
    switch sender.state {
    case .on:
      app.setStartAtLogin(enabled: true)
    case .off:
      app.setStartAtLogin(enabled: false)
    default: break
    }
  }

  @IBAction func combinedBrightness(_ sender: NSButton) {
    switch sender.state {
    case .on:
      prefs.set(false, forKey: PrefKey.disableCombinedBrightness.rawValue)
      DisplayManager.shared.resetSwBrightnessForAllDisplays(async: false)
      for display in DisplayManager.shared.getDdcCapableDisplays() where !display.isSw() {
        _ = display.setDirectBrightness(0.5 + display.getBrightness() / 2)
      }
    case .off:
      prefs.set(true, forKey: PrefKey.disableCombinedBrightness.rawValue)
      DisplayManager.shared.resetSwBrightnessForAllDisplays(async: !prefs.bool(forKey: PrefKey.disableSmoothBrightness.rawValue))
      for display in DisplayManager.shared.getDdcCapableDisplays() where !display.isSw() {
        _ = display.setDirectBrightness(max(0, (display.getBrightness() - 0.5) * 2))
      }
    default: break
    }
    app.updateDisplaysAndMenus()
  }

  @IBAction func disableSoftwareFallback(_ sender: NSButton) {
    switch sender.state {
    case .on:
      for display in DisplayManager.shared.getOtherDisplays() where display.isSw() {
        _ = display.setBrightness(1)
      }
      prefs.set(true, forKey: PrefKey.disableSoftwareFallback.rawValue)
    case .off:
      prefs.set(false, forKey: PrefKey.disableSoftwareFallback.rawValue)
      for display in DisplayManager.shared.getOtherDisplays() where display.isSw() {
        _ = display.setBrightness(1)
      }
    default: break
    }
    _ = self.showAdvanced()
    app.updateDisplaysAndMenus()
  }

  @IBAction func enableSmooth(_ sender: NSButton) {
    switch sender.state {
    case .on:
      prefs.set(false, forKey: PrefKey.disableSmoothBrightness.rawValue)
    case .off:
      prefs.set(true, forKey: PrefKey.disableSmoothBrightness.rawValue)
    default: break
    }
  }

  @IBAction func notEnableDDCDuringStartupClicked(_ sender: NSButton) {
    switch sender.state {
    case .on:
      prefs.set(false, forKey: PrefKey.enableDDCDuringStartup.rawValue)
      prefs.set(false, forKey: PrefKey.readDDCInsteadOfRestoreValues.rawValue)
      self.writeDDCOnStartup.state = .off
      self.readDDCOnStartup.state = .off
    default: break
    }
    _ = self.showAdvanced()
  }

  @IBAction func writeDDCOnStartupClicked(_ sender: NSButton) {
    switch sender.state {
    case .on:
      prefs.set(false, forKey: PrefKey.readDDCInsteadOfRestoreValues.rawValue)
      prefs.set(true, forKey: PrefKey.enableDDCDuringStartup.rawValue)
      self.notEnableDDCDuringStartup.state = .off
      self.readDDCOnStartup.state = .off
    default: break
    }
    _ = self.showAdvanced()
  }

  @IBAction func readDDCOnStartupClicked(_ sender: NSButton) {
    switch sender.state {
    case .on:
      prefs.set(true, forKey: PrefKey.readDDCInsteadOfRestoreValues.rawValue)
      prefs.set(true, forKey: PrefKey.enableDDCDuringStartup.rawValue)
      self.notEnableDDCDuringStartup.state = .off
      self.writeDDCOnStartup.state = .off
    default: break
    }
    _ = self.showAdvanced()
  }

  @IBAction func showAdvancedClicked(_ sender: NSButton) {
    switch sender.state {
    case .on:
      prefs.set(true, forKey: PrefKey.showAdvancedSettings.rawValue)
    case .off:
      prefs.set(false, forKey: PrefKey.showAdvancedSettings.rawValue)
    default: break
    }
    _ = self.showAdvanced()
    _ = menuslidersPrefsVc?.showAdvanced()
    _ = keyboardPrefsVc?.showAdvanced()
    _ = displaysPrefsVc?.showAdvanced()
    menuslidersPrefsVc?.view.layoutSubtreeIfNeeded()
    keyboardPrefsVc?.view.layoutSubtreeIfNeeded()
    displaysPrefsVc?.view.layoutSubtreeIfNeeded()
    aboutPrefsVc?.view.layoutSubtreeIfNeeded()
  }

  @available(macOS, deprecated: 10.10)
  func resetSheetModalHander(modalResponse: NSApplication.ModalResponse) {
    if modalResponse == NSApplication.ModalResponse.alertFirstButtonReturn {
      NotificationCenter.default.post(name: Notification.Name(PrefKey.preferenceReset.rawValue), object: nil)
      self.populateSettings()
      menuslidersPrefsVc?.populateSettings()
      keyboardPrefsVc?.populateSettings()
      displaysPrefsVc?.loadDisplayList()
      self.showAdvancedClicked(self.showAdvancedDisplays)
    }
  }

  @available(macOS, deprecated: 10.10)
  @IBAction func resetPrefsClicked(_: NSButton) {
    let alert = NSAlert()
    alert.messageText = NSLocalizedString("Reset Preferences?", comment: "Shown in the alert dialog")
    alert.informativeText = NSLocalizedString("Are you sure you want to reset all preferences?", comment: "Shown in the alert dialog")
    alert.addButton(withTitle: NSLocalizedString("Yes", comment: "Shown in the alert dialog"))
    alert.addButton(withTitle: NSLocalizedString("No", comment: "Shown in the alert dialog"))
    alert.alertStyle = NSAlert.Style.warning
    if let window = self.view.window {
      alert.beginSheetModal(for: window, completionHandler: { modalResponse in self.resetSheetModalHander(modalResponse: modalResponse) })
    }
  }
}
