//
//  AppDelegate.swift
//  MonitorControl
//
//  Created by Mathew Kurian on 9/26/16.
//  Last edited by Guillaume Broder on 9/17/2017
//  MIT Licensed. 2017.
//

import Cocoa
import Foundation
import MediaKeyTap
import MASPreferences

var app: AppDelegate! = nil
let prefs = UserDefaults.standard

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, MediaKeyTapDelegate {

    @IBOutlet weak var statusMenu: NSMenu!
    @IBOutlet weak var window: NSWindow!

    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    var monitorItems: [NSMenuItem] = []
    var displays: [Display] = []

	let step = 100/16

	var mediaKeyTap: MediaKeyTap?
	var prefsController: NSWindowController?

	var keysListenedFor: [MediaKey] = [.brightnessUp, .brightnessDown, .mute, .volumeUp, .volumeDown]

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        app = self

		let listenFor = prefs.integer(forKey: Utils.PrefKeys.listenFor.rawValue)
		if listenFor == Utils.ListenForKeys.brightnessOnlyKeys.rawValue {
			keysListenedFor.removeSubrange(2...4)
		} else if listenFor == Utils.ListenForKeys.volumeOnlyKeys.rawValue {
			keysListenedFor.removeSubrange(0...1)
		}

		mediaKeyTap = MediaKeyTap.init(delegate: self, for: keysListenedFor, observeBuiltIn: false)
		let storyboard: NSStoryboard = NSStoryboard.init(name: NSStoryboard.Name(rawValue: "Main"), bundle: Bundle.main)
		let views = [
			storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "MainPrefsVC")),
			storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "KeysPrefsVC")),
			storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "DisplayPrefsVC"))
		]
		prefsController = MASPreferencesWindowController(viewControllers: views, title: NSLocalizedString("Preferences", comment: "Shown in Preferences window"))

		NotificationCenter.default.addObserver(self, selector: #selector(handleListenForChanged), name: NSNotification.Name.init(Utils.PrefKeys.listenFor.rawValue), object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleShowContrastChanged), name: NSNotification.Name.init(Utils.PrefKeys.showContrast.rawValue), object: nil)

		statusItem.image = NSImage.init(named: NSImage.Name(rawValue: "status"))
        statusItem.menu = statusMenu

		setDefaultPrefs()

        Utils.acquirePrivileges()

        CGDisplayRegisterReconfigurationCallback({_, _, _ in app.updateDisplays()}, nil)
        updateDisplays()

		mediaKeyTap?.start()
    }

	func applicationWillTerminate(_ aNotification: Notification) {
	}

	@IBAction func quitClicked(_ sender: AnyObject) {
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
		if statusMenu.items.count > 2 {
			var items: [NSMenuItem] = []
			for i in 0..<statusMenu.items.count - 2 {
				items.append(statusMenu.items[i])
			}

			for item in items {
				statusMenu.removeItem(item)
			}
		}

		monitorItems = []
		displays = []
	}

    func updateDisplays() {
		clearDisplays()

		var filteredScreens = NSScreen.screens.filter { screen -> Bool in
			if let id = screen.deviceDescription[NSDeviceDescriptionKey.init("NSScreenNumber")] as? CGDirectDisplayID {
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
            monitorItems.append(item)
            statusMenu.insertItem(item, at: 0)
        }
    }

	/// Add a screen to the menu
	///
	/// - Parameters:
	///   - screen: The screen to add
	///   - asSubMenu: Display in a sub menu or directly in menu
	private func addScreenToMenu(screen: NSScreen, asSubMenu: Bool) {
		if let id = screen.deviceDescription[NSDeviceDescriptionKey.init("NSScreenNumber")] as? CGDirectDisplayID {

			var edid = EDID()
			if EDIDTest(id, &edid) {
				let name = Utils.getDisplayName(forEdid: edid)
				let serial = Utils.getDisplaySerial(forEdid: edid)

				let display = Display.init(id, name: name, serial: serial)

				let monitorSubMenu: NSMenu = asSubMenu ? NSMenu() : statusMenu
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
				displays.append(display)

				let monitorMenuItem = NSMenuItem()
				monitorMenuItem.title = "\(name)"
				if asSubMenu {
					monitorMenuItem.submenu = monitorSubMenu
				}

				monitorItems.append(monitorMenuItem)
				statusMenu.insertItem(monitorMenuItem, at: 0)
			}
		}
	}

	// MARK: - Media Key Tap delegate

	func handle(mediaKey: MediaKey, event: KeyEvent?) {
		guard let currentDisplay = Utils.getCurrentDisplay(from: displays) else { return }
		let allDisplays = prefs.bool(forKey: Utils.PrefKeys.allScreens.rawValue) ? displays : [currentDisplay]
		for display in allDisplays {
			if (prefs.object(forKey: "\(display.identifier)-state") as? Bool) ?? true {
				switch mediaKey {
				case .brightnessUp:
					let value = display.calcNewValue(for: BRIGHTNESS, withRel: +step)
					display.setBrightness(to: value)
				case .brightnessDown:
					let value = currentDisplay.calcNewValue(for: BRIGHTNESS, withRel: -step)
					display.setBrightness(to: value)
				case .mute:
					display.mute()
				case .volumeUp:
					let value = display.calcNewValue(for: AUDIO_SPEAKER_VOLUME, withRel: +step)
					display.setVolume(to: value)
				case .volumeDown:
					let value = display.calcNewValue(for: AUDIO_SPEAKER_VOLUME, withRel: -step)
					display.setVolume(to: value)
				default:
					return
				}
			}
		}

	}

	// MARK: - Prefs notification

	@objc func handleListenForChanged() {
		let listenFor = prefs.integer(forKey: Utils.PrefKeys.listenFor.rawValue)
		keysListenedFor = [.brightnessUp, .brightnessDown, .mute, .volumeUp, .volumeDown]
		if listenFor == Utils.ListenForKeys.brightnessOnlyKeys.rawValue {
			keysListenedFor.removeSubrange(2...4)
		} else if listenFor == Utils.ListenForKeys.volumeOnlyKeys.rawValue {
			keysListenedFor.removeSubrange(0...1)
		}

		mediaKeyTap?.stop()
		mediaKeyTap = MediaKeyTap.init(delegate: self, for: keysListenedFor, observeBuiltIn: false)
		mediaKeyTap?.start()
	}

	@objc func handleShowContrastChanged() {
		self.updateDisplays()
	}

}
