import Cocoa
import Foundation
import MediaKeyTap
import os.log
import Preferences
import SimplyCoreAudio

var app: AppDelegate!
let prefs = UserDefaults.standard

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
  @IBOutlet var statusMenu: NSMenu!
  let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
  var monitorItems: [NSMenuItem] = []
  var mediaKeyTap: MediaKeyTap?
  var keyRepeatTimers: [MediaKey: Timer] = [:]
  let coreAudio = SimplyCoreAudio()
  var accessibilityObserver: NSObjectProtocol!
  var reconfigureID: Int = 0 // dispatched reconfigure command ID
  var sleepID: Int = 0 // Don't reconfigure display as the system or display is sleeping or wake just recently.
  var safeMode = false // Safe mode engaged during startup?
  let debugSw: Bool = false
  lazy var preferencesWindowController: PreferencesWindowController = {
    let storyboard = NSStoryboard(name: "Main", bundle: Bundle.main)
    let mainPrefsVc = storyboard.instantiateController(withIdentifier: "MainPrefsVC") as? MainPrefsViewController
    let displaysPrefsVc = storyboard.instantiateController(withIdentifier: "DisplaysPrefsVC") as? DisplaysPrefsViewController
    let aboutPrefsVc = storyboard.instantiateController(withIdentifier: "AboutPrefsVC") as? AboutPrefsViewController
    return PreferencesWindowController(
      preferencePanes: [
        mainPrefsVc!,
        displaysPrefsVc!,
        aboutPrefsVc!,
      ],
      animated: true
    )
  }()

  func applicationDidFinishLaunching(_: Notification) {
    app = self
    self.subscribeEventListeners()
    if NSEvent.modifierFlags.contains(NSEvent.ModifierFlags.shift) {
      self.safeMode = true
      self.handlePreferenceReset()
      Utils.alert(text: NSLocalizedString("Safe Mode Activated", comment: "Shown in the alert dialog"), info: NSLocalizedString("Shift was pressed during launch. MonitorControl started in safe mode. Default preferences are reloaded, DDC read is blocked.", comment: "Shown in the alert dialog"))
    }
    self.setDefaultPrefs()
    if #available(macOS 11.0, *) {
      self.statusItem.button?.image = NSImage(systemSymbolName: "sun.max", accessibilityDescription: "MonitorControl")
    } else {
      self.statusItem.button?.image = NSImage(named: "status")
    }
    self.statusItem.isVisible = prefs.bool(forKey: Utils.PrefKeys.hideMenuIcon.rawValue) ? false : true
    self.statusItem.menu = self.statusMenu
    self.checkPermissions()
    CGDisplayRegisterReconfigurationCallback({ _, _, _ in app.displayReconfigured() }, nil)
    self.updateDisplays(firstrun: true)
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
    if !prefs.bool(forKey: Utils.PrefKeys.appAlreadyLaunched.rawValue) {
      prefs.set(true, forKey: Utils.PrefKeys.appAlreadyLaunched.rawValue)
      prefs.set(false, forKey: Utils.PrefKeys.showContrast.rawValue)
      prefs.set(true, forKey: Utils.PrefKeys.showVolume.rawValue)
      prefs.set(false, forKey: Utils.PrefKeys.lowerSwAfterBrightness.rawValue)
      prefs.set(true, forKey: Utils.PrefKeys.fallbackSw.rawValue)
      prefs.set(false, forKey: Utils.PrefKeys.hideMenuIcon.rawValue)
      prefs.set(false, forKey: Utils.PrefKeys.showAdvancedDisplays.rawValue)
    }
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

  func updateArm64AVServices() {
    if Arm64DDC.isArm64 {
      os_log("arm64 AVService update requested", type: .info)
      var displayIDs: [CGDirectDisplayID] = []
      for externalDisplay in DisplayManager.shared.getExternalDisplays() {
        displayIDs.append(externalDisplay.identifier)
      }
      for serviceMatch in Arm64DDC.getServiceMatches(displayIDs: displayIDs) {
        for externalDisplay in DisplayManager.shared.getExternalDisplays() where externalDisplay.identifier == serviceMatch.displayID && serviceMatch.service != nil {
          externalDisplay.arm64avService = serviceMatch.service
          os_log("Display service match successful for display %{public}@", type: .info, String(serviceMatch.displayID))
          if !serviceMatch.isDiscouraged {
            externalDisplay.arm64ddc = !debugSw ? true : false // MARK: (point of interest when testing)
          }
        }
      }
      os_log("AVService update done", type: .info)
    }
  }

  func displayReconfigured() {
    self.reconfigureID += 1
    os_log("Bumping reconfigureID to %{public}@", type: .info, String(self.reconfigureID))
    if self.sleepID == 0 {
      let dispatchedReconfigureID = self.reconfigureID
      os_log("Display to be reconfigured with reconfigureID %{public}@", type: .info, String(dispatchedReconfigureID))
      DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
        self.updateDisplays(dispatchedReconfigureID: dispatchedReconfigureID)
      }
    }
  }

  func updateMenus() {
    self.clearMenu()
    var controllableExternalDisplays: [ExternalDisplay] = []
    if prefs.bool(forKey: Utils.PrefKeys.fallbackSw.rawValue) {
      controllableExternalDisplays = DisplayManager.shared.getNonVirtualExternalDisplays()
    } else {
      controllableExternalDisplays = DisplayManager.shared.getDdcCapableDisplays()
    }
    if controllableExternalDisplays.count == 0 {
      let item = NSMenuItem()
      item.title = NSLocalizedString("No supported display found", comment: "Shown in menu")
      item.isEnabled = false
      self.monitorItems.append(item)
      self.statusMenu.insertItem(item, at: 0)
      self.statusMenu.insertItem(NSMenuItem.separator(), at: 1)
    } else {
      for display in controllableExternalDisplays {
        os_log("Supported display found: %{public}@", type: .info, "\(display.name) (Vendor: \(display.vendorNumber ?? 0), Model: \(display.modelNumber ?? 0))")
        let asSubmenu: Bool = controllableExternalDisplays.count > 2 ? true : false
        if asSubmenu {
          self.statusMenu.insertItem(NSMenuItem.separator(), at: 0)
        }
        self.addDisplayToMenu(display: display, asSubMenu: asSubmenu)
      }
    }
  }

  func updateDisplays(dispatchedReconfigureID: Int = 0, firstrun: Bool = false) {
    guard self.sleepID == 0, dispatchedReconfigureID == self.reconfigureID else {
      return
    }
    os_log("Request for updateDisplay with reconfigreID %{public}@", type: .info, String(dispatchedReconfigureID))
    self.reconfigureID = 0
    DisplayManager.shared.clearDisplays()
    var onlineDisplayIDs = [CGDirectDisplayID](repeating: 0, count: 16)
    var displayCount: UInt32 = 0
    guard CGGetOnlineDisplayList(10, &onlineDisplayIDs, &displayCount) == .success else {
      os_log("Unable to get display list.", type: .info)
      return
    }
    for onlineDisplayID in onlineDisplayIDs where onlineDisplayID != 0 {
      let name = DisplayManager.shared.getDisplayNameByID(displayID: onlineDisplayID)
      let id = onlineDisplayID
      let vendorNumber = CGDisplayVendorNumber(onlineDisplayID)
      let modelNumber = CGDisplayVendorNumber(onlineDisplayID)
      let display: Display
      var isVirtual: Bool = false
      if #available(macOS 11.0, *) {
        if let dictionary = ((CoreDisplay_DisplayCreateInfoDictionary(onlineDisplayID))?.takeRetainedValue() as NSDictionary?) {
          let isVirtualDevice = dictionary["kCGDisplayIsVirtualDevice"] as? Bool
          let displayIsAirplay = dictionary["kCGDisplayIsAirPlay"] as? Bool
          if isVirtualDevice ?? displayIsAirplay ?? false {
            isVirtual = true
          }
        }
      }
      if !debugSw, CGDisplayIsBuiltin(onlineDisplayID) != 0 { // MARK: (point of interest for testing)
        display = InternalDisplay(id, name: name, vendorNumber: vendorNumber, modelNumber: modelNumber, isVirtual: isVirtual)
      } else {
        display = ExternalDisplay(id, name: name, vendorNumber: vendorNumber, modelNumber: modelNumber, isVirtual: isVirtual)
      }
      DisplayManager.shared.addDisplay(display: display)
    }
    self.updateArm64AVServices()
    if firstrun {
      DisplayManager.shared.resetSwBrightnessForAllDisplays(settingsOnly: true)
    }
    NotificationCenter.default.post(name: Notification.Name(Utils.PrefKeys.displayListUpdate.rawValue), object: nil)
    self.updateMenus()
    if !firstrun {
      if prefs.bool(forKey: Utils.PrefKeys.fallbackSw.rawValue) || prefs.bool(forKey: Utils.PrefKeys.lowerSwAfterBrightness.rawValue) {
        DisplayManager.shared.restoreSwBrightnessForAllDisplays(async: true)
      }
    }
    updateMediaKeyTap()
  }

  private func addDisplayToMenu(display: ExternalDisplay, asSubMenu: Bool) {
    if !asSubMenu {
      self.statusMenu.insertItem(NSMenuItem.separator(), at: 0)
    }
    let monitorSubMenu: NSMenu = asSubMenu ? NSMenu() : self.statusMenu

    if !display.isSw() {
      if prefs.bool(forKey: Utils.PrefKeys.showVolume.rawValue) {
        let volumeSliderHandler = SliderHandler.addSliderMenuItem(toMenu: monitorSubMenu, forDisplay: display, command: .audioSpeakerVolume, title: NSLocalizedString("Volume", comment: "Shown in menu"))
        display.volumeSliderHandler = volumeSliderHandler
      }
      if prefs.bool(forKey: Utils.PrefKeys.showContrast.rawValue) {
        let contrastSliderHandler = SliderHandler.addSliderMenuItem(toMenu: monitorSubMenu, forDisplay: display, command: .contrast, title: NSLocalizedString("Contrast", comment: "Shown in menu"))
        display.contrastSliderHandler = contrastSliderHandler
      }
    }
    var numOfTickMarks = 0
    if !display.isSw(), prefs.bool(forKey: Utils.PrefKeys.lowerSwAfterBrightness.rawValue) {
      numOfTickMarks = 0 // 1 - I  disabled this because tickmarks are buggy in dark mode on Monterey (probably Big Sur as well).
    }
    let brightnessSliderHandler = SliderHandler.addSliderMenuItem(toMenu: monitorSubMenu, forDisplay: display, command: .brightness, title: NSLocalizedString("Brightness", comment: "Shown in menu"), numOfTickMarks: numOfTickMarks)
    display.brightnessSliderHandler = brightnessSliderHandler

    let monitorMenuItem = NSMenuItem()
    if asSubMenu {
      monitorMenuItem.title = "\(display.getFriendlyName())"
      monitorMenuItem.submenu = monitorSubMenu
    } else {
      let attrs: [NSAttributedString.Key: Any] = [.foregroundColor: NSColor.systemGray, .font: NSFont.boldSystemFont(ofSize: 12)]
      monitorMenuItem.attributedTitle = NSAttributedString(string: "\(display.getFriendlyName())", attributes: attrs)
    }

    self.monitorItems.append(monitorMenuItem)
    self.statusMenu.insertItem(monitorMenuItem, at: 0)
  }

  private func checkPermissions() {
    let permissionsRequired: Bool = prefs.integer(forKey: Utils.PrefKeys.listenFor.rawValue) != Utils.ListenForKeys.none.rawValue
    if !Utils.readPrivileges(prompt: false) && permissionsRequired {
      Utils.acquirePrivileges()
    }
  }

  private func subscribeEventListeners() {
    NotificationCenter.default.addObserver(self, selector: #selector(handleListenForChanged), name: .listenFor, object: nil) // subscribe KeyTap event listeners
    NotificationCenter.default.addObserver(self, selector: #selector(handleFriendlyNameChanged), name: .friendlyName, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(handlePreferenceReset), name: .preferenceReset, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(audioDeviceChanged), name: Notification.Name.defaultOutputDeviceChanged, object: nil) // subscribe Audio output detector (SimplyCoreAudio)
    DistributedNotificationCenter.default.addObserver(self, selector: #selector(colorSyncSettingsChanged), name: NSNotification.Name(rawValue: kColorSyncDisplayDeviceProfilesNotification.takeRetainedValue() as String), object: nil) // ColorSync change
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
        self.updateDisplays(dispatchedReconfigureID: dispatchedReconfigureID)
      } else if Arm64DDC.isArm64 {
        os_log("Displays don't need reconfig after sober but might need AVServices update", type: .info)
        self.updateArm64AVServices()
      }
    }
  }

  private func oppositeMediaKey(mediaKey: MediaKey) -> MediaKey? {
    if mediaKey == .brightnessUp {
      return .brightnessDown
    } else if mediaKey == .brightnessDown {
      return .brightnessUp
    } else if mediaKey == .volumeUp {
      return .volumeDown
    } else if mediaKey == .volumeDown {
      return .volumeUp
    }
    return nil
  }

  func handleOpenPrefPane(mediaKey: MediaKey, event: KeyEvent?, modifiers: NSEvent.ModifierFlags?) -> Bool {
    guard let modifiers = modifiers else { return false }
    if !(modifiers.contains(.option) && !modifiers.contains(.shift)) {
      return false
    }
    if event?.keyRepeat == true {
      return false
    }
    switch mediaKey {
    case .brightnessUp, .brightnessDown:
      NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/PreferencePanes/Displays.prefPane"))
    case .mute, .volumeUp, .volumeDown:
      NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/PreferencePanes/Sound.prefPane"))
    default:
      return false
    }
    return true
  }
}

extension AppDelegate: MediaKeyTapDelegate {
  func handle(mediaKey: MediaKey, event: KeyEvent?, modifiers: NSEvent.ModifierFlags?) {
    guard self.sleepID == 0, self.reconfigureID == 0 else {
      if [.brightnessUp, .brightnessDown].contains(mediaKey) {
        OSDUtils.showOSDLockOnAllDisplays(osdImage: 1)
      }
      if [.volumeUp, .volumeDown, .mute].contains(mediaKey) {
        OSDUtils.showOSDLockOnAllDisplays(osdImage: 3)
      }
      return
    }
    let isPressed = event?.keyPressed ?? true
    let isRepeat = event?.keyRepeat ?? false
    if isPressed, self.handleOpenPrefPane(mediaKey: mediaKey, event: event, modifiers: modifiers) {
      return
    }
    let isSmallIncrement = modifiers?.isSuperset(of: NSEvent.ModifierFlags([.shift, .option])) ?? false
    // control internal display when holding ctrl modifier
    let isControlModifier = modifiers?.isSuperset(of: NSEvent.ModifierFlags([.control])) ?? false
    if isControlModifier, mediaKey == .brightnessUp || mediaKey == .brightnessDown {
      if isPressed, let internalDisplay = DisplayManager.shared.getBuiltInDisplay() as? InternalDisplay {
        internalDisplay.stepBrightness(isUp: mediaKey == .brightnessUp, isSmallIncrement: isSmallIncrement)
        return
      }
    }
    let oppositeKey: MediaKey? = self.oppositeMediaKey(mediaKey: mediaKey)
    // If the opposite key to the one being held has an active timer, cancel it - we'll be going in the opposite direction
    if let oppositeKey = oppositeKey, let oppositeKeyTimer = self.keyRepeatTimers[oppositeKey], oppositeKeyTimer.isValid {
      oppositeKeyTimer.invalidate()
    } else if let mediaKeyTimer = self.keyRepeatTimers[mediaKey], mediaKeyTimer.isValid {
      // If there's already an active timer for the key being held down, let it run rather than executing it again
      if isRepeat {
        return
      }
      mediaKeyTimer.invalidate()
    }
    self.sendDisplayCommand(mediaKey: mediaKey, isRepeat: isRepeat, isSmallIncrement: isSmallIncrement, isPressed: isPressed)
  }

  private func sendDisplayCommand(mediaKey: MediaKey, isRepeat: Bool, isSmallIncrement: Bool, isPressed: Bool) {
    guard self.sleepID == 0, self.reconfigureID == 0, let affectedDisplays = DisplayManager.shared.getAffectedDisplays() else {
      return
    }
    var wasNotIsPressedVolumeSentAlready = false
    for display in affectedDisplays where display.isEnabled && !display.isVirtual {
      switch mediaKey {
      case .brightnessUp:
        var isAnyDisplayInSwAfterBrightnessMode: Bool = false
        for display in affectedDisplays where ((display as? ExternalDisplay)?.isSwBrightnessNotDefault() ?? false) && !((display as? ExternalDisplay)?.isSw() ?? false) {
          isAnyDisplayInSwAfterBrightnessMode = true
        }
        if isPressed, !(isAnyDisplayInSwAfterBrightnessMode && !(((display as? ExternalDisplay)?.isSwBrightnessNotDefault() ?? false) && !((display as? ExternalDisplay)?.isSw() ?? false))) {
          display.stepBrightness(isUp: mediaKey == .brightnessUp, isSmallIncrement: isSmallIncrement)
        }
      case .brightnessDown:
        if isPressed {
          display.stepBrightness(isUp: mediaKey == .brightnessUp, isSmallIncrement: isSmallIncrement)
        }
      case .mute:
        // The mute key should not respond to press + hold or keyup
        if !isRepeat, isPressed {
          // mute only matters for external displays
          if let display = display as? ExternalDisplay {
            display.toggleMute()
          }
        }
      case .volumeUp, .volumeDown:
        // volume only matters for external displays
        if let display = display as? ExternalDisplay {
          if isPressed || !wasNotIsPressedVolumeSentAlready {
            display.stepVolume(isUp: mediaKey == .volumeUp, isSmallIncrement: isSmallIncrement, isPressed: isPressed)
          }
          wasNotIsPressedVolumeSentAlready = true
        }
      default:
        return
      }
    }
  }

  @objc func handleListenForChanged() {
    self.checkPermissions()
    self.updateMediaKeyTap()
  }

  @objc func handleFriendlyNameChanged() {
    self.updateMenus()
  }

  @objc func handlePreferenceReset() {
    os_log("Resetting all preferences.")
    if prefs.bool(forKey: Utils.PrefKeys.fallbackSw.rawValue) || prefs.bool(forKey: Utils.PrefKeys.lowerSwAfterBrightness.rawValue) {
      DisplayManager.shared.resetSwBrightnessForAllDisplays()
    }
    if let bundleID = Bundle.main.bundleIdentifier {
      UserDefaults.standard.removePersistentDomain(forName: bundleID)
    }
    app.statusItem.isVisible = true
    self.setDefaultPrefs()
    self.checkPermissions()
    self.updateMediaKeyTap()
    self.updateDisplays(firstrun: true)
  }

  private func updateMediaKeyTap() {
    var keys: [MediaKey]
    switch prefs.integer(forKey: Utils.PrefKeys.listenFor.rawValue) {
    case Utils.ListenForKeys.brightnessOnlyKeys.rawValue:
      keys = [.brightnessUp, .brightnessDown]
    case Utils.ListenForKeys.volumeOnlyKeys.rawValue:
      keys = [.mute, .volumeUp, .volumeDown]
    case Utils.ListenForKeys.none.rawValue:
      keys = []
    default:
      keys = [.brightnessUp, .brightnessDown, .mute, .volumeUp, .volumeDown]
    }
    // Remove keys if no external displays are connected
    var isInternalDisplayOnly = true
    for display in DisplayManager.shared.getAllDisplays() where display is ExternalDisplay {
      isInternalDisplayOnly = false
    }
    if isInternalDisplayOnly {
      let keysToDelete: [MediaKey] = [.volumeUp, .volumeDown, .mute, .brightnessUp, .brightnessDown]
      keys.removeAll { keysToDelete.contains($0) }
    }
    // Remove volume related keys if audio device is controllable
    if self.coreAudio.defaultOutputDevice?.canSetVirtualMasterVolume(scope: .output) == true {
      let keysToDelete: [MediaKey] = [.volumeUp, .volumeDown, .mute]
      keys.removeAll { keysToDelete.contains($0) }
    }
    self.mediaKeyTap?.stop()
    // returning an empty array listens for all mediakeys in MediaKeyTap
    if keys.count > 0 {
      self.mediaKeyTap = MediaKeyTap(delegate: self, on: KeyPressMode.keyDownAndUp, for: keys, observeBuiltIn: true)
      self.mediaKeyTap?.start()
    }
  }

  @objc private func audioDeviceChanged() {
    #if DEBUG
      if let defaultDevice = self.coreAudio.defaultOutputDevice {
        os_log("Default output device changed to “%{public}@”.", type: .info, defaultDevice.name)
        os_log("Can device set its own volume? %{public}@", type: .info, defaultDevice.canSetVirtualMasterVolume(scope: .output).description)
      }
    #endif
    self.updateMediaKeyTap()
  }

  @objc private func colorSyncSettingsChanged() {
    CGDisplayRestoreColorSyncSettings()
    self.displayReconfigured()
  }
}
