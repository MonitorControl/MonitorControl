//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Cocoa
import os.log
import ServiceManagement
import Settings

class MainPrefsViewController: NSViewController, SettingsPane {
  private static let appleLanguagesKey = "AppleLanguages"

  let paneIdentifier = Settings.PaneIdentifier.main
  let paneTitle: String = NSLocalizedString("General", comment: "Shown in the main prefs window")

  var toolbarItemIcon: NSImage {
    if !DEBUG_MACOS10, #available(macOS 11.0, *) {
      return NSImage(systemSymbolName: "switch.2", accessibilityDescription: "Display")!
    } else {
      return NSImage(named: NSImage.infoName)!
    }
  }

  @IBOutlet var startAtLogin: NSButton!
  @IBOutlet var automaticUpdateCheck: NSButton!
  @IBOutlet var allowZeroSwBrightness: NSButton!
  @IBOutlet var combinedBrightness: NSButton!
  @IBOutlet var enableSmooth: NSButton!
  @IBOutlet var enableBrightnessSync: NSButton!
  @IBOutlet var startupAction: NSPopUpButton!
  @IBOutlet var rowDoNothingStartupText: NSGridRow!
  @IBOutlet var rowWriteStartupText: NSGridRow!
  @IBOutlet var rowReadStartupText: NSGridRow!

  func updateGridLayout() {
    if self.startupAction.selectedTag() == StartupAction.doNothing.rawValue {
      self.rowDoNothingStartupText.isHidden = false
      self.rowWriteStartupText.isHidden = true
      self.rowReadStartupText.isHidden = true
    } else if self.startupAction.selectedTag() == StartupAction.write.rawValue {
      self.rowDoNothingStartupText.isHidden = true
      self.rowWriteStartupText.isHidden = false
      self.rowReadStartupText.isHidden = true
    } else {
      self.rowDoNothingStartupText.isHidden = true
      self.rowWriteStartupText.isHidden = true
      self.rowReadStartupText.isHidden = false
    }
  }

  @available(macOS, deprecated: 10.10)
  override func viewDidLoad() {
    super.viewDidLoad()
    self.addLanguageSetting()
    self.populateSettings()
  }

  private func addLanguageSetting() {
    guard let gridView = self.view.subviews.compactMap({ $0 as? NSGridView }).first else {
      return
    }

    let label = NSTextField(labelWithString: NSLocalizedString("Language:", comment: "Shown in the main prefs window"))
    label.alignment = .right

    let languagePicker = NSPopUpButton(frame: .zero, pullsDown: false)
    languagePicker.target = self
    languagePicker.action = #selector(self.languageChanged(_:))

    let systemDefaultItem = NSMenuItem(title: NSLocalizedString("System Default", comment: "Shown in the language picker"), action: nil, keyEquivalent: "")
    systemDefaultItem.representedObject = ""
    languagePicker.menu?.addItem(systemDefaultItem)

    for identifier in self.availableLanguageIdentifiers() {
      let locale = Locale(identifier: identifier)
      let languageName = locale.localizedString(forLanguageCode: identifier) ?? identifier
      let item = NSMenuItem(title: languageName.capitalized(with: locale), action: nil, keyEquivalent: "")
      item.representedObject = identifier
      languagePicker.menu?.addItem(item)
    }

    let selectedIdentifier = self.preferredLanguageIdentifier()
    languagePicker.select(languagePicker.itemArray.first { ($0.representedObject as? String) == selectedIdentifier })
    gridView.addRow(with: [label, languagePicker])
  }

  private func availableLanguageIdentifiers() -> [String] {
    Bundle.main.localizations
      .filter { $0 != "Base" }
      .sorted {
        let firstLocale = Locale(identifier: $0)
        let secondLocale = Locale(identifier: $1)
        let firstName = firstLocale.localizedString(forLanguageCode: $0) ?? $0
        let secondName = secondLocale.localizedString(forLanguageCode: $1) ?? $1
        return firstName.localizedStandardCompare(secondName) == .orderedAscending
      }
  }

  private func preferredLanguageIdentifier() -> String {
    guard let bundleIdentifier = Bundle.main.bundleIdentifier,
          let languages = prefs.persistentDomain(forName: bundleIdentifier)?[Self.appleLanguagesKey] as? [String]
    else {
      return ""
    }
    return languages.first ?? ""
  }

  @objc private func languageChanged(_ sender: NSPopUpButton) {
    guard let identifier = sender.selectedItem?.representedObject as? String else {
      return
    }

    if identifier.isEmpty {
      prefs.removeObject(forKey: Self.appleLanguagesKey)
    } else {
      prefs.set([identifier], forKey: Self.appleLanguagesKey)
    }

    let alert = NSAlert()
    alert.messageText = NSLocalizedString("Language Change Requires Restart", comment: "Shown after changing the app language")
    alert.informativeText = NSLocalizedString("The new language will be used the next time MonitorControl is opened.", comment: "Shown after changing the app language")
    alert.addButton(withTitle: NSLocalizedString("Quit MonitorControl", comment: "Shown after changing the app language"))
    alert.addButton(withTitle: NSLocalizedString("Later", comment: "Shown after changing the app language"))
    alert.alertStyle = .informational

    if alert.runModal() == .alertFirstButtonReturn {
      NSApp.terminate(nil)
    }
  }

  @available(macOS, deprecated: 10.10)
  func populateSettings() {
    // This is marked as deprectated but according to the function header it still does not have a replacement as of macOS 12 Monterey and is valid to use.
    let startAtLogin = (SMCopyAllJobDictionaries(kSMDomainUserLaunchd).takeRetainedValue() as? [[String: AnyObject]])?.first { $0["Label"] as? String == "\(Bundle.main.bundleIdentifier!)Helper" }?["OnDemand"] as? Bool ?? false
    self.startAtLogin.state = startAtLogin ? .on : .off
    self.automaticUpdateCheck.state = prefs.bool(forKey: PrefKey.SUEnableAutomaticChecks.rawValue) ? .on : .off
    self.combinedBrightness.state = prefs.bool(forKey: PrefKey.disableCombinedBrightness.rawValue) ? .off : .on
    self.allowZeroSwBrightness.state = prefs.bool(forKey: PrefKey.allowZeroSwBrightness.rawValue) ? .on : .off
    self.enableSmooth.state = prefs.bool(forKey: PrefKey.disableSmoothBrightness.rawValue) ? .off : .on
    self.enableBrightnessSync.state = prefs.bool(forKey: PrefKey.enableBrightnessSync.rawValue) ? .on : .off
    self.startupAction.selectItem(withTag: prefs.integer(forKey: PrefKey.startupAction.rawValue))
    // Preload Display settings to some extent to properly set up size in orther that animation won't fail
    menuslidersPrefsVc?.view.layoutSubtreeIfNeeded()
    keyboardPrefsVc?.view.layoutSubtreeIfNeeded()
    displaysPrefsVc?.view.layoutSubtreeIfNeeded()
    aboutPrefsVc?.view.layoutSubtreeIfNeeded()
    self.updateGridLayout()
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
    self.updateGridLayout()
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
    self.updateGridLayout()
  }

  @available(macOS, deprecated: 10.10)
  func resetSheetModalHander(modalResponse: NSApplication.ModalResponse) {
    if modalResponse == NSApplication.ModalResponse.alertFirstButtonReturn {
      app.settingsReset()
      self.populateSettings()
      menuslidersPrefsVc?.populateSettings()
      keyboardPrefsVc?.populateSettings()
      displaysPrefsVc?.populateSettings()
    }
  }

  @available(macOS, deprecated: 10.10)
  @IBAction func resetPrefsClicked(_: NSButton) {
    let alert = NSAlert()
    alert.messageText = NSLocalizedString("Reset Settings?", comment: "Shown in the alert dialog")
    alert.informativeText = NSLocalizedString("Are you sure you want to reset all settings?", comment: "Shown in the alert dialog")
    alert.addButton(withTitle: NSLocalizedString("Yes", comment: "Shown in the alert dialog"))
    alert.addButton(withTitle: NSLocalizedString("No", comment: "Shown in the alert dialog"))
    alert.alertStyle = NSAlert.Style.warning
    if let window = self.view.window {
      alert.beginSheetModal(for: window, completionHandler: { modalResponse in self.resetSheetModalHander(modalResponse: modalResponse) })
    }
  }
}
