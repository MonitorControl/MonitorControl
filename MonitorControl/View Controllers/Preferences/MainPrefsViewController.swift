//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Cocoa
import os.log
import ServiceManagement
import Settings

class MainPrefsViewController: NSViewController, SettingsPane {
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
    self.populateSettings()
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

  private func startingBrightnessReference() -> (Display, StartingBrightness)? {
    guard app.sleepID == 0, app.reconfigureID == 0, !app.safeMode,
          let source = DisplayManager.shared.getBuiltInDisplay() as? AppleDisplay,
          CGDisplayIsActive(source.identifier) != 0, CGDisplayIsAsleep(source.identifier) == 0,
          !source.isDummy, !source.isVirtual else { return nil }
    var level: Float = 0
    guard DisplayServicesGetBrightness(source.identifier, &level) == 0,
          let suggestion = StartingBrightness(builtInLevel: level) else { return nil }
    return (source, suggestion)
  }

  private func eligibleForStartingBrightness(_ display: OtherDisplay) -> Bool {
    !display.isDummy && !display.isVirtual && CGDisplayIsBuiltin(display.identifier) == 0 &&
      CGDisplayIsOnline(display.identifier) != 0 && CGDisplayIsAsleep(display.identifier) == 0 &&
      CGDisplayIsInMirrorSet(display.identifier) == 0 &&
      !display.readPrefAsBool(key: .isDisabled) && !display.readPrefAsBool(key: .unavailableDDC, for: .brightness)
  }

  private func suggestionName(for display: OtherDisplay) -> String {
    let friendly = display.readPrefAsString(key: .friendlyName)
    return friendly.isEmpty || friendly == display.name ? display.name : "\(friendly) (\(display.name))"
  }

  @IBAction func recommendBrightness(_ sender: NSButton) {
    let displays = DisplayManager.shared.getOtherDisplays().filter(self.eligibleForStartingBrightness)
    guard !displays.isEmpty, self.startingBrightnessReference() != nil else {
      self.showBrightnessNotice(NSLocalizedString("Open the built-in display and connect an independently adjustable external display to see a suggestion.", comment: "One-time brightness suggestion"))
      return
    }
    if displays.count == 1, let display = displays.first {
      self.offerStartingBrightness(for: display)
      return
    }
    let menu = NSMenu()
    for display in displays {
      let item = menu.addItem(withTitle: self.suggestionName(for: display), action: #selector(self.chooseSuggestionDisplay(_:)), keyEquivalent: "")
      item.target = self
      item.representedObject = display
    }
    menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.minY), in: sender)
  }

  @objc func chooseSuggestionDisplay(_ sender: NSMenuItem) {
    if let display = sender.representedObject as? OtherDisplay {
      self.offerStartingBrightness(for: display)
    }
  }

  private func showBrightnessNotice(_ text: String) {
    guard let window = self.view.window else { return }
    let alert = NSAlert()
    alert.messageText = text
    alert.beginSheetModal(for: window)
  }

  private func offerStartingBrightness(for display: OtherDisplay) {
    guard let window = self.view.window else { return }
    guard let (_, suggestion) = self.startingBrightnessReference(),
          DisplayManager.shared.getOtherDisplays().contains(where: { $0 === display }),
          self.eligibleForStartingBrightness(display) else {
      self.showBrightnessNotice(NSLocalizedString("Open the built-in display and connect an independently adjustable external display to see a suggestion.", comment: "One-time brightness suggestion"))
      return
    }
    let alert = NSAlert()
    let title = NSLocalizedString("Suggested starting brightness: %d%%", comment: "One-time brightness suggestion")
    alert.messageText = String(format: title, suggestion.percent)
    let current = display.getBrightness()
    guard current.isFinite, (0 ... 1).contains(current) else {
      self.showBrightnessNotice(NSLocalizedString("The current brightness is unavailable.", comment: "One-time brightness suggestion"))
      return
    }
    let line = "\(self.suggestionName(for: display)): \(Int((current * 100).rounded()))%"
    if !suggestion.wouldDim(current) {
      alert.informativeText = line + "\n\n" + NSLocalizedString("This display is already at or below the suggested level.", comment: "One-time brightness suggestion")
      alert.beginSheetModal(for: window)
      return
    }
    alert.informativeText = line + " → \(suggestion.percent)%\n\n" + NSLocalizedString("This one-time estimate uses the current built-in brightness. Apply it to this display, then fine-tune its slider.", comment: "One-time brightness suggestion")
    alert.addButton(withTitle: NSLocalizedString("Use Suggested Brightness", comment: "One-time brightness suggestion"))
    alert.addButton(withTitle: NSLocalizedString("Keep Current Levels", comment: "One-time brightness suggestion")).keyEquivalent = "\u{1b}"
    alert.beginSheetModal(for: window) { response in
      guard response == .alertFirstButtonReturn else { return }
      // A click accepts the displayed percentage, even if the reference screen has since changed.
      guard app.sleepID == 0, app.reconfigureID == 0, !app.safeMode,
            DisplayManager.shared.getOtherDisplays().contains(where: { $0 === display }),
            self.eligibleForStartingBrightness(display) else {
        self.showBrightnessNotice(NSLocalizedString("The selected display is no longer available.", comment: "One-time brightness suggestion"))
        return
      }
      guard suggestion.wouldDim(display.getBrightness()) else { return }
      if !display.applyStartingBrightness(suggestion) {
        self.showBrightnessNotice(NSLocalizedString("MonitorControl could not verify a dim-only adjustment. You can adjust this display manually.", comment: "One-time brightness suggestion"))
      }
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
