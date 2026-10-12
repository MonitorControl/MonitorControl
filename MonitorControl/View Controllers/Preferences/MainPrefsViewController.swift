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

  private var equalBrightnessWindowController: EqualBrightnessSettingsWindowController?

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

  /// Opens the standalone equal-brightness editor from the existing settings page.
  /// 从现有设置页打开独立的等亮度编辑器。
  @IBAction func equalBrightnessSettingsClicked(_: NSButton) {
    if let existingController = self.equalBrightnessWindowController {
      existingController.showSettings()
      return
    }

    let displays = DisplayManager.shared.displays.filter { !$0.isDummy }
    let savedProfile = EqualBrightnessSettingsStore.shared.load()
    let savedReferenceDisplay = displays.first { display in
      guard let savedReferenceKey = savedProfile?.referenceDisplayKey else {
        return false
      }
      return EqualBrightnessDisplayIdentity(display: display).key == savedReferenceKey
    }
    if let savedReferenceDisplay {
      self.openEqualBrightnessSettings(referenceDisplay: savedReferenceDisplay)
      return
    }

    if savedProfile?.referenceDisplayKey != nil {
      // A saved reference that is currently disconnected must be selected again.
      // 已保存的参考显示器当前未连接时，必须重新选择。
      guard !displays.isEmpty else {
        self.openEqualBrightnessSettings(referenceDisplay: nil)
        return
      }
      self.chooseReferenceDisplayAndOpenSettings(from: displays)
      return
    }

    if let automaticReferenceDisplay = EqualBrightnessDisplaySupport.automaticReferenceDisplay(from: displays) {
      self.openEqualBrightnessSettings(referenceDisplay: automaticReferenceDisplay)
      return
    }

    // Headless Macs and other systems without a built-in screen need an explicit reference.
    // 无头 Mac 以及没有内置屏幕的设备需要用户明确选择参考显示器。
    guard !displays.isEmpty else {
      self.openEqualBrightnessSettings(referenceDisplay: nil)
      return
    }
    self.chooseReferenceDisplayAndOpenSettings(from: displays)
  }

  /// Opens the editor after the reference display has been resolved.
  /// 确定参考显示器后打开编辑器。
  private func openEqualBrightnessSettings(referenceDisplay: Display?) {
    let controller = EqualBrightnessSettingsWindowController(referenceDisplay: referenceDisplay)
    controller.onSave = { [weak self] in
      self?.equalBrightnessWindowController = nil
    }
    controller.onCancel = { [weak self] in
      self?.equalBrightnessWindowController = nil
    }
    self.equalBrightnessWindowController = controller
    controller.showSettings()
  }

  /// Chooses a reference display and opens the editor only after confirmation.
  /// 选择参考显示器并仅在确认后打开编辑器。
  private func chooseReferenceDisplayAndOpenSettings(from displays: [Display]) {
    self.chooseReferenceDisplay(from: displays) { [weak self] selectedDisplay in
      guard let self, let selectedDisplay else {
        return
      }
      self.openEqualBrightnessSettings(referenceDisplay: selectedDisplay)
    }
  }

  /// Presents a localized display picker for headless and non-MacBook systems.
  /// 为无头 Mac 和非 MacBook 设备显示本地化的显示器选择器。
  private func chooseReferenceDisplay(from displays: [Display], completion: @escaping (Display?) -> Void) {
    let alert = NSAlert()
    alert.messageText = NSLocalizedString("Select Reference Display", comment: "Reference display selection title")
    alert.informativeText = NSLocalizedString("Choose a reference display for equal brightness settings.", comment: "Reference display selection explanation")

    let accessoryView = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 54))
    let label = NSTextField(labelWithString: NSLocalizedString("Reference display", comment: "Reference display picker label"))
    label.frame = NSRect(x: 0, y: 30, width: 320, height: 18)
    let displayPopup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 320, height: 26), pullsDown: false)
    displayPopup.addItems(withTitles: displays.enumerated().map { index, display in
      EqualBrightnessDisplaySupport.userFacingName(for: display, fallbackIndex: index)
    })
    accessoryView.addSubview(label)
    accessoryView.addSubview(displayPopup)
    alert.accessoryView = accessoryView
    alert.addButton(withTitle: NSLocalizedString("Continue", comment: "Reference display selection confirmation"))
    alert.addButton(withTitle: NSLocalizedString("Cancel", comment: "Reference display selection cancellation"))

    let response = alert.runModal()
    guard response == .alertFirstButtonReturn,
          displayPopup.indexOfSelectedItem >= 0,
          displayPopup.indexOfSelectedItem < displays.count else {
      completion(nil)
      return
    }
    completion(displays[displayPopup.indexOfSelectedItem])
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
