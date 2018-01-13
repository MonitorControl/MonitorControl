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

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        app = self
		mediaKeyTap = MediaKeyTap.init(delegate: self, forKeys: [.brightnessUp, .brightnessDown, .mute, .volumeUp, .volumeDown], observeBuiltIn: false)
		let storyboard: NSStoryboard = NSStoryboard.init(name: NSStoryboard.Name(rawValue: "Main"), bundle: Bundle.main)
		let views = [
			storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "MainPrefsVC")),
			storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "KeysPrefsVC")),
			storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "DisplayPrefsVC"))
		]
		prefsController = MASPreferencesWindowController(viewControllers: views, title: NSLocalizedString("Preferences", comment: "Shown in Preferences window"))

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
			prefsController.window?.makeKeyAndOrderFront(sender)
		}
	}

	/// Set the default prefs of the app
	func setDefaultPrefs() {
		let prefs = UserDefaults.standard
		if !prefs.bool(forKey: Utils.PrefKeys.appAlreadyLaunched.rawValue) {
			prefs.set(true, forKey: Utils.PrefKeys.appAlreadyLaunched.rawValue)

			prefs.set(false, forKey: Utils.PrefKeys.startAtLogin.rawValue)
			prefs.set(true, forKey: Utils.PrefKeys.startWhenExternal.rawValue)
		}
	}

	// MARK: - Menu

	func clearDisplays() {
		for monitor in monitorItems {
			statusMenu.removeItem(monitor)
		}

		monitorItems = []
		displays = []
	}

    func updateDisplays() {
		clearDisplays()
        sleep(1)

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

	func handle(mediaKey: MediaKey, event: KeyEvent) {
		guard let currentDisplay = Utils.getCurrentDisplay(from: displays) else { return }
		var rel = 0

		switch mediaKey {
		case .brightnessUp:
			rel = +self.step
			let value = currentDisplay.calcNewValue(for: BRIGHTNESS, withRel: rel)
			currentDisplay.setBrightness(to: value)
		case .brightnessDown:
			rel = -self.step
			let value = currentDisplay.calcNewValue(for: BRIGHTNESS, withRel: rel)
			currentDisplay.setBrightness(to: value)
		case .mute:
			currentDisplay.mute()
		case .volumeUp:
			rel = +self.step
			let value = currentDisplay.calcNewValue(for: AUDIO_SPEAKER_VOLUME, withRel: rel)
			currentDisplay.setVolume(to: value)
		case .volumeDown:
			rel = -self.step
			let value = currentDisplay.calcNewValue(for: AUDIO_SPEAKER_VOLUME, withRel: rel)
			currentDisplay.setVolume(to: value)
		default:
			return
		}

	}

}
