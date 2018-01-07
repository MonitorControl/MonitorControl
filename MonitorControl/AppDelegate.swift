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
	var sliderHandlers: [SliderHandler] = []

    var defaultDisplay: Display! = nil
    var defaultBrightnessSlider: NSSlider! = nil
    var defaultVolumeSlider: NSSlider! = nil

	let step = 100/16

	var mediaKeyTap: MediaKeyTap?
	var prefsController: NSWindowController?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        app = self
		mediaKeyTap = MediaKeyTap.init(delegate: self, forKeys: [.brightnessUp, .brightnessDown, .mute, .volumeUp, .volumeDown], observeBuiltIn: false)
		let storyboard: NSStoryboard = NSStoryboard.init(name: NSStoryboard.Name(rawValue: "Main"), bundle: Bundle.main)
		prefsController = MASPreferencesWindowController(viewControllers:
			[
				storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "MainPrefsVC")),
				storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "KeysPrefsVC")),
				storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "DisplayPrefsVC"))
			],
														 title: NSLocalizedString("Preferences", comment: "Shown in Preferences window"))

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
		defaultDisplay = nil
		defaultBrightnessSlider = nil
		defaultVolumeSlider = nil

		for monitor in monitorItems {
			statusMenu.removeItem(monitor)
		}

		monitorItems = []
		displays = []
		sliderHandlers = []
	}

    func updateDisplays() {
		clearDisplays()
        sleep(1)

        for screen in NSScreen.screens {
			if let id = screen.deviceDescription[NSDeviceDescriptionKey.init("NSScreenNumber")] as? CGDirectDisplayID {
				// Is Built In Screen (e.g. MBP/iMac Screen)
				if CGDisplayIsBuiltin(id) != 0 {
					continue
				}

				// Does screen support EDID ?
				var edid = EDID()
				if !EDIDTest(id, &edid) {
					continue
				}

				let name = Utils.getDisplayName(forEdid: edid)
				let serial = Utils.getDisplaySerial(forEdid: edid)

				let display = Display(identifier: id, name: name, serial: serial, isEnabled: true)
				displays.append(display)

				let monitorSubMenu = NSMenu()
				let brightnessSliderHandler = Utils.addSliderMenuItem(toMenu: monitorSubMenu,
													   forDisplay: display,
													   command: BRIGHTNESS,
													   title: NSLocalizedString("Brightness", comment: "Shown in menu"))
				let volumeSliderHandler = Utils.addSliderMenuItem(toMenu: monitorSubMenu,
												   forDisplay: display,
												   command: AUDIO_SPEAKER_VOLUME,
												   title: NSLocalizedString("Volume", comment: "Shown in menu"))
				sliderHandlers.append(brightnessSliderHandler)
				sliderHandlers.append(volumeSliderHandler)

				let isDefaultDisplay = defaultDisplay == nil
				let defaultMonitorSelectButtom = NSButton(frame: NSRect(x: 25, y: 0, width: 200, height: 25))
				defaultMonitorSelectButtom.title = isDefaultDisplay ? NSLocalizedString("Default", comment: "Shown in menu") : NSLocalizedString("Set as default", comment: "Shown in menu")
				defaultMonitorSelectButtom.bezelStyle = NSButton.BezelStyle.rounded
				defaultMonitorSelectButtom.isEnabled = !isDefaultDisplay

				let defaultMonitorView = NSView(frame: NSRect(x: 0, y: 5, width: 250, height: 25))
				defaultMonitorView.addSubview(defaultMonitorSelectButtom)

				let defaultMonitorItem = NSMenuItem()
				defaultMonitorItem.view = defaultMonitorView
				monitorSubMenu.addItem(defaultMonitorItem)

				let monitorMenuItem = NSMenuItem()
				monitorMenuItem.title = "\(name)"
				monitorMenuItem.submenu = monitorSubMenu

				monitorItems.append(monitorMenuItem)
				statusMenu.insertItem(monitorMenuItem, at: displays.count - 1)

				if isDefaultDisplay {
					defaultDisplay = display
					defaultBrightnessSlider = brightnessSliderHandler.slider
					defaultVolumeSlider = volumeSliderHandler.slider
				}
			}
        }

        if defaultDisplay == nil {
            // If no DDC capable display was detected
            let item = NSMenuItem()
            item.title = NSLocalizedString("No supported display found", comment: "Shown in menu")
            item.isEnabled = false
            monitorItems.append(item)
            statusMenu.insertItem(item, at: 0)
        }
    }

	// MARK: - Media Key Tap delegate

	func handle(mediaKey: MediaKey, event: KeyEvent) {

		var command = BRIGHTNESS
		var rel = 0
		var slider = self.defaultBrightnessSlider

		switch mediaKey {
		case .brightnessUp:
			rel = +self.step
		case .brightnessDown:
			rel = -self.step
		case .mute:
			rel = -100
			command = AUDIO_SPEAKER_VOLUME
			slider = self.defaultVolumeSlider
		case .volumeUp:
			rel = +self.step
			command = AUDIO_SPEAKER_VOLUME
			slider = self.defaultVolumeSlider
		case .volumeDown:
			rel = -self.step
			command = AUDIO_SPEAKER_VOLUME
			slider = self.defaultVolumeSlider
		default:
			return
		}

		let k = "\(command)-\(self.defaultDisplay.serial)"
		let value = max(0, min(100, prefs.integer(forKey: k) + rel))
		prefs.setValue(value, forKey: k)
		prefs.synchronize()

		if let slider = slider {
			slider.intValue = Int32(value)
		}

		Utils.ddcctl(monitor: self.defaultDisplay.identifier, command: command, value: value)

		// OSD
		if let manager = OSDManager.sharedManager() as? OSDManager {
			var osdImage: Int64 = 1 // Brightness Image
			if command == AUDIO_SPEAKER_VOLUME {
				osdImage = 3 // Speaker image
				if value == 0 {
					osdImage = 4 // Mute speaker
				}
			}
			manager.showImage(osdImage,
							  onDisplayID: self.defaultDisplay.identifier,
							  priority: 0x1f4,
							  msecUntilFade: 2000,
							  filledChiclets: UInt32(value/self.step),
							  totalChiclets: UInt32(100/self.step),
							  locked: false)
		}
	}

}
