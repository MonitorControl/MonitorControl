//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Cocoa
import Foundation
import MediaKeyTap
import os.log
import Preferences
import ServiceManagement
import SimplyCoreAudio

let DEBUG_SW = false
let DEBUG_VIRTUAL = false
let DEBUG_MACOS10 = false

let prefs = UserDefaults.standard
let storyboard = NSStoryboard(name: "Main", bundle: Bundle.main)
let mainPrefsVc = storyboard.instantiateController(withIdentifier: "MainPrefsVC") as? MainPrefsViewController
let displaysPrefsVc = storyboard.instantiateController(withIdentifier: "DisplaysPrefsVC") as? DisplaysPrefsViewController
let menuslidersPrefsVc = storyboard.instantiateController(withIdentifier: "MenuslidersPrefsVC") as? MenuslidersPrefsViewController
let keyboardPrefsVc = storyboard.instantiateController(withIdentifier: "KeyboardPrefsVC") as? KeyboardPrefsViewController
let aboutPrefsVc = storyboard.instantiateController(withIdentifier: "AboutPrefsVC") as? AboutPrefsViewController

var app: MonitorControl!

autoreleasepool { () -> Void in
  let mc = NSApplication.shared
  let mcDelegate = MonitorControl()
  mc.delegate = mcDelegate
  mc.run()
}

class MonitorControl: NSObject, NSApplicationDelegate {
  var statusMenu: NSMenu!
  let minPreviousBuildNumber = 3600 // Below this previous app version there is a mandatory preferences reset!
  let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
  var mediaKeyTap = MediaKeyTapManager()
  var monitorItems: [NSMenuItem] = []
  let coreAudio = SimplyCoreAudio()
  var accessibilityObserver: NSObjectProtocol!
  var reconfigureID: Int = 0 // dispatched reconfigure command ID
  var sleepID: Int = 0 // Don't reconfigure display as the system or display is sleeping or wake just recently.
  var safeMode = false // Safe mode engaged during startup?
  var brightnessJobRunning = false // Is brightness job active?
  var lastMenuRelevantDisplayId: CGDirectDisplayID = 0
  let ddcQueue = DispatchQueue(label: "DDC queue")
  var combinedBrightnessSliderHandler: SliderHandler?
  var combinedVolumeSliderHandler: SliderHandler?
  var combinedContrastSliderHandler: SliderHandler?
  var isBootstrapped: Bool = false

  var preferencePaneStyle: Preferences.Style {
    if !DEBUG_MACOS10, #available(macOS 11.0, *) {
      return Preferences.Style.toolbarItems
    } else {
      return Preferences.Style.segmentedControl
    }
  }

  lazy var preferencesWindowController: PreferencesWindowController = {
    PreferencesWindowController(
      preferencePanes: [
        mainPrefsVc!,
        menuslidersPrefsVc!,
        keyboardPrefsVc!,
        displaysPrefsVc!,
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
      let alert = NSAlert()
      alert.messageText = NSLocalizedString("Safe Mode Activated", comment: "Shown in the alert dialog")
      alert.informativeText = NSLocalizedString("Shift was pressed during launch. MonitorControl started in safe mode. Default preferences are reloaded, DDC read is blocked.", comment: "Shown in the alert dialog")
      alert.runModal()
    }
    let currentBuildNumber = Int(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1") ?? 1
    let previousBuildNumber: Int = (Int(prefs.string(forKey: PrefKey.buildNumber.rawValue) ?? "0") ?? 0)
    if self.safeMode || ((previousBuildNumber < self.minPreviousBuildNumber) && previousBuildNumber > 0) || (previousBuildNumber > currentBuildNumber), let bundleID = Bundle.main.bundleIdentifier {
      let alert = NSAlert()
      alert.messageText = NSLocalizedString("Incompatible previous version", comment: "Shown in the alert dialog")
      alert.informativeText = NSLocalizedString("Preferences for an incompatible previous app version detected. Default preferences are reloaded.", comment: "Shown in the alert dialog")
      alert.runModal()
      prefs.removePersistentDomain(forName: bundleID)
    }
    prefs.set(currentBuildNumber, forKey: PrefKey.buildNumber.rawValue)
    self.setDefaultPrefs()
    self.statusMenu = NSMenu()
    if !DEBUG_MACOS10, #available(macOS 11.0, *) {
      self.statusItem.button?.image = NSImage(systemSymbolName: "sun.max", accessibilityDescription: "MonitorControl")
    } else {
      self.statusItem.button?.image = NSImage(named: "status")
    }
    self.statusItem.isVisible = (prefs.string(forKey: PrefKey.menuIcon.rawValue) ?? "") == "" ? true : false
    self.statusItem.menu = self.statusMenu
    self.checkPermissions()
    CGDisplayRegisterReconfigurationCallback({ _, _, _ in app.displayReconfigured() }, nil)
    self.configure(firstrun: true)
    DisplayManager.shared.createGammaActivityEnforcer()
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

  @objc func quitClicked(_: AnyObject) {
    NSApplication.shared.terminate(self)
  }

  @objc func prefsClicked(_: AnyObject) {
    self.preferencesWindowController.show()
  }

  func setDefaultPrefs() {
    if !prefs.bool(forKey: PrefKey.appAlreadyLaunched.rawValue) {
      // Only preferences that are not false, 0 or "" by default are set here. Assumes pre-wiped database.
      prefs.set(true, forKey: PrefKey.appAlreadyLaunched.rawValue)
    }
  }

  func displayReconfigured() {
    self.reconfigureID += 1
    os_log("Bumping reconfigureID to %{public}@", type: .info, String(self.reconfigureID))
    if self.sleepID == 0 {
      let dispatchedReconfigureID = self.reconfigureID
      os_log("Display to be reconfigured with reconfigureID %{public}@", type: .info, String(dispatchedReconfigureID))
      DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
        self.configure(dispatchedReconfigureID: dispatchedReconfigureID)
      }
    }
  }

  func configure(dispatchedReconfigureID: Int = 0, firstrun: Bool = false) {
    guard self.sleepID == 0, dispatchedReconfigureID == self.reconfigureID else {
      return
    }
    os_log("Request for configuration with reconfigreID %{public}@", type: .info, String(dispatchedReconfigureID))
    self.reconfigureID = 0
    DisplayManager.shared.configureDisplays()
    DisplayManager.shared.addDisplayCounterSuffixes()
    DisplayManager.shared.updateArm64AVServices()
    if firstrun {
      DisplayManager.shared.resetSwBrightnessForAllDisplays(settingsOnly: true)
    }
    DisplayManager.shared.setupOtherDisplays(firstrun: firstrun)
    self.updateMenusAndKeys()
    if !firstrun {
      if !prefs.bool(forKey: PrefKey.disableSoftwareFallback.rawValue) || !prefs.bool(forKey: PrefKey.disableCombinedBrightness.rawValue) {
        DisplayManager.shared.restoreSwBrightnessForAllDisplays(async: !prefs.bool(forKey: PrefKey.disableSmoothBrightness.rawValue))
      }
    }
    self.refreshBrightnessJob(start: true)
  }

  func updateMenusAndKeys() {
    self.updateMenus()
    self.updateMediaKeyTap()
  }

  func updateMenuRelevantDisplay() {
    if prefs.bool(forKey: PrefKey.slidersRelevant.rawValue) {
      if let display = DisplayManager.shared.getCurrentDisplay(), display.identifier != self.lastMenuRelevantDisplayId {
        os_log("Menu must be refreshed as relevant display changed since last time.")
        self.lastMenuRelevantDisplayId = display.identifier
        self.updateMenus()
      }
    }
  }

  func clearMenu() {
    var items: [NSMenuItem] = []
    for i in 0 ..< self.statusMenu.items.count {
      items.append(self.statusMenu.items[i])
    }
    for item in items {
      self.statusMenu.removeItem(item)
    }
    self.statusMenu.addItem(withTitle: NSLocalizedString("Preferences", comment: "Shown in menu"), action: #selector(self.prefsClicked), keyEquivalent: "")
    self.statusMenu.addItem(withTitle: NSLocalizedString("Quit", comment: "Shown in menu"), action: #selector(self.quitClicked), keyEquivalent: "")
    self.monitorItems = []
    self.combinedBrightnessSliderHandler = nil
    self.combinedVolumeSliderHandler = nil
    self.combinedContrastSliderHandler = nil
  }

  func updateMenus() {
    self.clearMenu()
    let currentDisplay = DisplayManager.shared.getCurrentDisplay()
    var displays: [Display] = []
    if !prefs.bool(forKey: PrefKey.hideAppleFromMenu.rawValue) {
      displays.append(contentsOf: DisplayManager.shared.getAppleDisplays())
    }
    if !prefs.bool(forKey: PrefKey.disableSoftwareFallback.rawValue) {
      displays.append(contentsOf: DisplayManager.shared.getOtherDisplays())
    } else {
      displays.append(contentsOf: DisplayManager.shared.getDdcCapableDisplays())
    }
    let relevant = prefs.bool(forKey: PrefKey.slidersRelevant.rawValue)
    let combine = prefs.bool(forKey: PrefKey.slidersCombine.rawValue)
    let numOfDisplays = displays.count
    if numOfDisplays != 0 {
      if relevant || combine {
        self.statusMenu.insertItem(NSMenuItem.separator(), at: 0)
      }
      let asSubMenu: Bool = (displays.count > 3 && relevant && !combine) ? true : false
      for display in displays where !relevant || display == currentDisplay {
        self.updateDisplayMenu(display: display, asSubMenu: asSubMenu, numOfDisplays: numOfDisplays)
      }
    }
  }

  private func updateDisplayMenu(display: Display, asSubMenu: Bool, numOfDisplays: Int) {
    let relevant = prefs.bool(forKey: PrefKey.slidersRelevant.rawValue)
    let combine = prefs.bool(forKey: PrefKey.slidersCombine.rawValue)
    os_log("Addig menu item for display %{public}@", type: .info, "\(display.identifier)")
    if !relevant, !combine {
      self.statusMenu.insertItem(NSMenuItem.separator(), at: 0)
    }
    let monitorSubMenu: NSMenu = asSubMenu ? NSMenu() : self.statusMenu
    let numOfTickMarks = prefs.bool(forKey: PrefKey.showTickMarks.rawValue) ? 5 : 0
    var hasSlider = false
    display.brightnessSliderHandler = nil
    if let otherDisplay = display as? OtherDisplay, !otherDisplay.isSw() {
      otherDisplay.contrastSliderHandler = nil
      otherDisplay.volumeSliderHandler = nil
      if !display.readPrefValueKeyBool(forkey: PrefKey.unavailableDDC, for: .audioSpeakerVolume), !prefs.bool(forKey: PrefKey.hideVolume.rawValue) {
        let position = (combine && self.combinedBrightnessSliderHandler != nil) ? (self.combinedContrastSliderHandler != nil ? 2 : 1) : 0
        let volumeSliderHandler = SliderHandler.addSliderMenuItem(toMenu: monitorSubMenu, forDisplay: otherDisplay, command: .audioSpeakerVolume, title: NSLocalizedString("Volume", comment: "Shown in menu"), numOfTickMarks: numOfTickMarks, sliderHandler: combine ? self.combinedVolumeSliderHandler : nil, position: position)
        self.combinedVolumeSliderHandler = combine ? volumeSliderHandler : nil
        otherDisplay.volumeSliderHandler = volumeSliderHandler
        hasSlider = true
      }
      if prefs.bool(forKey: PrefKey.showContrast.rawValue), !display.readPrefValueKeyBool(forkey: PrefKey.unavailableDDC, for: .contrast) {
        let position = (combine && self.combinedBrightnessSliderHandler != nil) ? 1 : 0
        let contrastSliderHandler = SliderHandler.addSliderMenuItem(toMenu: monitorSubMenu, forDisplay: otherDisplay, command: .contrast, title: NSLocalizedString("Contrast", comment: "Shown in menu"), numOfTickMarks: numOfTickMarks, sliderHandler: combine ? self.combinedContrastSliderHandler : nil, position: position)
        self.combinedContrastSliderHandler = combine ? contrastSliderHandler : nil
        otherDisplay.contrastSliderHandler = contrastSliderHandler
        hasSlider = true
      }
    }
    if !prefs.bool(forKey: PrefKey.hideBrightness.rawValue), !display.readPrefValueKeyBool(forkey: PrefKey.unavailableDDC, for: .brightness) {
      let brightnessSliderHandler = SliderHandler.addSliderMenuItem(toMenu: monitorSubMenu, forDisplay: display, command: .brightness, title: NSLocalizedString("Brightness", comment: "Shown in menu"), numOfTickMarks: numOfTickMarks, sliderHandler: combine ? self.combinedBrightnessSliderHandler : nil)
      display.brightnessSliderHandler = brightnessSliderHandler
      self.combinedBrightnessSliderHandler = combine ? brightnessSliderHandler : nil
      hasSlider = true
    }
    if hasSlider, !relevant, !combine, numOfDisplays > 1 {
      self.appendMenuHeader(friendlyName: display.friendlyName, monitorSubMenu: monitorSubMenu, asSubMenu: asSubMenu)
    }
    if prefs.string(forKey: PrefKey.menuIcon.rawValue) == "sliderOnly" {
      app.statusItem.isVisible = hasSlider
    }
  }

  private func appendMenuHeader(friendlyName: String, monitorSubMenu: NSMenu, asSubMenu: Bool) {
    let monitorMenuItem = NSMenuItem()
    if asSubMenu {
      monitorMenuItem.title = "\(friendlyName)"
      monitorMenuItem.submenu = monitorSubMenu
    } else {
      let attrs: [NSAttributedString.Key: Any] = [.foregroundColor: NSColor.systemGray, .font: NSFont.boldSystemFont(ofSize: 12)]
      monitorMenuItem.attributedTitle = NSAttributedString(string: "\(friendlyName)", attributes: attrs)
    }
    self.monitorItems.append(monitorMenuItem)
    self.statusMenu.insertItem(monitorMenuItem, at: 0)
  }

  func checkPermissions() {
    let permissionsRequired: Bool = !prefs.bool(forKey: PrefKey.disableListenForVolume.rawValue) || !prefs.bool(forKey: PrefKey.disableListenForBrightness.rawValue)
    if !MediaKeyTapManager.readPrivileges(prompt: false) && permissionsRequired {
      MediaKeyTapManager.acquirePrivileges()
    }
  }

  private func subscribeEventListeners() {
    NotificationCenter.default.addObserver(self, selector: #selector(self.audioDeviceChanged), name: Notification.Name.defaultOutputDeviceChanged, object: nil) // subscribe Audio output detector (SimplyCoreAudio)
    DistributedNotificationCenter.default.addObserver(self, selector: #selector(self.colorSyncSettingsChanged), name: NSNotification.Name(rawValue: kColorSyncDisplayDeviceProfilesNotification.takeRetainedValue() as String), object: nil) // ColorSync change
    NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(self.sleepNotification), name: NSWorkspace.screensDidSleepNotification, object: nil) // sleep and wake listeners
    NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(self.wakeNotofication), name: NSWorkspace.screensDidWakeNotification, object: nil)
    NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(self.sleepNotification), name: NSWorkspace.willSleepNotification, object: nil)
    NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(self.wakeNotofication), name: NSWorkspace.didWakeNotification, object: nil)
    _ = DistributedNotificationCenter.default().addObserver(forName: .accessibilityApi, object: nil, queue: nil) { _ in DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { self.updateMediaKeyTap() } } // listen for accessibility status changes
    NotificationCenter.default.addObserver(forName: NSWindow.didChangeOcclusionStateNotification, object: self.statusItem.button?.menu, queue: nil) { _ in self.updateMenuRelevantDisplay() }
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
        self.configure(dispatchedReconfigureID: dispatchedReconfigureID)
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
        os_log("Refresh brightness job started.", type: .debug)
        self.brightnessJobRunning = true
      }
      var refreshedSomething = false
      for display in DisplayManager.shared.displays {
        let delta = display.refreshBrightness()
        if delta != 0 {
          refreshedSomething = true
          if prefs.bool(forKey: PrefKey.enableBrightnessSync.rawValue) {
            for targetDisplay in DisplayManager.shared.displays where targetDisplay != display {
              os_log("Updating delta from display %{public}@ to display %{public}@", type: .debug, String(display.identifier), String(targetDisplay.identifier))
              let newValue = max(0, min(1, targetDisplay.getBrightness() + delta))
              _ = targetDisplay.setBrightness(newValue)
              if let slider = targetDisplay.brightnessSliderHandler {
                slider.setValue(newValue, displayID: targetDisplay.identifier)
              }
            }
          }
        }
      }
      let nextRefresh = refreshedSomething ? 0.1 : 1.0
      DispatchQueue.main.asyncAfter(deadline: .now() + nextRefresh) {
        self.refreshBrightnessJob()
      }
    } else {
      self.brightnessJobRunning = false
      os_log("Refresh brightness job died because of sleep or reconfiguration.", type: .info)
    }
  }

  @objc private func colorSyncSettingsChanged() {
    CGDisplayRestoreColorSyncSettings()
    self.displayReconfigured()
  }

  func handleListenForChanged() {
    self.checkPermissions()
    self.updateMediaKeyTap()
  }

  func preferenceReset() {
    os_log("Resetting all preferences.")
    if !prefs.bool(forKey: PrefKey.disableSoftwareFallback.rawValue) || !prefs.bool(forKey: PrefKey.disableCombinedBrightness.rawValue) {
      DisplayManager.shared.resetSwBrightnessForAllDisplays(async: false)
    }
    if let bundleID = Bundle.main.bundleIdentifier {
      prefs.removePersistentDomain(forName: bundleID)
    }
    app.statusItem.isVisible = true
    self.setDefaultPrefs()
    self.checkPermissions()
    self.updateMediaKeyTap()
    self.configure(firstrun: true)
  }

  @objc func audioDeviceChanged() {
    if let defaultDevice = self.coreAudio.defaultOutputDevice {
      os_log("Default output device changed to “%{public}@”.", type: .debug, defaultDevice.name)
      os_log("Can device set its own volume? %{public}@", type: .debug, defaultDevice.canSetVirtualMasterVolume(scope: .output).description)
    }
    self.updateMediaKeyTap()
  }

  func updateMediaKeyTap() {
    MediaKeyTap.useAlternateBrightnessKeys = !prefs.bool(forKey: PrefKey.disableAltBrightnessKeys.rawValue)
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
