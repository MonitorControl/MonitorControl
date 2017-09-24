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

struct Display {
    var id: CGDirectDisplayID
    var name: String
    var serial: String
}

var app: AppDelegate! = nil
let prefs = UserDefaults.standard

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    @IBOutlet weak var statusMenu: NSMenu!
    @IBOutlet weak var window: NSWindow!
    
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    var monitorItems: [NSMenuItem] = []
    var displays: [Display] = []
    var sliderHandlers: [SliderHandler] = []

    var defaultDisplay: Display! = nil
    var defaultBrightnessSlider: NSSlider! = nil
    var defaultVolumeSlider: NSSlider! = nil

	let step = 100/16;

    @IBAction func quitClicked(_ sender: AnyObject) {
        NSApplication.shared.terminate(self)
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        app = self

		statusItem.image = NSImage.init(named: NSImage.Name(rawValue: "status"))
        statusItem.menu = statusMenu

        acquirePrivileges()

        CGDisplayRegisterReconfigurationCallback({_,_,_ in app.updateDisplays()}, nil)
        updateDisplays()

        NSEvent.addGlobalMonitorForEvents(
            matching: NSEvent.EventTypeMask.keyDown, handler: {(event: NSEvent) in
                if self.defaultDisplay == nil {
                    return
                }

				// Keyboard shortcut only for main screen
				let currentDisplayId = NSScreen.main?.deviceDescription[NSDeviceDescriptionKey.init("NSScreenNumber")] as! CGDirectDisplayID
				if (self.defaultDisplay.id != currentDisplayId) {
					return
				}

				// Brightness -> Shift + Control + Alt + Command + (Up/Down)
				// Volume -> Shift + Control + Alt + Command + (Left/Right)
				// Mute -> Minus

				// Capture keys
				let modifiers = NSEvent.ModifierFlags.init(rawValue: NSEvent.ModifierFlags.shift.rawValue | NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.control.rawValue | NSEvent.ModifierFlags.option.rawValue)
				let flags = event.modifierFlags.intersection(modifiers)

				// Only do something if all modifiers are active
				if !flags.contains(NSEvent.ModifierFlags.shift) || !flags.contains(NSEvent.ModifierFlags.command) || !flags.contains(NSEvent.ModifierFlags.control) || !flags.contains(NSEvent.ModifierFlags.option) {
					return
				}

                var brightnessRel = 0
				var volumeRel = 0
				var rel = 0

				// Down key
                if event.keyCode == Utils.key.keyDownArrow.rawValue {
                    brightnessRel = -self.step
				// Up key
                } else if event.keyCode == Utils.key.keyUpArrow.rawValue {
                    brightnessRel = +self.step
				// Left key
                } else if event.keyCode == Utils.key.keyLeftArrow.rawValue {
					volumeRel = -self.step
				// Right key
				} else if event.keyCode == Utils.key.keyRightArrow.rawValue {
					volumeRel = +self.step
				// M key
				} else if event.keyCode == Utils.key.keyMute.rawValue {
					volumeRel = -100
				} else {
                    return
                }

                var command = Int32()
                var slider: NSSlider! = nil
                if brightnessRel == 0 {
                    command = AUDIO_SPEAKER_VOLUME
                    slider = self.defaultVolumeSlider
					rel = volumeRel
                } else if volumeRel == 0 {
                    command = BRIGHTNESS
                    slider = self.defaultBrightnessSlider
					rel = brightnessRel
                } else {
                    return
                }

                let k = "\(command)-\(self.defaultDisplay.serial)"
                let value = max(0, min(100, prefs.integer(forKey: k) + rel))

                prefs.setValue(value, forKey: k)
                prefs.synchronize()
                slider.intValue = Int32(value)

                Utils.ddcctl(monitor: self.defaultDisplay.id, command: command, value: value)

				// OSD
				let manager : OSDManager = OSDManager.sharedManager() as! OSDManager
				var osdImage : Int = 1 // Brightness Image
				if brightnessRel == 0 {
					osdImage = 3 // Speaker image
					if value == 0 {
						osdImage = 4 // Mute speaker
					}
				}
				manager.showImage(Int64(osdImage), onDisplayID: self.defaultDisplay.id, priority: 0x1f4, msecUntilFade: 2000, filledChiclets: UInt32(value/self.step), totalChiclets: UInt32(100/self.step), locked: false)
        })
    }

    func addSliderItem(menu: NSMenu, isDefaultDisplay: Bool, display: Display, command: Int32, title: String) -> NSSlider {
        let item = NSMenuItem()

        let view = NSView(frame: NSRect(x: 0, y: 5, width: 250, height: 40))

        let label = Utils.makeLabel(text: title, frame: NSRect(x: 20, y: 19, width: 130, height: 20))

        let handler = SliderHandler(display: display, command: command)
        sliderHandlers.append(handler)

        let slider = NSSlider(frame: NSRect(x: 20, y: 0, width: 200, height: 19))
        slider.target = handler
        slider.minValue = 0
        slider.maxValue = 100
        slider.integerValue = prefs.integer(forKey: "\(command)-\(display.serial)")
		slider.action = #selector(SliderHandler.valueChanged)

        view.addSubview(label)
        view.addSubview(slider)

        item.view = view
 
        menu.addItem(item)
        menu.addItem(NSMenuItem.separator())

        return slider
    }

    func updateDisplays() {
        defaultDisplay = nil
        defaultBrightnessSlider = nil
        defaultVolumeSlider = nil

        for m in monitorItems {
            statusMenu.removeItem(m)
        }

        monitorItems = []
        displays = []
        sliderHandlers = []

        sleep(1)

        for s in NSScreen.screens {
            let id = s.deviceDescription[NSDeviceDescriptionKey.init("NSScreenNumber")] as! CGDirectDisplayID
            if CGDisplayIsBuiltin(id) != 0 {
                continue
            }

            var edid = EDID()
            if !EDIDTest(id, &edid) {
                continue
            }

            let name = getDisplayName(edid)
            let serial = getDisplaySerial(edid)

            let isDefaultDisplay = defaultDisplay == nil

            let d = Display(id: id, name: name, serial: serial)
            displays.append(d)

            let monitorMenuItem = NSMenuItem()
            let monitorSubMenu = NSMenu()

            let brightnessSlider = addSliderItem(menu: monitorSubMenu, isDefaultDisplay: isDefaultDisplay, display: d, command: BRIGHTNESS, title: NSLocalizedString("Brightness", comment: "Sown in menu"))
            let _ = addSliderItem(menu: monitorSubMenu, isDefaultDisplay: isDefaultDisplay, display: d, command: CONTRAST, title: NSLocalizedString("Contrast", comment: "Shown in menu"))
            let volumeSlider = addSliderItem(menu: monitorSubMenu, isDefaultDisplay: isDefaultDisplay, display: d, command: AUDIO_SPEAKER_VOLUME, title: NSLocalizedString("Volume", comment: "Shown in menu"))

            let defaultMonitorItem = NSMenuItem()
            let defaultMonitorView = NSView(frame: NSRect(x: 0, y: 5, width: 250, height: 25))

            let defaultMonitorSelectButtom = NSButton(frame: NSRect(x: 25, y: 0, width: 200, height: 25))
            defaultMonitorSelectButtom.title = isDefaultDisplay ? NSLocalizedString("Default", comment: "Shown in menu") : NSLocalizedString("Set as default", comment: "Shown in menu")
            defaultMonitorSelectButtom.bezelStyle = NSButton.BezelStyle.rounded
            defaultMonitorSelectButtom.isEnabled = !isDefaultDisplay

            defaultMonitorView.addSubview(defaultMonitorSelectButtom)

            defaultMonitorItem.view = defaultMonitorView

            monitorSubMenu.addItem(defaultMonitorItem)

            monitorMenuItem.title = "\(name)"
            monitorMenuItem.submenu = monitorSubMenu

            monitorItems.append(monitorMenuItem)
            statusMenu.insertItem(monitorMenuItem, at: displays.count - 1)

            if isDefaultDisplay {
                defaultDisplay = d
                defaultBrightnessSlider = brightnessSlider
                defaultVolumeSlider = volumeSlider
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
	
    func acquirePrivileges() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: true]
        let accessibilityEnabled = AXIsProcessTrustedWithOptions(options)
        
        if !accessibilityEnabled {
            print(NSLocalizedString("You need to enable the keylogger in the System Prefrences for the keyboard shortcuts to work", comment: ""))
        }
        
        return
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func edidString(_ d: descriptor) -> String {
        var s = ""
        for (_, b) in Mirror(reflecting: d.text.data).children {
            let b = b as! Int8
            let c = Character(UnicodeScalar(UInt8(bitPattern: b)))
            if c == "\0" || c == "\n" {
                break
            }
            s.append(c)
        }
        return s
    }

    func getDescriptorString(_ edid: EDID, _ type: UInt8) -> String? {
        for (_, d) in Mirror(reflecting: edid.descriptors).children {
            let d = d as! descriptor
            if d.text.type == UInt8(type) {
                return edidString(d)
            }
        }

        return nil
    }

    func getDisplayName(_ edid: EDID) -> String {
        return getDescriptorString(edid, 0xFC) ?? NSLocalizedString("Display", comment: "")
    }

    func getDisplaySerial(_ edid: EDID) -> String {
        return getDescriptorString(edid, 0xFF) ?? NSLocalizedString("Unknown", comment: "")
    }
}
