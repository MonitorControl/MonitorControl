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
  var displays: [Display] = []

  let step = 100 / 16

  var mediaKeyTap: MediaKeyTap?
  var prefsController: NSWindowController?

  var accessibilityObserver: NSObjectProtocol!

  func applicationDidFinishLaunching(_: Notification) {
    app = self

    self.setupLayout()
    self.subscribeEventListeners()
    self.startOrRestartMediaKeyTap()
    self.statusItem.image = NSImage(named: "status")
    self.statusItem.menu = self.statusMenu
    self.setDefaultPrefs()
    Utils.acquirePrivileges()
    CGDisplayRegisterReconfigurationCallback({ _, _, _ in app.updateDisplays() }, nil)
    self.updateDisplays()
  }

  func applicationWillTerminate(_: Notification) {
    AMCoreAudio.NotificationCenter.defaultCenter.unsubscribe(self, eventType: AudioHardwareEvent.self)
    DistributedNotificationCenter.default().removeObserver(self.accessibilityObserver as Any, name: .accessibilityApi, object: nil)
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
    let prefs = UserDefaults.standard
    if !prefs.bool(forKey: Utils.PrefKeys.appAlreadyLaunched.rawValue) {
      prefs.set(true, forKey: Utils.PrefKeys.appAlreadyLaunched.rawValue)

      prefs.set(false, forKey: Utils.PrefKeys.showContrast.rawValue)
      prefs.set(false, forKey: Utils.PrefKeys.lowerContrast.rawValue)
    }
  }

  // MARK: - Menu

  func clearDisplays() {
    if self.statusMenu.items.count > 2 {
      var items: [NSMenuItem] = []
      for i in 0..<self.statusMenu.items.count - 2 {
        items.append(self.statusMenu.items[i])
      }

      for item in items {
        self.statusMenu.removeItem(item)
      }
    }

    self.monitorItems = []
    self.displays = []
  }

  func updateDisplays() {
    self.clearDisplays()

    let filteredScreens = NSScreen.screens.filter { screen -> Bool in
      // Skip built-in displays.
      if screen.isBuiltin {
        return false
      }

      return DDC(for: screen.displayID)?.edid() != nil
    }

    switch filteredScreens.count {
    case 0:
      // If no DDC capable display was detected
      let item = NSMenuItem()
      item.title = NSLocalizedString("No supported display found", comment: "Shown in menu")
      item.isEnabled = false
      self.monitorItems.append(item)
      self.statusMenu.insertItem(item, at: 0)
      self.statusMenu.insertItem(NSMenuItem.separator(), at: 1)
    default:
      os_log("The following supported displays were found:", type: .info)

      for screen in filteredScreens {
        os_log(" - %{public}@", type: .info, "\(screen.displayName ?? NSLocalizedString("Unknown", comment: "Unknown display name")) (Vendor: \(screen.vendorNumber ?? 0), Model: \(screen.modelNumber ?? 0))")
        self.addScreenToMenu(screen: screen, asSubMenu: filteredScreens.count > 1)
      }
    }
  }

  /// Add a screen to the menu
  ///
  /// - Parameters:
  ///   - screen: The screen to add
  ///   - asSubMenu: Display in a sub menu or directly in menu
  private func addScreenToMenu(screen: NSScreen, asSubMenu: Bool) {
    let id = screen.displayID
    let ddc = DDC(for: id)

    if let edid = ddc?.edid() {
      let name = Utils.getDisplayName(forEdid: edid)

      let display = Display(id, name: name, isBuiltin: screen.isBuiltin)

      let monitorSubMenu: NSMenu = asSubMenu ? NSMenu() : self.statusMenu

      self.statusMenu.insertItem(NSMenuItem.separator(), at: 0)

      let volumeSliderHandler = Utils.addSliderMenuItem(toMenu: monitorSubMenu,
                                                        forDisplay: display,
                                                        command: .audioSpeakerVolume,
                                                        title: NSLocalizedString("Volume", comment: "Shown in menu"))
      let brightnessSliderHandler = Utils.addSliderMenuItem(toMenu: monitorSubMenu,
                                                            forDisplay: display,
                                                            command: .brightness,
                                                            title: NSLocalizedString("Brightness", comment: "Shown in menu"))
      if prefs.bool(forKey: Utils.PrefKeys.showContrast.rawValue) {
        let contrastSliderHandler = Utils.addSliderMenuItem(toMenu: monitorSubMenu,
                                                            forDisplay: display,
                                                            command: .contrast,
                                                            title: NSLocalizedString("Contrast", comment: "Shown in menu"))
        display.contrastSliderHandler = contrastSliderHandler
      }

      display.volumeSliderHandler = volumeSliderHandler
      display.brightnessSliderHandler = brightnessSliderHandler
      self.displays.append(display)

      let monitorMenuItem = NSMenuItem()
      monitorMenuItem.title = "\(display.getFriendlyName())"
      if asSubMenu {
        monitorMenuItem.submenu = monitorSubMenu
      }

      self.monitorItems.append(monitorMenuItem)
      self.statusMenu.insertItem(monitorMenuItem, at: 0)
    }
  }

  private func setupLayout() {
    let storyboard: NSStoryboard = NSStoryboard(name: "Main", bundle: Bundle.main)
    let views = [
      storyboard.instantiateController(withIdentifier: "MainPrefsVC"),
      storyboard.instantiateController(withIdentifier: "KeysPrefsVC"),
      storyboard.instantiateController(withIdentifier: "DisplayPrefsVC"),
    ]
    prefsController = MASPreferencesWindowController(viewControllers: views, title: NSLocalizedString("Preferences", comment: "Shown in Preferences window"))
  }

  private func subscribeEventListeners() {
    // subscribe KeyTap event listener
    NotificationCenter.default.addObserver(self, selector: #selector(handleListenForChanged), name: NSNotification.Name(Utils.PrefKeys.listenFor.rawValue), object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(handleShowContrastChanged), name: NSNotification.Name(Utils.PrefKeys.showContrast.rawValue), object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(handleFriendlyNameChanged), name: NSNotification.Name(Utils.PrefKeys.friendlyName.rawValue), object: nil)

    // subscribe Audio output detector (AMCoreAudio)
    AMCoreAudio.NotificationCenter.defaultCenter.subscribe(self, eventType: AudioHardwareEvent.self, dispatchQueue: DispatchQueue.main)

    // listen for accessibility status changes
    accessibilityObserver = DistributedNotificationCenter.default().addObserver(forName: .accessibilityApi, object: nil, queue: nil) { _ in
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        self.startOrRestartMediaKeyTap()
      }
    }
  }
}

// MARK: - Media Key Tap delegate

extension AppDelegate: MediaKeyTapDelegate {
  func handle(mediaKey: MediaKey, event _: KeyEvent?) {
    guard let currentDisplay = Utils.getCurrentDisplay(from: displays) else { return }

    let allDisplays = prefs.bool(forKey: Utils.PrefKeys.allScreens.rawValue) ? self.displays : [currentDisplay]

    for display in allDisplays {
      if (prefs.object(forKey: "\(display.identifier)-state") as? Bool) ?? true {
        switch mediaKey {
        case .brightnessUp:
          let value = display.calcNewValue(for: .brightness, withRel: +self.step)
          display.setBrightness(to: value)
        case .brightnessDown:
          let value = currentDisplay.calcNewValue(for: .brightness, withRel: -self.step)
          display.setBrightness(to: value)
        case .mute:
          display.mute()
        case .volumeUp:
          let value = display.calcNewValue(for: .audioSpeakerVolume, withRel: +self.step)
          display.setVolume(to: value)
        case .volumeDown:
          let value = display.calcNewValue(for: .audioSpeakerVolume, withRel: -self.step)
          display.setVolume(to: value)

        default:
          return
        }
      }
    }
  }

  // MARK: - Prefs notification

  @objc func handleListenForChanged() {
    self.startOrRestartMediaKeyTap()
  }

  @objc func handleShowContrastChanged() {
    self.updateDisplays()
  }

  @objc func handleFriendlyNameChanged() {
    self.updateDisplays()
  }

  private func startOrRestartMediaKeyTap() {
    var keys: [MediaKey]

    switch prefs.integer(forKey: Utils.PrefKeys.listenFor.rawValue) {
    case Utils.ListenForKeys.brightnessOnlyKeys.rawValue:
      keys = [.brightnessUp, .brightnessDown]
    case Utils.ListenForKeys.volumeOnlyKeys.rawValue:
      keys = [.mute, .volumeUp, .volumeDown]
    default:
      keys = [.brightnessUp, .brightnessDown, .mute, .volumeUp, .volumeDown]
    }

    if let audioDevice = AudioDevice.defaultOutputDevice(), audioDevice.canSetVirtualMasterVolume(direction: .playback) {
      // Remove volume related keys.
      let keysToDelete: [MediaKey] = [.volumeUp, .volumeDown, .mute]
      keys.removeAll { keysToDelete.contains($0) }
    }

    self.mediaKeyTap?.stop()
    self.mediaKeyTap = MediaKeyTap(delegate: self, for: keys, observeBuiltIn: false)
    self.mediaKeyTap?.start()
  }
}

extension AppDelegate: EventSubscriber {
  /**
   Fires off when the default audio device changes.
   */
  func eventReceiver(_ event: Event) {
    if case let .defaultOutputDeviceChanged(audioDevice)? = event as? AudioHardwareEvent {
      #if DEBUG
        os_log("Default output device changed to “%{public}@”.", type: .info, audioDevice.name)
        os_log("Can device set its own volume? %{public}@", type: .info, audioDevice.canSetVirtualMasterVolume(direction: .playback).description)
      #endif

      self.startOrRestartMediaKeyTap()
    }
  }
}
