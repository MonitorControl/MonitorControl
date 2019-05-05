//
//  AppDelegate.swift
//  MonitorControl
//
//  Created by Mathew Kurian on 9/26/16.
//  Last edited by Guillaume Broder on 9/17/2017
//  MIT Licensed. 2017.
//

import AMCoreAudio
import Cocoa
import Foundation
import MASPreferences
import MediaKeyTap

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

  var keysListenedFor: [MediaKey] = [.brightnessUp, .brightnessDown, .mute, .volumeUp, .volumeDown]

  func applicationDidFinishLaunching(_: Notification) {
    app = self

    self.setupLayout()
    self.subscribeEventListeners()
    setVolumeKeysMode()
    self.statusItem.image = NSImage(named: "status")
    self.statusItem.menu = self.statusMenu
    self.setDefaultPrefs()
    Utils.acquirePrivileges()
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
    let prefs = UserDefaults.standard
    if !prefs.bool(forKey: Utils.PrefKeys.appAlreadyLaunched.rawValue) {
      prefs.set(true, forKey: Utils.PrefKeys.appAlreadyLaunched.rawValue)

      prefs.set(false, forKey: Utils.PrefKeys.startAtLogin.rawValue)

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

    var filteredScreens = NSScreen.screens.filter { screen -> Bool in
      if let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID {
        // Is Built In Screen (e.g. MBP/iMac Screen)
        if CGDisplayIsBuiltin(id) != 0 {
          return false
        }

        // Does screen support EDID ?
        var edid = EDID()
        if !EDIDTest(id, &edid) {
          return false
        }

        return true
      }
      return false
    }

    if filteredScreens.count == 1 {
      self.addScreenToMenu(screen: filteredScreens[0], asSubMenu: false)
    } else {
      for screen in filteredScreens {
        self.addScreenToMenu(screen: screen, asSubMenu: true)
      }
    }

    if filteredScreens.count == 0 {
      // If no DDC capable display was detected
      let item = NSMenuItem()
      item.title = NSLocalizedString("No supported display found", comment: "Shown in menu")
      item.isEnabled = false
      self.monitorItems.append(item)
      self.statusMenu.insertItem(item, at: 0)
    }
  }

  /// Add a screen to the menu
  ///
  /// - Parameters:
  ///   - screen: The screen to add
  ///   - asSubMenu: Display in a sub menu or directly in menu
  private func addScreenToMenu(screen: NSScreen, asSubMenu: Bool) {
    if let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID {
      var edid = EDID()
      if EDIDTest(id, &edid) {
        let name = Utils.getDisplayName(forEdid: edid)
        let serial = Utils.getDisplaySerial(forEdid: edid)

        let display = Display(id, name: name, serial: serial)

        let monitorSubMenu: NSMenu = asSubMenu ? NSMenu() : self.statusMenu
        let volumeSliderHandler = Utils.addSliderMenuItem(toMenu: monitorSubMenu,
                                                          forDisplay: display,
                                                          command: AUDIO_SPEAKER_VOLUME,
                                                          title: NSLocalizedString("Volume", comment: "Shown in menu"))
        let brightnessSliderHandler = Utils.addSliderMenuItem(toMenu: monitorSubMenu,
                                                              forDisplay: display,
                                                              command: BRIGHTNESS,
                                                              title: NSLocalizedString("Brightness", comment: "Shown in menu"))
        if prefs.bool(forKey: Utils.PrefKeys.showContrast.rawValue) {
          let contrastSliderHandler = Utils.addSliderMenuItem(toMenu: monitorSubMenu,
                                                              forDisplay: display,
                                                              command: CONTRAST,
                                                              title: NSLocalizedString("Contrast", comment: "Shown in menu"))
          display.contrastSliderHandler = contrastSliderHandler
        }

        display.volumeSliderHandler = volumeSliderHandler
        display.brightnessSliderHandler = brightnessSliderHandler
        self.displays.append(display)

        let monitorMenuItem = NSMenuItem()
        monitorMenuItem.title = "\(name)"
        if asSubMenu {
          monitorMenuItem.submenu = monitorSubMenu
        }

        self.monitorItems.append(monitorMenuItem)
        self.statusMenu.insertItem(monitorMenuItem, at: 0)
      }
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

    // subscribe Audio output detector (AMCoreAudio)
    NotificationCenter.defaultCenter.subscribe(self, eventType: AudioHardwareEvent.self, dispatchQueue: DispatchQueue.main)
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
          let value = display.calcNewValue(for: BRIGHTNESS, withRel: +self.step)
          display.setBrightness(to: value)
        case .brightnessDown:
          let value = currentDisplay.calcNewValue(for: BRIGHTNESS, withRel: -self.step)
          display.setBrightness(to: value)
        case .mute:
          display.mute()
        case .volumeUp:
          let value = display.calcNewValue(for: AUDIO_SPEAKER_VOLUME, withRel: +self.step)
          display.setVolume(to: value)
        case .volumeDown:
          let value = display.calcNewValue(for: AUDIO_SPEAKER_VOLUME, withRel: -self.step)
          display.setVolume(to: value)

        default:
          return
        }
      }
    }
  }

  // MARK: - Prefs notification

  @objc func handleListenForChanged() {
    self.readKeyListenPreferences()
    self.setKeysToListenFor()
  }

  @objc func handleShowContrastChanged() {
    self.updateDisplays()
  }

  private func setKeysToListenFor() {
    self.mediaKeyTap?.stop()
    self.mediaKeyTap = MediaKeyTap(delegate: self, for: self.keysListenedFor, observeBuiltIn: false)
    self.mediaKeyTap?.start()
  }

  private func readKeyListenPreferences() {
    let listenFor = prefs.integer(forKey: Utils.PrefKeys.listenFor.rawValue)

    self.keysListenedFor = [.brightnessUp, .brightnessDown, .mute, .volumeUp, .volumeDown]

    if listenFor == Utils.ListenForKeys.brightnessOnlyKeys.rawValue {
      self.keysListenedFor.removeSubrange(2...4)
    } else if listenFor == Utils.ListenForKeys.volumeOnlyKeys.rawValue {
      self.keysListenedFor.removeSubrange(0...1)
    }
  }
}

extension AppDelegate: EventSubscriber {
  /**
   Fires off when a change in default audio device is detected.
   */
  func eventReceiver(_ event: Event) {
    switch event {
    case let event as AudioHardwareEvent:
      switch event {
      case let .defaultOutputDeviceChanged(audioDevice):
        #if DEBUG
          print("Default output device changed to \(audioDevice)")
          print("Can device set its own volume? \(audioDevice.canSetVirtualMasterVolume(direction: .playback))")
        #endif
        self.setVolumeKeysMode()
      default: break
      }
    default: break
    }
  }

  /**
   We check if the current default audio output device can change the volume,
   if not, we know for sure that we don't need to interact with it.
   */
  func setVolumeKeysMode() {
    self.readKeyListenPreferences()

    if let defaultOutputDevice = AudioDevice.defaultOutputDevice() {
      if defaultOutputDevice.canSetVirtualMasterVolume(direction: .playback) {
        // Remove volume related keys
        let keysToDelete: [MediaKey] = [.volumeUp, .volumeDown, .mute]
        keysListenedFor = self.keysListenedFor.filter { !keysToDelete.contains($0) }
      } else {
        // load keys to listen to from prefs like normal
        self.readKeyListenPreferences()
      }
    }
    self.setKeysToListenFor()
  }
}
