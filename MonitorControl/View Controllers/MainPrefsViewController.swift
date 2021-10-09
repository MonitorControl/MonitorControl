//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Cocoa
import os.log
import Preferences
import ServiceManagement

class MainPrefsViewController: NSViewController, PreferencePane {
  let preferencePaneIdentifier = Preferences.PaneIdentifier.main
  let preferencePaneTitle: String = NSLocalizedString("General", comment: "Shown in the main prefs window")

  var toolbarItemIcon: NSImage {
    if !DEBUG_MACOS10, #available(macOS 11.0, *) {
      return NSImage(systemSymbolName: "switch.2", accessibilityDescription: "Display")!
    } else {
      return NSImage(named: NSImage.infoName)!
    }
  }

  @IBOutlet var startAtLogin: NSButton!
  @IBOutlet var automaticUpdateCheck: NSButton!
  @IBOutlet var disableSoftwareFallback: NSButton!
  @IBOutlet var allowZeroSwBrightness: NSButton!
  @IBOutlet var combinedBrightness: NSButton!
  @IBOutlet var enableSmooth: NSButton!
  @IBOutlet var enableBrightnessSync: NSButton!
  @IBOutlet var showAdvancedDisplays: NSButton!
  @IBOutlet var startupAction: NSPopUpButton!
  @IBOutlet var rowStartupSeparator: NSGridRow!
  @IBOutlet var rowStartupAction: NSGridRow!
  @IBOutlet var rowDoNothingStartupText: NSGridRow!
  @IBOutlet var rowWriteStartupText: NSGridRow!
  @IBOutlet var rowReadStartupText: NSGridRow!
  @IBOutlet var rowSafeModeText: NSGridRow!
  @IBOutlet var rowResetButton: NSGridRow!
  @IBOutlet var rowDisableSoftwareFallbackCheck: NSGridRow!
  @IBOutlet var rowDisableSoftwareFallbackText: NSGridRow!
  @IBOutlet var rowAllowZeroSwBrightnessCheck: NSGridRow!
  @IBOutlet var rowAllowZeroSwBrightnessText: NSGridRow!

  func updateGridLayout() -> Bool {
    let hide = !prefs.bool(forKey: PrefKey.showAdvancedSettings.rawValue)
    if self.startupAction.selectedTag() == StartupAction.doNothing.rawValue {
      self.rowStartupSeparator.isHidden = hide
      self.rowStartupAction.isHidden = hide
      self.rowDoNothingStartupText.isHidden = hide
      self.rowWriteStartupText.isHidden = true
      self.rowReadStartupText.isHidden = true
      self.rowSafeModeText.isHidden = hide
    } else if self.startupAction.selectedTag() == StartupAction.write.rawValue {
      self.rowStartupSeparator.isHidden = false
      self.rowStartupAction.isHidden = false
      self.rowDoNothingStartupText.isHidden = true
      self.rowWriteStartupText.isHidden = false
      self.rowReadStartupText.isHidden = true
      self.rowSafeModeText.isHidden = false
    } else {
      self.rowStartupSeparator.isHidden = false
      self.rowStartupAction.isHidden = false
      self.rowDoNothingStartupText.isHidden = true
      self.rowWriteStartupText.isHidden = true
      self.rowReadStartupText.isHidden = false
      self.rowSafeModeText.isHidden = false
    }
    if self.disableSoftwareFallback.state == .on {
      self.rowDisableSoftwareFallbackCheck.isHidden = false
      self.rowDisableSoftwareFallbackText.isHidden = false
    } else {
      self.rowDisableSoftwareFallbackCheck.isHidden = hide
      self.rowDisableSoftwareFallbackText.isHidden = hide
    }
    if self.allowZeroSwBrightness.state == .on {
      self.rowAllowZeroSwBrightnessCheck.isHidden = false
      self.rowAllowZeroSwBrightnessText.isHidden = false
    } else {
      self.rowAllowZeroSwBrightnessCheck.isHidden = hide
      self.rowAllowZeroSwBrightnessText.isHidden = hide
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
    self.automaticUpdateCheck.state = prefs.bool(forKey: PrefKey.SUEnableAutomaticChecks.rawValue) ? .on : .off
    self.combinedBrightness.state = prefs.bool(forKey: PrefKey.disableCombinedBrightness.rawValue) ? .off : .on
    self.disableSoftwareFallback.state = prefs.bool(forKey: PrefKey.disableSoftwareFallback.rawValue) ? .on : .off
    self.allowZeroSwBrightness.state = prefs.bool(forKey: PrefKey.allowZeroSwBrightness.rawValue) ? .on : .off
    self.enableSmooth.state = prefs.bool(forKey: PrefKey.disableSmoothBrightness.rawValue) ? .off : .on
    self.enableBrightnessSync.state = prefs.bool(forKey: PrefKey.enableBrightnessSync.rawValue) ? .on : .off
    self.showAdvancedDisplays.state = prefs.bool(forKey: PrefKey.showAdvancedSettings.rawValue) ? .on : .off
    self.startupAction.selectItem(withTag: prefs.integer(forKey: PrefKey.startupAction.rawValue))
    // Preload Display preferences to some extent to properly set up size in orther that animation won't fail
    menuslidersPrefsVc?.view.layoutSubtreeIfNeeded()
    keyboardPrefsVc?.view.layoutSubtreeIfNeeded()
    displaysPrefsVc?.view.layoutSubtreeIfNeeded()
    aboutPrefsVc?.view.layoutSubtreeIfNeeded()
    _ = self.updateGridLayout()
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

  @IBAction func automaticUpdateCheck(_ sender: NSButton) {
    switch sender.state {
    case .on:
      prefs.set(true, forKey: PrefKey.SUEnableAutomaticChecks.rawValue)
    case .off:
      prefs.set(false, forKey: PrefKey.SUEnableAutomaticChecks.rawValue)
    default: break
    }
  }

  @IBAction func combinedBrightness(_ sender: NSButton) {
    for display in DisplayManager.shared.getDdcCapableDisplays() where !display.isSw() {
      _ = display.setDirectBrightness(1)
    }
    DisplayManager.shared.resetSwBrightnessForAllDisplays(async: false)
    switch sender.state {
    case .on:
      prefs.set(false, forKey: PrefKey.disableCombinedBrightness.rawValue)
    case .off:
      prefs.set(true, forKey: PrefKey.disableCombinedBrightness.rawValue)
    default: break
    }
    app.configure()
  }

  @IBAction func disableSoftwareFallback(_ sender: NSButton) {
    switch sender.state {
    case .on:
      prefs.set(true, forKey: PrefKey.disableSoftwareFallback.rawValue)
    case .off:
      prefs.set(false, forKey: PrefKey.disableSoftwareFallback.rawValue)
    default: break
    }
    for display in DisplayManager.shared.getOtherDisplays() {
      _ = display.setDirectBrightness(1)
      _ = display.setSwBrightness(1)
    }
    _ = self.updateGridLayout()
    app.configure()
  }

  @IBAction func allowZeroSwBrightness(_ sender: NSButton) {
    switch sender.state {
    case .on:
      prefs.set(true, forKey: PrefKey.allowZeroSwBrightness.rawValue)
    case .off:
      prefs.set(false, forKey: PrefKey.allowZeroSwBrightness.rawValue)
    default: break
    }
    for display in DisplayManager.shared.getOtherDisplays() {
      _ = display.setDirectBrightness(1)
      _ = display.setSwBrightness(1)
    }
    _ = self.updateGridLayout()
    app.configure()
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

  @IBAction func enableBrightnessSync(_ sender: NSButton) {
    switch sender.state {
    case .on:
      prefs.set(true, forKey: PrefKey.enableBrightnessSync.rawValue)
    case .off:
      prefs.set(false, forKey: PrefKey.enableBrightnessSync.rawValue)
    default: break
    }
  }

  @IBAction func startupAction(_ sender: NSPopUpButton) {
    prefs.set(sender.selectedTag(), forKey: PrefKey.startupAction.rawValue)
    _ = self.updateGridLayout()
  }

  @IBAction func showAdvancedClicked(_ sender: NSButton) {
    switch sender.state {
    case .on:
      prefs.set(true, forKey: PrefKey.showAdvancedSettings.rawValue)
    case .off:
      prefs.set(false, forKey: PrefKey.showAdvancedSettings.rawValue)
    default: break
    }
    _ = self.updateGridLayout()
    _ = menuslidersPrefsVc?.updateGridLayout()
    _ = keyboardPrefsVc?.updateGridLayout()
    _ = displaysPrefsVc?.updateGridLayout()
    menuslidersPrefsVc?.view.layoutSubtreeIfNeeded()
    keyboardPrefsVc?.view.layoutSubtreeIfNeeded()
    displaysPrefsVc?.view.layoutSubtreeIfNeeded()
    aboutPrefsVc?.view.layoutSubtreeIfNeeded()
  }

  @available(macOS, deprecated: 10.10)
  func resetSheetModalHander(modalResponse: NSApplication.ModalResponse) {
    if modalResponse == NSApplication.ModalResponse.alertFirstButtonReturn {
      app.preferenceReset()
      self.populateSettings()
      menuslidersPrefsVc?.populateSettings()
      keyboardPrefsVc?.populateSettings()
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
