//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Cocoa
import Foundation
import MediaKeyTap
import os.log
import Preferences
import ServiceManagement
import SimplyCoreAudio

class MonitorControl: NSObject, NSApplicationDelegate {
  let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
  var mediaKeyTap = MediaKeyTapManager()
  let coreAudio = SimplyCoreAudio()
  var accessibilityObserver: NSObjectProtocol!
  var reconfigureID: Int = 0 // dispatched reconfigure command ID
  var sleepID: Int = 0 // sleep event ID
  var safeMode = false
  var jobRunning = false

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
    menu = MenuHandler()
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
    if self.safeMode || ((previousBuildNumber < MIN_PREVIOUS_BUILD_NUMBER) && previousBuildNumber > 0) || (previousBuildNumber > currentBuildNumber), let bundleID = Bundle.main.bundleIdentifier {
      let alert = NSAlert()
      alert.messageText = NSLocalizedString("Incompatible previous version", comment: "Shown in the alert dialog")
      alert.informativeText = NSLocalizedString("Preferences for an incompatible previous app version detected. Default preferences are reloaded.", comment: "Shown in the alert dialog")
      alert.runModal()
      prefs.removePersistentDomain(forName: bundleID)
    }
    prefs.set(currentBuildNumber, forKey: PrefKey.buildNumber.rawValue)
    self.setDefaultPrefs()
    if !DEBUG_MACOS10, #available(macOS 11.0, *) {
      self.statusItem.button?.image = NSImage(systemSymbolName: "sun.max", accessibilityDescription: "MonitorControl")
    } else {
      self.statusItem.button?.image = NSImage(named: "status")
    }
    self.statusItem.isVisible = (prefs.string(forKey: PrefKey.menuIcon.rawValue) ?? "") == "" ? true : false
    self.statusItem.menu = menu
    self.checkPermissions()
    CGDisplayRegisterReconfigurationCallback({ _, _, _ in app.displayReconfigured() }, nil)
    self.configure(firstrun: true)
    DisplayManager.shared.createGammaActivityEnforcer()
  }

  @objc func quitClicked(_: AnyObject) {
    os_log("Quit clicked", type: .debug)
    NSApplication.shared.terminate(self)
  }

  @objc func prefsClicked(_: AnyObject) {
    os_log("Preferences clicked", type: .debug)
    self.preferencesWindowController.show()
  }

  func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows _: Bool) -> Bool {
    app.prefsClicked(self)
    return true
  }

  func applicationWillTerminate(_: Notification) {
    os_log("Goodbye!", type: .info)
    DisplayManager.shared.resetSwBrightnessForAllDisplays()
    self.statusItem.isVisible = true
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
    self.job(start: true)
  }

  func updateMenusAndKeys() {
    menu.updateMenus()
    self.updateMediaKeyTap()
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
    NotificationCenter.default.addObserver(forName: NSWindow.didChangeOcclusionStateNotification, object: self.statusItem.button?.menu, queue: nil) { _ in menu.updateMenuRelevantDisplay() }
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
        self.job(start: true)
      }
    }
  }

  private func job(start: Bool = false) {
    guard !(self.jobRunning && start) else {
      return
    }
    if self.sleepID == 0, self.reconfigureID == 0 {
      if !self.jobRunning {
        os_log("MonitorControl job started.", type: .debug)
        self.jobRunning = true
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
        self.job()
      }
    } else {
      self.jobRunning = false
      os_log("MonitorControl job died because of sleep or reconfiguration.", type: .info)
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
