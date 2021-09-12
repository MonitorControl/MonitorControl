//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Cocoa
import Foundation
import MediaKeyTap
import os.log
import Preferences
import ServiceManagement
import SimplyCoreAudio

var app: AppDelegate!
let prefs = UserDefaults.standard

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
  @IBOutlet var statusMenu: NSMenu!
  let minPreviousBuildNumber = 3380 // Below this previous app version there is a mandatory preferences reset!
  let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
  var mediaKeyTap = MediaKeyTapManager()
  var monitorItems: [NSMenuItem] = []
  let coreAudio = SimplyCoreAudio()
  var accessibilityObserver: NSObjectProtocol!
  var reconfigureID: Int = 0 // dispatched reconfigure command ID
  var sleepID: Int = 0 // Don't reconfigure display as the system or display is sleeping or wake just recently.
  var safeMode = false // Safe mode engaged during startup?
  var brightnessJobRunning = false // Is brightness job active?
  let debugSw: Bool = false
  let ddcQueue = DispatchQueue(label: "DDC queue")

  var preferencePaneStyle: Preferences.Style {
    if #available(macOS 11.0, *) {
      return Preferences.Style.toolbarItems
    } else {
      return Preferences.Style.segmentedControl
    }
  }

  lazy var preferencesWindowController: PreferencesWindowController = {
    let storyboard = NSStoryboard(name: "Main", bundle: Bundle.main)
    let mainPrefsVc = storyboard.instantiateController(withIdentifier: "MainPrefsVC") as? MainPrefsViewController
    let displaysPrefsVc = storyboard.instantiateController(withIdentifier: "DisplaysPrefsVC") as? DisplaysPrefsViewController
    let menuslidersPrefsVc = storyboard.instantiateController(withIdentifier: "MenuslidersPrefsVC") as? MenuslidersPrefsViewController
    let keyboardPrefsVc = storyboard.instantiateController(withIdentifier: "KeyboardPrefsVC") as? KeyboardPrefsViewController
    let advancedPrefsVc = storyboard.instantiateController(withIdentifier: "AdvancedPrefsVC") as? AdvancedPrefsViewController
    let aboutPrefsVc = storyboard.instantiateController(withIdentifier: "AboutPrefsVC") as? AboutPrefsViewController
    return PreferencesWindowController(
      preferencePanes: [
        mainPrefsVc!,
        menuslidersPrefsVc!,
        keyboardPrefsVc!,
        displaysPrefsVc!,
        // advancedPrefsVc!,
        aboutPrefsVc!,
      ],
      style: preferencePaneStyle,
      animated: true
    )
  }()

  func applicationDidFinishLaunching(_: Notification) {
    app = self
    self.subscribeEventListeners()
    if NSEvent.modifierFlags.contains(NSEvent.ModifierFlags.shift) {
      self.safeMode = true
      self.handlePreferenceReset()
      let alert = NSAlert()
      alert.alertStyle = NSAlert.Style.informational
      alert.messageText = NSLocalizedString("Safe Mode Activated", comment: "Shown in the alert dialog")
      alert.informativeText = NSLocalizedString("Shift was pressed during launch. MonitorControl started in safe mode. Default preferences are reloaded, DDC read is blocked.", comment: "Shown in the alert dialog")
      alert.addButton(withTitle: NSLocalizedString("OK", comment: "Shown in the alert dialog"))
      alert.runModal()
    }
    self.setDefaultPrefs()
    if #available(macOS 11.0, *) {
      self.statusItem.button?.image = NSImage(systemSymbolName: "sun.max", accessibilityDescription: "MonitorControl")
    } else {
      self.statusItem.button?.image = NSImage(named: "status")
    }
    self.statusItem.isVisible = prefs.bool(forKey: PrefKey.hideMenuIcon.rawValue) ? false : true
    self.statusItem.menu = self.statusMenu
    self.checkPermissions()
    CGDisplayRegisterReconfigurationCallback({ _, _, _ in app.displayReconfigured() }, nil)
    self.configuration(firstrun: true)
  }

  func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows _: Bool) -> Bool {
    self.prefsClicked(self)
    return true
  }

  func applicationWillTerminate(_: Notification) {
    os_log("Goodbye!", type: .info)
    DisplayManager.shared.resetSwBrightnessForAllDisplays()
    self.statusItem.isVisible = true
  }

  @IBAction func quitClicked(_: AnyObject) {
    NSApplication.shared.terminate(self)
  }

  @IBAction func prefsClicked(_: AnyObject) {
    self.preferencesWindowController.show()
  }

  func setDefaultPrefs() {
    let currentBuildNumber = Int(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1") ?? 1
    let previousBuildNumber: Int = (Int(prefs.string(forKey: PrefKey.buildNumber.rawValue) ?? "0") ?? 0)
    if !prefs.bool(forKey: PrefKey.appAlreadyLaunched.rawValue) || (previousBuildNumber < self.minPreviousBuildNumber && previousBuildNumber > 0) || previousBuildNumber > currentBuildNumber {
      // Preferences reset is needed
      prefs.set(true, forKey: PrefKey.appAlreadyLaunched.rawValue)
      prefs.set(false, forKey: PrefKey.hideBrightness.rawValue)
      prefs.set(false, forKey: PrefKey.showContrast.rawValue)
      prefs.set(true, forKey: PrefKey.showVolume.rawValue)
      prefs.set(true, forKey: PrefKey.fallbackSw.rawValue)
      prefs.set(false, forKey: PrefKey.hideAppleFromMenu.rawValue)
      prefs.set(false, forKey: PrefKey.enableSliderSnap.rawValue)
      prefs.set(false, forKey: PrefKey.hideMenuIcon.rawValue)
      prefs.set(false, forKey: PrefKey.showAdvancedDisplays.rawValue)
      prefs.set(false, forKey: PrefKey.lowerSwAfterBrightness.rawValue)
      prefs.set(false, forKey: PrefKey.useFocusInsteadOfMouse.rawValue)
      prefs.set(false, forKey: PrefKey.readDDCInsteadOfRestoreValues.rawValue)
      prefs.set(false, forKey: PrefKey.useFocusInsteadOfMouse.rawValue)
      prefs.set(false, forKey: PrefKey.allScreensVolume.rawValue)
      prefs.set(false, forKey: PrefKey.useAudioDeviceNameMatching.rawValue)
      prefs.set(false, forKey: PrefKey.useFineScaleBrightness.rawValue)
      prefs.set(false, forKey: PrefKey.useFineScaleVolume.rawValue)
    }
    prefs.set(currentBuildNumber, forKey: PrefKey.buildNumber.rawValue)
  }

  func clearMenu() {
    if self.statusMenu.items.count > 2 {
      var items: [NSMenuItem] = []
      for i in 0 ..< self.statusMenu.items.count - 2 {
        items.append(self.statusMenu.items[i])
      }
      for item in items {
        self.statusMenu.removeItem(item)
      }
    }
    self.monitorItems = []
  }

  func displayReconfigured() {
    self.reconfigureID += 1
    os_log("Bumping reconfigureID to %{public}@", type: .info, String(self.reconfigureID))
    if self.sleepID == 0 {
      let dispatchedReconfigureID = self.reconfigureID
      os_log("Display to be reconfigured with reconfigureID %{public}@", type: .info, String(dispatchedReconfigureID))
      DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
        self.configuration(dispatchedReconfigureID: dispatchedReconfigureID)
      }
    }
  }

  func configuration(dispatchedReconfigureID: Int = 0, firstrun: Bool = false) {
    guard self.sleepID == 0, dispatchedReconfigureID == self.reconfigureID else {
      return
    }
    os_log("Request for configuration with reconfigreID %{public}@", type: .info, String(dispatchedReconfigureID))
    self.reconfigureID = 0
    DisplayManager.shared.updateDisplays()
    DisplayManager.shared.addDisplayCounterSuffixes()
    DisplayManager.shared.updateArm64AVServices()
    NotificationCenter.default.post(name: Notification.Name(PrefKey.displayListUpdate.rawValue), object: nil)
    if firstrun {
      DisplayManager.shared.resetSwBrightnessForAllDisplays(settingsOnly: true)
    }
    self.updateDisplaysAndMenus()
    if !firstrun {
      if prefs.bool(forKey: PrefKey.fallbackSw.rawValue) || prefs.bool(forKey: PrefKey.lowerSwAfterBrightness.rawValue) {
        DisplayManager.shared.restoreSwBrightnessForAllDisplays(async: true)
      }
    }
    self.refreshBrightnessJob(start: true)
  }

  func updateDisplaysAndMenus() {
    self.clearMenu()
    var displays: [Display] = []
    if !prefs.bool(forKey: PrefKey.hideAppleFromMenu.rawValue) {
      displays.append(contentsOf: DisplayManager.shared.getAppleDisplays())
    }
    if prefs.bool(forKey: PrefKey.fallbackSw.rawValue) {
      displays.append(contentsOf: DisplayManager.shared.getNonVirtualExternalDisplays())
    } else {
      displays.append(contentsOf: DisplayManager.shared.getDdcCapableDisplays())
    }
    if displays.count != 0 {
      let asSubmenu: Bool = displays.count > 3 ? true : false
      for display in displays {
        os_log("Supported display found: %{public}@", type: .info, "\(display.name) (Vendor: \(display.vendorNumber ?? 0), Model: \(display.modelNumber ?? 0))")
        if asSubmenu {
          self.statusMenu.insertItem(NSMenuItem.separator(), at: 0)
        }
        self.updateDisplayAndMenu(display: display, asSubMenu: asSubmenu)
      }
    }
    self.updateMediaKeyTap()
  }

  private func updateDisplayAndMenu(display: Display, asSubMenu: Bool) {
    if !asSubMenu {
      self.statusMenu.insertItem(NSMenuItem.separator(), at: 0)
    }
    let monitorSubMenu: NSMenu = asSubMenu ? NSMenu() : self.statusMenu
    var numOfTickMarks = 0
    if prefs.bool(forKey: PrefKey.showTickMarks.rawValue) {
      numOfTickMarks = 5
    }
    var hasSlider = false
    if let externalDisplay = display as? ExternalDisplay, !externalDisplay.isSw() {
      if prefs.bool(forKey: PrefKey.showVolume.rawValue) {
        let volumeSliderHandler = SliderHandler.addSliderMenuItem(toMenu: monitorSubMenu, forDisplay: externalDisplay, command: .audioSpeakerVolume, title: NSLocalizedString("Volume", comment: "Shown in menu"), numOfTickMarks: numOfTickMarks)
        externalDisplay.volumeSliderHandler = volumeSliderHandler
        hasSlider = true
      } else {
        externalDisplay.setupCurrentAndMaxValues(command: .audioSpeakerVolume) // We have to initialize speaker DDC without menu as well
      }
      if prefs.bool(forKey: PrefKey.showContrast.rawValue) {
        let contrastSliderHandler = SliderHandler.addSliderMenuItem(toMenu: monitorSubMenu, forDisplay: externalDisplay, command: .contrast, title: NSLocalizedString("Contrast", comment: "Shown in menu"), numOfTickMarks: numOfTickMarks)
        externalDisplay.contrastSliderHandler = contrastSliderHandler
        hasSlider = true
      }
    }
    if !prefs.bool(forKey: PrefKey.hideBrightness.rawValue) {
      let brightnessSliderHandler = SliderHandler.addSliderMenuItem(toMenu: monitorSubMenu, forDisplay: display, command: .brightness, title: NSLocalizedString("Brightness", comment: "Shown in menu"), numOfTickMarks: numOfTickMarks)
      display.brightnessSliderHandler = brightnessSliderHandler
      hasSlider = true
    } else if let externalDisplay = display as? ExternalDisplay, !externalDisplay.isSw() {
      externalDisplay.setupCurrentAndMaxValues(command: .brightness) // We have to initialize brightness DDC without menu as well
    }
    if hasSlider {
      let monitorMenuItem = NSMenuItem()
      if asSubMenu {
        monitorMenuItem.title = "\(display.friendlyName)"
        monitorMenuItem.submenu = monitorSubMenu
      } else {
        let attrs: [NSAttributedString.Key: Any] = [.foregroundColor: NSColor.systemGray, .font: NSFont.boldSystemFont(ofSize: 12)]
        monitorMenuItem.attributedTitle = NSAttributedString(string: "\(display.friendlyName)", attributes: attrs)
      }
      self.monitorItems.append(monitorMenuItem)
      self.statusMenu.insertItem(monitorMenuItem, at: 0)
    }
  }

  func checkPermissions() {
    let permissionsRequired: Bool = prefs.integer(forKey: PrefKey.listenFor.rawValue) != MediaKeyTapManager.ListenForKeys.none.rawValue
    if !MediaKeyTapManager.readPrivileges(prompt: false) && permissionsRequired {
      MediaKeyTapManager.acquirePrivileges()
    }
  }

  private func subscribeEventListeners() {
    NotificationCenter.default.addObserver(self, selector: #selector(self.handleListenForChanged), name: .listenFor, object: nil) // subscribe KeyTap event listeners
    NotificationCenter.default.addObserver(self, selector: #selector(self.handleFriendlyNameChanged), name: .friendlyName, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(self.handlePreferenceReset), name: .preferenceReset, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(self.audioDeviceChanged), name: Notification.Name.defaultOutputDeviceChanged, object: nil) // subscribe Audio output detector (SimplyCoreAudio)
    DistributedNotificationCenter.default.addObserver(self, selector: #selector(self.colorSyncSettingsChanged), name: NSNotification.Name(rawValue: kColorSyncDisplayDeviceProfilesNotification.takeRetainedValue() as String), object: nil) // ColorSync change
    NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(self.sleepNotification), name: NSWorkspace.screensDidSleepNotification, object: nil) // sleep and wake listeners
    NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(self.wakeNotofication), name: NSWorkspace.screensDidWakeNotification, object: nil)
    NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(self.sleepNotification), name: NSWorkspace.willSleepNotification, object: nil)
    NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(self.wakeNotofication), name: NSWorkspace.didWakeNotification, object: nil)
    _ = DistributedNotificationCenter.default().addObserver(forName: .accessibilityApi, object: nil, queue: nil) { _ in DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { self.updateMediaKeyTap() } } // listen for accessibility status changes
  }

  @objc private func sleepNotification() {
    self.sleepID += 1
    os_log("Sleeping with sleep %{public}@", type: .info, String(self.sleepID))
  }

  @objc private func wakeNotofication() {
    if self.sleepID != 0 {
      os_log("Waking up from sleep %{public}@", type: .info, String(self.sleepID))
      let dispatchedSleepID = self.sleepID
      DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) { // Some displays take time to recover...
        self.soberNow(dispatchedSleepID: dispatchedSleepID)
      }
    }
  }

  private func soberNow(dispatchedSleepID: Int) {
    if self.sleepID == dispatchedSleepID {
      os_log("Sober from sleep %{public}@", type: .info, String(self.sleepID))
      self.sleepID = 0
      if self.reconfigureID != 0 {
        let dispatchedReconfigureID = self.reconfigureID
        os_log("Display needs reconfig after sober with reconfigureID %{public}@", type: .info, String(dispatchedReconfigureID))
        self.configuration(dispatchedReconfigureID: dispatchedReconfigureID)
      } else if Arm64DDC.isArm64 {
        os_log("Displays don't need reconfig after sober but might need AVServices update", type: .info)
        DisplayManager.shared.updateArm64AVServices()
        self.refreshBrightnessJob(start: true)
      }
    }
  }

  private func refreshBrightnessJob(start: Bool = false) {
    guard !(self.brightnessJobRunning && start) else {
      return
    }
    if self.sleepID == 0, self.reconfigureID == 0 {
      if !self.brightnessJobRunning {
        os_log("Refresh brightness job started.", type: .info)
        self.brightnessJobRunning = true
      }
      var nextRefresh = 1.0
      if DisplayManager.shared.refreshDisplaysBrightness() {
        nextRefresh = 0.1
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + nextRefresh) {
        self.refreshBrightnessJob()
      }
    } else {
      // Brightness refresh job dies if there is sleep or reconfiguration.
      self.brightnessJobRunning = false
      os_log("Refresh brightness job died because of sleep or reconfiguration.", type: .info)
    }
  }

  @objc private func colorSyncSettingsChanged() {
    CGDisplayRestoreColorSyncSettings()
    self.displayReconfigured()
  }

  @objc func handleListenForChanged() {
    self.checkPermissions()
    self.updateMediaKeyTap()
  }

  @objc func handleFriendlyNameChanged() {
    self.updateDisplaysAndMenus()
  }

  @objc func handlePreferenceReset() {
    os_log("Resetting all preferences.")
    if prefs.bool(forKey: PrefKey.fallbackSw.rawValue) || prefs.bool(forKey: PrefKey.lowerSwAfterBrightness.rawValue) {
      DisplayManager.shared.resetSwBrightnessForAllDisplays()
    }
    if let bundleID = Bundle.main.bundleIdentifier {
      UserDefaults.standard.removePersistentDomain(forName: bundleID)
    }
    app.statusItem.isVisible = true
    self.setDefaultPrefs()
    self.checkPermissions()
    self.updateMediaKeyTap()
    self.configuration(firstrun: true)
  }

  @objc func audioDeviceChanged() {
    #if DEBUG
      if let defaultDevice = self.coreAudio.defaultOutputDevice {
        os_log("Default output device changed to “%{public}@”.", type: .info, defaultDevice.name)
        os_log("Can device set its own volume? %{public}@", type: .info, defaultDevice.canSetVirtualMasterVolume(scope: .output).description)
      }
    #endif
    self.updateMediaKeyTap()
  }

  func updateMediaKeyTap() {
    self.mediaKeyTap.updateMediaKeyTap()
  }

  func setStartAtLogin(enabled: Bool) {
    let identifier = "\(Bundle.main.bundleIdentifier!)Helper" as CFString
    SMLoginItemSetEnabled(identifier, enabled)
  }

  func getSystemPreferences() -> [String: AnyObject]? {
    var propertyListFormat = PropertyListSerialization.PropertyListFormat.xml
    let plistPath = NSString(string: "~/Library/Preferences/.GlobalPreferences.plist").expandingTildeInPath
    guard let plistXML = FileManager.default.contents(atPath: plistPath) else {
      return nil
    }
    do {
      return try PropertyListSerialization.propertyList(from: plistXML, options: .mutableContainersAndLeaves, format: &propertyListFormat) as? [String: AnyObject]
    } catch {
      os_log("Error reading system prefs plist: %{public}@", type: .info, error.localizedDescription)
      return nil
    }
  }
}
