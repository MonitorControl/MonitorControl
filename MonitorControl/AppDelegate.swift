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

  lazy var preferencesWindowController: PreferencesWindowController = {
    let storyboard = NSStoryboard(name: "Main", bundle: Bundle.main)
    let mainPrefsVc = storyboard.instantiateController(withIdentifier: "MainPrefsVC") as? MainPrefsViewController
    let keyPrefsVc = storyboard.instantiateController(withIdentifier: "KeysPrefsVC") as? KeysPrefsViewController
    let displayPrefsVc = storyboard.instantiateController(withIdentifier: "DisplayPrefsVC") as? DisplayPrefsViewController
    let advancedPrefsVc = storyboard.instantiateController(withIdentifier: "AdvancedPrefsVC") as? AdvancedPrefsViewController
    return PreferencesWindowController(
      preferencePanes: [
        mainPrefsVc!,
        keyPrefsVc!,
        displayPrefsVc!,
        advancedPrefsVc!,
      ],
      animated: false // causes glitchy animations
    )
  }()

  func applicationDidFinishLaunching(_: Notification) {
    app = self
    self.subscribeEventListeners()
    self.setDefaultPrefs()
    self.updateMediaKeyTap()
    self.statusItem.button?.image = NSImage(named: "status")
    self.statusItem.menu = self.statusMenu
    self.checkPermissions()
    CGDisplayRegisterReconfigurationCallback({ _, _, _ in app.updateDisplays() }, nil)
    self.updateDisplays()
  }

  @IBAction func quitClicked(_: AnyObject) {
    NSApplication.shared.terminate(self)
  }

  @IBAction func prefsClicked(_: AnyObject) {
    self.preferencesWindowController.show()
  }

  // Set the default prefs of the app
  func setDefaultPrefs() {
    if !prefs.bool(forKey: Utils.PrefKeys.appAlreadyLaunched.rawValue) {
      prefs.set(true, forKey: Utils.PrefKeys.appAlreadyLaunched.rawValue)

      prefs.set(false, forKey: Utils.PrefKeys.showContrast.rawValue)
      prefs.set(true, forKey: Utils.PrefKeys.showVolume.rawValue)
      prefs.set(false, forKey: Utils.PrefKeys.lowerContrast.rawValue)
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

  func getDisplayName(displayID: CGDirectDisplayID) -> String {
    let defaultName: String = NSLocalizedString("Unknown", comment: "Unknown display name") // + String(CGDisplaySerialNumber(displayID))
    if let dictionary = ((CoreDisplay_DisplayCreateInfoDictionary(displayID))?.takeRetainedValue() as NSDictionary?), let nameList = dictionary["DisplayProductName"] as? [String: String], let name = nameList[Locale.current.identifier] ?? nameList["en_US"] ?? nameList.first?.value {
      return name
    }
    if let screen = NSScreen.getByDisplayID(displayID: displayID) {
      if #available(OSX 10.15, *) {
        return screen.localizedName
      } else {
        return screen.displayName ?? defaultName
      }
    }
    if CGDisplayIsInHWMirrorSet(displayID) != 0 || CGDisplayIsInMirrorSet(displayID) != 0 {
      if let mirroredScreen = NSScreen.getByDisplayID(displayID: CGDisplayMirrorsDisplay(displayID)) {
        let name = NSLocalizedString("Mirror of", comment: "Shown in case a display mirrors an other display - like 'Mirror of DisplayName")
        if #available(OSX 10.15, *) {
          return "" + name + " " + String(mirroredScreen.localizedName)
        } else {
          return "" + name + " " + String(mirroredScreen.displayName ?? defaultName)
        }
      }
    }
    return defaultName
  }

  #if arch(arm64)

    func updateAVServices() {
      // MARK: TODO tasks

      // Implement - Find out the match score of each service (via its destcriptor strings) to each ExternalDisplay using the new ExternalDisplay.ioregMatchScore()
      // Implement - Based on the scores, attach the proper service in order from the service array to each ExternalDisplay
      // Cleanup - Reduce cyclomatic complexity, break up into parts
      // Cleanup - Move all this stuff out to a separate source file

      // This will store the IOAVService with associated display properties
      struct IOregService {
        var service: IOAVService?
        var edidUUID: String = ""
        var productName: String = ""
        var serialNumber: Int64 = 0
      }
      var ioregServicesForMatching: [IOregService] = []
      // We will iterate through the entire ioreg tree
      let root: io_registry_entry_t = IORegistryGetRootEntry(kIOMasterPortDefault)
      var iter = io_iterator_t()
      guard IORegistryEntryCreateIterator(root, "IOService", IOOptionBits(kIORegistryIterateRecursively), &iter) == KERN_SUCCESS else {
        os_log("IORegistryEntryCreateIterator error", type: .debug)
        return
      }
      var service: io_service_t
      while true {
        service = IOIteratorNext(iter)
        guard service != MACH_PORT_NULL else {
          break
        }
        let name = UnsafeMutablePointer<CChar>.allocate(capacity: MemoryLayout<io_name_t>.size)
        guard IORegistryEntryGetName(service, name) == KERN_SUCCESS else {
          os_log("IORegistryEntryGetName error", type: .debug)
          return
        }
        // We are looking for an AppleCLCD2 service
        if String(cString: name) == "AppleCLCD2" {
          // We will check if it has an EDID UUID. If so, then we take it as an external display
          if let unmanagedEdidUUID = IORegistryEntryCreateCFProperty(service, CFStringCreateWithCString(kCFAllocatorDefault, "EDID UUID", kCFStringEncodingASCII), kCFAllocatorDefault, IOOptionBits(kIORegistryIterateRecursively)), let edidUUID = unmanagedEdidUUID.takeRetainedValue() as? String {
            // Now we will store the display's properties
            var ioregService = IOregService()
            ioregService.edidUUID = edidUUID
            if let unmanagedDisplayAttrs = IORegistryEntryCreateCFProperty(service, CFStringCreateWithCString(kCFAllocatorDefault, "DisplayAttributes", kCFStringEncodingASCII), kCFAllocatorDefault, IOOptionBits(kIORegistryIterateRecursively)), let displayAttrs = unmanagedDisplayAttrs.takeRetainedValue() as? NSDictionary, let productAttrs = displayAttrs.value(forKey: "ProductAttributes") as? NSDictionary {
              if let productName = productAttrs.value(forKey: "ProductName") as? String {
                ioregService.productName = productName
              }
              if let serialNumber = productAttrs.value(forKey: "SerialNumber") as? Int64 {
                ioregService.serialNumber = serialNumber
              }
            }
            //  We will now iterate further, looking for the belonging "DCPAVServiceProxy" service (which should follow "AppleCLCD2" somewhat closely)
            while true {
              service = IOIteratorNext(iter)
              guard service != MACH_PORT_NULL else {
                break
              }
              let name = UnsafeMutablePointer<CChar>.allocate(capacity: MemoryLayout<io_name_t>.size)
              guard IORegistryEntryGetName(service, name) == KERN_SUCCESS else {
                os_log("IORegistryEntryGetName error", type: .debug)
                return
              }
              if String(cString: name) == "DCPAVServiceProxy" {
                // Let's now create an instance of IOAVService with this service and add it to the service store with the "AppleCLCD2" strings
                if let unmanagedLocation = IORegistryEntryCreateCFProperty(service, CFStringCreateWithCString(kCFAllocatorDefault, "Location", kCFStringEncodingASCII), kCFAllocatorDefault, IOOptionBits(kIORegistryIterateRecursively)), let location = unmanagedLocation.takeRetainedValue() as? String {
                  if location == "External" {
                    ioregService.service = IOAVServiceCreateWithService(kCFAllocatorDefault, service)?.takeRetainedValue() as IOAVService
                    if ioregService.service != nil {
                      // Finally, we are there!
                      ioregServicesForMatching.append(ioregService)
                    }
                  }
                }
              }
            }
          }
        }
      }

      // MARK: Temporary solution (returns whichever service we found first for every display)

      for display in DisplayManager.shared.getExternalDisplays() {
        display.arm64avService = IOAVServiceCreate(kCFAllocatorDefault)?.takeRetainedValue() as IOAVService
        display.arm64ddc = true

        /*
         var send: [UInt8] = [0xF1]
         var reply = [UInt8](repeating: 0, count: 11)
         if display.arm64ddcComm(send: &send, reply: &reply) {
           display.arm64ddc = true
         }
          */
      }
    }

  #endif

  func updateDisplays() {
    self.clearDisplays()

    var onlineDisplayIDs = [CGDirectDisplayID](repeating: 0, count: 10)
    var displayCount: UInt32 = 0

    guard CGGetOnlineDisplayList(10, &onlineDisplayIDs, &displayCount) == .success else {
      os_log("Unable to get display list.", type: .info)
      return
    }

    for onlineDisplayID in onlineDisplayIDs where onlineDisplayID != 0 {
      let name = getDisplayName(displayID: onlineDisplayID)
      let id = onlineDisplayID
      let vendorNumber = CGDisplayVendorNumber(onlineDisplayID)
      let modelNumber = CGDisplayVendorNumber(onlineDisplayID)
      let display: Display

      var isVirtual: Bool = false

      if let dictionary = ((CoreDisplay_DisplayCreateInfoDictionary(onlineDisplayID))?.takeRetainedValue() as NSDictionary?) {
        let isVirtualDevice = dictionary["kCGDisplayIsVirtualDevice"] as? Bool
        let displayIsAirplay = dictionary["kCGDisplayIsAirPlay"] as? Bool
        if isVirtualDevice ?? displayIsAirplay ?? false {
          isVirtual = true
        }
      }

      if CGDisplayIsBuiltin(onlineDisplayID) != 0 {
        display = InternalDisplay(id, name: name, vendorNumber: vendorNumber, modelNumber: modelNumber, isVirtual: isVirtual)
      } else {
        display = ExternalDisplay(id, name: name, vendorNumber: vendorNumber, modelNumber: modelNumber, isVirtual: isVirtual)
      }

      DisplayManager.shared.addDisplay(display: display)
    }

    #if arch(arm64)

      self.updateAVServices()

    #endif

    let ddcDisplays = DisplayManager.shared.getDdcCapableDisplays()
    if ddcDisplays.count == 0 {
      let item = NSMenuItem()
      item.title = NSLocalizedString("No supported display found", comment: "Shown in menu")
      item.isEnabled = false
      self.monitorItems.append(item)
      self.statusMenu.insertItem(item, at: 0)
      self.statusMenu.insertItem(NSMenuItem.separator(), at: 1)
    } else {
      for display in ddcDisplays {
        os_log("Supported display found: %{public}@", type: .info, "\(display.name) (Vendor: \(display.vendorNumber ?? 0), Model: \(display.modelNumber ?? 0))")

        let asSubmenu: Bool = ddcDisplays.count > 2 ? true : false // MARK: >2

        if asSubmenu {
          self.statusMenu.insertItem(NSMenuItem.separator(), at: 0)
        }
        self.addDisplayToMenu(display: display, asSubMenu: asSubmenu)
      }
    }
  }

  private func addDisplayToMenu(display: ExternalDisplay, asSubMenu: Bool) {
    if !asSubMenu {
      self.statusMenu.insertItem(NSMenuItem.separator(), at: 0)
    }
    let monitorSubMenu: NSMenu = asSubMenu ? NSMenu() : self.statusMenu

    if prefs.bool(forKey: Utils.PrefKeys.showVolume.rawValue) {
      let volumeSliderHandler = Utils.addSliderMenuItem(toMenu: monitorSubMenu,
                                                        forDisplay: display,
                                                        command: .audioSpeakerVolume,
                                                        title: NSLocalizedString("Volume", comment: "Shown in menu"))
      display.volumeSliderHandler = volumeSliderHandler
    }
    if prefs.bool(forKey: Utils.PrefKeys.showContrast.rawValue) {
      let contrastSliderHandler = Utils.addSliderMenuItem(toMenu: monitorSubMenu,
                                                          forDisplay: display,
                                                          command: .contrast,
                                                          title: NSLocalizedString("Contrast", comment: "Shown in menu"))
      display.contrastSliderHandler = contrastSliderHandler
    }
    let brightnessSliderHandler = Utils.addSliderMenuItem(toMenu: monitorSubMenu,
                                                          forDisplay: display,
                                                          command: .brightness,
                                                          title: NSLocalizedString("Brightness", comment: "Shown in menu"))

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
    // subscribe KeyTap event listener
    NotificationCenter.default.addObserver(self, selector: #selector(handleListenForChanged), name: .listenFor, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(handleShowContrastChanged), name: .showContrast, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(handleShowVolumeChanged), name: .showVolume, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(handleFriendlyNameChanged), name: .friendlyName, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(handlePreferenceReset), name: .preferenceReset, object: nil)

    // subscribe Audio output detector (SimplyCoreAudio)
    NotificationCenter.default.addObserver(self, selector: #selector(audioDeviceChanged), name: Notification.Name.defaultOutputDeviceChanged, object: nil)

    // listen for accessibility status changes
    _ = DistributedNotificationCenter.default().addObserver(forName: .accessibilityApi, object: nil, queue: nil) { _ in
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        self.updateMediaKeyTap()
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

// MARK: - Media Key Tap delegate

extension AppDelegate: MediaKeyTapDelegate {
  func handle(mediaKey: MediaKey, event: KeyEvent?, modifiers: NSEvent.ModifierFlags?) {
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

  private func sendDisplayCommand(mediaKey: MediaKey, isRepeat: Bool, isSmallIncrement: Bool) {
    let displays = DisplayManager.shared.getAllDisplays()
    guard let currentDisplay = DisplayManager.shared.getCurrentDisplay() else { return }

    let allDisplays = prefs.bool(forKey: Utils.PrefKeys.allScreens.rawValue) ? displays : [currentDisplay]

    // Introduce a small delay to handle the media key being held down
    let delay = isRepeat ? 0.05 : 0

    var isAnyDisplayInContrastAfterBrightnessMode: Bool = false
    for display in allDisplays where (display as? ExternalDisplay)?.isContrastAfterBrightnessMode ?? false {
      isAnyDisplayInContrastAfterBrightnessMode = true
    }

    self.keyRepeatTimers[mediaKey] = Timer.scheduledTimer(withTimeInterval: delay, repeats: false, block: { _ in
      for display in allDisplays where display.isEnabled && !display.isVirtual {
        switch mediaKey {
        case .brightnessUp:
          if !(isAnyDisplayInContrastAfterBrightnessMode && !((display as? ExternalDisplay)?.isContrastAfterBrightnessMode ?? false)) {
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

  // MARK: - Prefs notification

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

  @objc func handleFriendlyNameChanged() {
    self.updateDisplays()
  }

  @objc func handlePreferenceReset() {
    self.setDefaultPrefs()
    self.updateDisplays()
    self.checkPermissions()
    self.updateMediaKeyTap()
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

    if self.coreAudio.defaultOutputDevice?.canSetVirtualMasterVolume(scope: .output) == true {
      // Remove volume related keys.
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
