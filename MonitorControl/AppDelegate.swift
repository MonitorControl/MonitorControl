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
  let debugSw: Bool = false
  lazy var preferencesWindowController: PreferencesWindowController = {
    let storyboard = NSStoryboard(name: "Main", bundle: Bundle.main)
    let mainPrefsVc = storyboard.instantiateController(withIdentifier: "MainPrefsVC") as? MainPrefsViewController
    let displayPrefsVc = storyboard.instantiateController(withIdentifier: "DisplayPrefsVC") as? DisplayPrefsViewController
    let advancedPrefsVc = storyboard.instantiateController(withIdentifier: "AdvancedPrefsVC") as? AdvancedPrefsViewController
    let aboutPrefsVc = storyboard.instantiateController(withIdentifier: "AboutPrefsVC") as? AboutPrefsViewController
    return PreferencesWindowController(
      preferencePanes: [
        mainPrefsVc!,
        displayPrefsVc!,
        advancedPrefsVc!,
        aboutPrefsVc!,
      ],
      animated: true // causes nice (some say glitchy) animations
    )
  }()

  func applicationDidFinishLaunching(_: Notification) {
    app = self
    self.subscribeEventListeners()
    self.setDefaultPrefs()
    self.updateMediaKeyTap()
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
      prefs.set(false, forKey: Utils.PrefKeys.fallbackSw.rawValue)
      prefs.set(false, forKey: Utils.PrefKeys.hideMenuIcon.rawValue)
    }
  }

  func clearDisplays() {
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
    DisplayManager.shared.clearDisplays()
  }

  func updateArm64AVServices() {
    if Arm64DDCUtils.isArm64 {
      os_log("arm64 AVService update requested", type: .info)
      var displayIDs: [CGDirectDisplayID] = []
      for externalDisplay in DisplayManager.shared.getExternalDisplays() {
        displayIDs.append(externalDisplay.identifier)
      }
      for serviceMatch in Arm64DDCUtils.getServiceMatches(displayIDs: displayIDs) {
        for externalDisplay in DisplayManager.shared.getExternalDisplays() where externalDisplay.identifier == serviceMatch.displayID && serviceMatch.service != nil {
          externalDisplay.arm64avService = serviceMatch.service
          os_log("Display service match successful for display %{public}@", type: .info, String(serviceMatch.displayID))
          // if Arm64DDCUtils.read(service: externalDisplay.arm64avService, command: UInt8(0xF1)) != nil {
          //   externalDisplay.arm64ddc = true
          // }
          if !serviceMatch.isDiscouraged {
            externalDisplay.arm64ddc = !debugSw ? true : false // MARK: (point of interest when testing)
          }
        }
      }
      os_log("AVService update done", type: .info)
    }
  }

  func displayReconfigured() {
    if self.sleepID == 0 {
      self.reconfigureID += 1
      let dispatchedReconfigureID = self.reconfigureID
      os_log("Display to be reconfigured with reconfigureID %{public}@", type: .info, String(dispatchedReconfigureID))
      DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
        self.updateDisplays(dispatchedReconfigureID: dispatchedReconfigureID)
      }
    }
  }

  func updateMenus(controllableExternalDisplays: [ExternalDisplay]) {
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
    self.clearDisplays()
    var onlineDisplayIDs = [CGDirectDisplayID](repeating: 0, count: 10)
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
    if firstrun {
      DisplayManager.shared.resetSwBrightnessForAllDisplays(settingsOnly: true)
    } else {
      if prefs.bool(forKey: Utils.PrefKeys.fallbackSw.rawValue) || prefs.bool(forKey: Utils.PrefKeys.lowerSwAfterBrightness.rawValue) {
        DisplayManager.shared.restoreSwBrightnessForAllDisplays()
      }
    }
    self.updateArm64AVServices()
    NotificationCenter.default.post(name: Notification.Name(Utils.PrefKeys.displayListUpdate.rawValue), object: nil)
    var controllableExternalDisplays: [ExternalDisplay] = []
    if prefs.bool(forKey: Utils.PrefKeys.fallbackSw.rawValue) {
      controllableExternalDisplays = DisplayManager.shared.getNonVirtualExternalDisplays()
    } else {
      controllableExternalDisplays = DisplayManager.shared.getDdcCapableDisplays()
    }
    self.updateMenus(controllableExternalDisplays: controllableExternalDisplays)
  }

  private func addDisplayToMenu(display: ExternalDisplay, asSubMenu: Bool) {
    if !asSubMenu {
      self.statusMenu.insertItem(NSMenuItem.separator(), at: 0)
    }
    let monitorSubMenu: NSMenu = asSubMenu ? NSMenu() : self.statusMenu

    if !display.isSw() {
      if prefs.bool(forKey: Utils.PrefKeys.showVolume.rawValue) {
        let volumeSliderHandler = Utils.addSliderMenuItem(toMenu: monitorSubMenu, forDisplay: display, command: .audioSpeakerVolume, title: NSLocalizedString("Volume", comment: "Shown in menu"))
        display.volumeSliderHandler = volumeSliderHandler
      }
      if prefs.bool(forKey: Utils.PrefKeys.showContrast.rawValue) {
        let contrastSliderHandler = Utils.addSliderMenuItem(toMenu: monitorSubMenu, forDisplay: display, command: .contrast, title: NSLocalizedString("Contrast", comment: "Shown in menu"))
        display.contrastSliderHandler = contrastSliderHandler
      }
    }
    let brightnessSliderHandler = Utils.addSliderMenuItem(toMenu: monitorSubMenu, forDisplay: display, command: .brightness, title: NSLocalizedString("Brightness", comment: "Shown in menu"))
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
    NotificationCenter.default.addObserver(self, selector: #selector(handleShowContrastChanged), name: .showContrast, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(handleShowVolumeChanged), name: .showVolume, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(handleFallbackSwChanged), name: .fallbackSw, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(handleFriendlyNameChanged), name: .friendlyName, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(handlePreferenceReset), name: .preferenceReset, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(audioDeviceChanged), name: Notification.Name.defaultOutputDeviceChanged, object: nil) // subscribe Audio output detector (SimplyCoreAudio)
    NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(self.sleepNotification), name: NSWorkspace.screensDidSleepNotification, object: nil) // sleep and wake listeners
    NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(self.wakeNotofication), name: NSWorkspace.screensDidWakeNotification, object: nil)
    NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(self.sleepNotification), name: NSWorkspace.willSleepNotification, object: nil)
    NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(self.wakeNotofication), name: NSWorkspace.didWakeNotification, object: nil)
    _ = DistributedNotificationCenter.default().addObserver(forName: .accessibilityApi, object: nil, queue: nil) { _ in DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      self.updateMediaKeyTap() // listen for accessibility status changes
    }
    }
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
      self.updateDisplays()
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
      return
    }
    if self.handleOpenPrefPane(mediaKey: mediaKey, event: event, modifiers: modifiers) {
      return
    }
    let isSmallIncrement = modifiers?.isSuperset(of: NSEvent.ModifierFlags([.shift, .option])) ?? false
    // control internal display when holding ctrl modifier
    let isControlModifier = modifiers?.isSuperset(of: NSEvent.ModifierFlags([.control])) ?? false
    if isControlModifier, mediaKey == .brightnessUp || mediaKey == .brightnessDown {
      if let internalDisplay = DisplayManager.shared.getBuiltInDisplay() as? InternalDisplay {
        internalDisplay.stepBrightness(isUp: mediaKey == .brightnessUp, isSmallIncrement: isSmallIncrement)
        return
      }
    }
    let oppositeKey: MediaKey? = self.oppositeMediaKey(mediaKey: mediaKey)
    let isRepeat = event?.keyRepeat ?? false
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
    self.sendDisplayCommand(mediaKey: mediaKey, isRepeat: isRepeat, isSmallIncrement: isSmallIncrement)
  }

  private func getAffectedDisplays() -> [Display]? {
    var affectedDisplays: [Display]
    let allDisplays = DisplayManager.shared.getAllNonVirtualDisplays()
    guard let currentDisplay = DisplayManager.shared.getCurrentDisplay() else {
      return nil
    }
    // let allDisplays = prefs.bool(forKey: Utils.PrefKeys.allScreens.rawValue) ? displays : [currentDisplay]
    if prefs.bool(forKey: Utils.PrefKeys.allScreens.rawValue) {
      affectedDisplays = allDisplays
    } else {
      affectedDisplays = [currentDisplay]
      if CGDisplayIsInHWMirrorSet(currentDisplay.identifier) != 0 || CGDisplayIsInMirrorSet(currentDisplay.identifier) != 0, CGDisplayMirrorsDisplay(currentDisplay.identifier) == 0 {
        for display in allDisplays where CGDisplayMirrorsDisplay(display.identifier) == currentDisplay.identifier {
          affectedDisplays.append(display)
        }
      }
    }
    return affectedDisplays
  }

  private func sendDisplayCommand(mediaKey: MediaKey, isRepeat: Bool, isSmallIncrement: Bool) {
    guard self.sleepID == 0, self.reconfigureID == 0, let affectedDisplays = self.getAffectedDisplays() else {
      return
    }
    let delay = isRepeat ? 0.05 : 0 // Introduce a small delay to handle the media key being held down
    var isAnyDisplayInSwAfterBrightnessMode: Bool = false
    for display in affectedDisplays where ((display as? ExternalDisplay)?.isSwBrightnessNotDefault() ?? false) && !((display as? ExternalDisplay)?.isSw() ?? false) {
      isAnyDisplayInSwAfterBrightnessMode = true
    }
    self.keyRepeatTimers[mediaKey] = Timer.scheduledTimer(withTimeInterval: delay, repeats: false, block: { _ in
      for display in affectedDisplays where display.isEnabled && !display.isVirtual {
        switch mediaKey {
        case .brightnessUp:
          if !(isAnyDisplayInSwAfterBrightnessMode && !(((display as? ExternalDisplay)?.isSwBrightnessNotDefault() ?? false) && !((display as? ExternalDisplay)?.isSw() ?? false))) {
            display.stepBrightness(isUp: mediaKey == .brightnessUp, isSmallIncrement: isSmallIncrement)
          }
        case .brightnessDown:
          display.stepBrightness(isUp: mediaKey == .brightnessUp, isSmallIncrement: isSmallIncrement)
        case .mute:
          // The mute key should not respond to press + hold
          if !isRepeat {
            // mute only matters for external displays
            if let display = display as? ExternalDisplay {
              display.toggleMute()
            }
          }
        case .volumeUp, .volumeDown:
          // volume only matters for external displays
          if let display = display as? ExternalDisplay {
            display.stepVolume(isUp: mediaKey == .volumeUp, isSmallIncrement: isSmallIncrement)
          }
        default:
          return
        }
      }
    })
  }

  @objc func handleListenForChanged() {
    self.checkPermissions()
    self.updateMediaKeyTap()
  }

  @objc func handleShowContrastChanged() {
    self.updateDisplays()
  }

  @objc func handleShowVolumeChanged() {
    self.updateDisplays()
  }

  @objc func handleFallbackSwChanged() {
    self.updateDisplays()
  }

  @objc func handleFriendlyNameChanged() {
    self.updateDisplays()
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
    if self.coreAudio.defaultOutputDevice?.canSetVirtualMasterVolume(scope: .output) == true { // Remove volume related keys.
      let keysToDelete: [MediaKey] = [.volumeUp, .volumeDown, .mute]
      keys.removeAll { keysToDelete.contains($0) }
    }
    self.mediaKeyTap?.stop()
    // returning an empty array listens for all mediakeys in MediaKeyTap
    if keys.count > 0 {
      self.mediaKeyTap = MediaKeyTap(delegate: self, for: keys, observeBuiltIn: true)
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
}
