import AMCoreAudio
import Cocoa
import DDC
import Foundation
import MASPreferences
import MediaKeyTap
import os.log

var app: AppDelegate!
let prefs = UserDefaults.standard

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
  @IBOutlet var statusMenu: NSMenu!
  @IBOutlet var window: NSWindow!

  let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

  var monitorItems: [NSMenuItem] = []

  var mediaKeyTap: MediaKeyTap?
  var prefsController: NSWindowController?
  var keyRepeatTimers: [MediaKey: Timer] = [:]

  var accessibilityObserver: NSObjectProtocol!

  func applicationDidFinishLaunching(_: Notification) {
    app = self
    self.setupViewControllers()
    self.subscribeEventListeners()
    self.setDefaultPrefs()
    self.updateMediaKeyTap()
    self.statusItem.image = NSImage(named: "status")
    self.statusItem.menu = self.statusMenu
    self.checkPermissions()
    CGDisplayRegisterReconfigurationCallback({ _, _, _ in app.updateDisplays() }, nil)
    self.updateDisplays()
  }

  @IBAction func quitClicked(_: AnyObject) {
    NSApplication.shared.terminate(self)
  }

  @IBAction func prefsClicked(_ sender: AnyObject) {
    if let prefsController = prefsController {
      prefsController.showWindow(sender)
      NSApp.activate(ignoringOtherApps: true)
      prefsController.window?.makeKeyAndOrderFront(sender)
    }
  }

  /// Set the default prefs of the app
  func setDefaultPrefs() {
    if !prefs.bool(forKey: Utils.PrefKeys.appAlreadyLaunched.rawValue) {
      prefs.set(true, forKey: Utils.PrefKeys.appAlreadyLaunched.rawValue)

      prefs.set(false, forKey: Utils.PrefKeys.showContrast.rawValue)
      prefs.set(false, forKey: Utils.PrefKeys.showVolume.rawValue)
      prefs.set(false, forKey: Utils.PrefKeys.lowerContrast.rawValue)
    }
  }

  // MARK: - Menu

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

  func updateDisplays() {
    self.clearDisplays()

    for screen in NSScreen.screens {
      let name = screen.displayName ?? NSLocalizedString("Unknown", comment: "Unknown display name")
      let id = screen.displayID
      let vendorNumber = screen.vendorNumber
      let modelNumber = screen.modelNumber
      let display: Display
      if screen.isBuiltin {
        display = InternalDisplay(id, name: name, vendorNumber: vendorNumber, modelNumber: modelNumber)
      } else {
        display = ExternalDisplay(id, name: name, vendorNumber: vendorNumber, modelNumber: modelNumber)
      }
      DisplayManager.shared.addDisplay(display: display)
    }

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
        self.addDisplayToMenu(display: display, asSubMenu: ddcDisplays.count > 1)
      }
    }
  }

  private func addDisplayToMenu(display: ExternalDisplay, asSubMenu: Bool) {
    let monitorSubMenu: NSMenu = asSubMenu ? NSMenu() : self.statusMenu

    self.statusMenu.insertItem(NSMenuItem.separator(), at: 0)
    
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
    monitorMenuItem.title = "\(display.getFriendlyName())"
    if asSubMenu {
      monitorMenuItem.submenu = monitorSubMenu
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

  private func setupViewControllers() {
    let storyboard: NSStoryboard = NSStoryboard(name: "Main", bundle: Bundle.main)
    let mainPrefsVc = storyboard.instantiateController(withIdentifier: "MainPrefsVC")
    let keyPrefsVc = storyboard.instantiateController(withIdentifier: "KeysPrefsVC")
    let displayPrefsVc = storyboard.instantiateController(withIdentifier: "DisplayPrefsVC")
    let advancedPrefsVc = storyboard.instantiateController(withIdentifier: "AdvancedPrefsVC")
    let views = [
      mainPrefsVc,
      keyPrefsVc,
      displayPrefsVc,
      advancedPrefsVc,
    ]
    prefsController = MASPreferencesWindowController(viewControllers: views, title: NSLocalizedString("Preferences", comment: "Shown in Preferences window"))
  }

  private func subscribeEventListeners() {
    // subscribe KeyTap event listener
    NotificationCenter.default.addObserver(self, selector: #selector(handleListenForChanged), name: .listenFor, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(handleShowVolumeChanged), name: .showVolume, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(handleShowContrastChanged), name: .showContrast, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(handleFriendlyNameChanged), name: .friendlyName, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(handlePreferenceReset), name: .preferenceReset, object: nil)

    // subscribe Audio output detector (AMCoreAudio)
    AMCoreAudio.NotificationCenter.defaultCenter.subscribe(self, eventType: AudioHardwareEvent.self, dispatchQueue: DispatchQueue.main)

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

    self.keyRepeatTimers[mediaKey] = Timer.scheduledTimer(withTimeInterval: delay, repeats: false, block: { _ in
      for display in allDisplays where display.isEnabled {
        switch mediaKey {
        case .brightnessUp, .brightnessDown:
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

    if let audioDevice = AudioDevice.defaultOutputDevice(), audioDevice.canSetVirtualMasterVolume(direction: .playback) {
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
}

extension AppDelegate: EventSubscriber {
  /// Fires off when the default audio device changes.
  func eventReceiver(_ event: Event) {
    if case let .defaultOutputDeviceChanged(audioDevice)? = event as? AudioHardwareEvent {
      #if DEBUG
        os_log("Default output device changed to “%{public}@”.", type: .info, audioDevice.name)
        os_log("Can device set its own volume? %{public}@", type: .info, audioDevice.canSetVirtualMasterVolume(direction: .playback).description)
      #endif
      self.updateMediaKeyTap()
    }
  }
}
