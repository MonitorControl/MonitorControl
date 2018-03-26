//
//  Utils.swift
//  MonitorControl
//
//  Created by Guillaume BRODER on 9/17/2017.
//  MIT Licensed.
//

import Cocoa

class Utils: NSObject {
	private static func printCommandValue(_ command: Int32, _ value: Int) {
		let cmdString: (Int32) -> String? = {
			switch $0 {
			case BRIGHTNESS:
				return "Brightness"
			case CONTRAST:
				return "Contrast"
			case AUDIO_SPEAKER_VOLUME:
				return "Volume"
			default:
				return nil
			}
		}

		print("\(cmdString(command) ?? "N/A") value: \(value)")
	}

	// MARK: - DDCCTL

	/// Send command to ddcctl
	///
	/// - Parameters:
	///   - command: The command to send
	///   - monitor: The id of the Monitor to send the command to
	///   - value: the value of the command
	static func sendCommand(_ command: Int32, toMonitor monitor: CGDirectDisplayID, withValue value: Int) {
		var wrcmd = DDCWriteCommand(control_id: UInt8(command), new_value: UInt8(value))
		DDCWrite(monitor, &wrcmd)

		#if DEBUG
		printCommandValue(command, value)
		#endif
	}

	/// Get current value of ddcctl command
	///
	/// - Parameters:
	///   - command: The command to send
	///   - monitor: The id of the monitor to send the command to
	/// - Returns: the value of the command
	static func getCommand(_ command: Int32, fromMonitor monitor: CGDirectDisplayID) -> Int? {
		var readCmd = DDCReadCommand()
		readCmd.control_id = UInt8(command)
		readCmd.max_value = 0
		readCmd.current_value = 0
		DDCRead(monitor, &readCmd)

		#if DEBUG
		printCommandValue(command, Int(readCmd.current_value))
		#endif

		return readCmd.success ? Int(readCmd.current_value) : nil
	}

	// MARK: - Menu

	/// Create a label
	///
	/// - Parameters:
	///   - text: The text of the label
	///   - frame: The frame of the label
	/// - Returns: An `NSTextField` label
	static func makeLabel(text: String, frame: NSRect) -> NSTextField {
		let label = NSTextField(frame: frame)
		label.stringValue = text
		label.isBordered = false
		label.isBezeled = false
		label.isEditable = false
		label.drawsBackground = false
		return label
	}

	/// Create a slider and add it to the menu
	///
	/// - Parameters:
	///   - menu: Menu containing the slider
	///   - display: Display to control
	///   - command: Command (Brightness/Volume/...)
	///   - title: Title of the slider
	/// - Returns: An `NSSlider` slider
	static func addSliderMenuItem(toMenu menu: NSMenu, forDisplay display: Display, command: Int32, title: String) -> SliderHandler {
		let item = NSMenuItem()
		let view = NSView(frame: NSRect(x: 0, y: 5, width: 250, height: 40))
		let label = Utils.makeLabel(text: title, frame: NSRect(x: 20, y: 19, width: 130, height: 20))
		let handler = SliderHandler(display: display, command: command)
		let slider = NSSlider(frame: NSRect(x: 20, y: 0, width: 200, height: 19))
		slider.target = handler
		slider.minValue = 0
		slider.maxValue = 100
		slider.action = #selector(SliderHandler.valueChanged)
		handler.slider = slider

		view.addSubview(label)
		view.addSubview(slider)

		item.view = view

		menu.insertItem(item, at: 0)
		menu.insertItem(NSMenuItem.separator(), at: 1)

		DispatchQueue.global(qos: .background).async {
			var val: Int?

			for _ in 0...100 {
				if let res = getCommand(command, fromMonitor: display.identifier) {
					val = res
					break
				}
				usleep(40000)
			}

			if let val = val {
				display.saveValue(val, for: command)

				DispatchQueue.main.async {
				 slider.integerValue = val
				}
			}
		}

		return handler
	}

	// MARK: - Utilities

	/// Acquire Privileges (Necessary to listen to keyboard event globally)
	static func acquirePrivileges() {
		let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: true]
		let accessibilityEnabled = AXIsProcessTrustedWithOptions(options)

		if !accessibilityEnabled {
			let alert = NSAlert()
			alert.addButton(withTitle: NSLocalizedString("Ok", comment: "Shown in the alert dialog"))
			alert.messageText = NSLocalizedString("Shortcuts not available", comment: "Shown in the alert dialog")
			alert.informativeText = NSLocalizedString("You need to enable MonitorControl in System Preferences > Security and Privacy > Accessibility for the keyboard shortcuts to work", comment: "Shown in the alert dialog")
			alert.alertStyle = .warning
			alert.runModal()
		}

		return
	}

	// MARK: - Display Infos

	/// Get the descriptor text
	///
	/// - Parameter descriptor: the descriptor
	/// - Returns: a string
	static func getEdidString(_ descriptor: descriptor) -> String {
		var result = ""
		for (_, bitChar) in Mirror(reflecting: descriptor.text.data).children {
			if let bitChar = bitChar as? Int8 {
				let char = Character(UnicodeScalar(UInt8(bitPattern: bitChar)))
				if char == "\0" || char == "\n" {
					break
				}
				result.append(char)
			}
		}
		return result
	}

	/// Get the descriptors of a display from the Edid
	///
	/// - Parameters:
	///   - edid: the EDID of a display
	///   - type: the type of descriptor
	/// - Returns: a string if type of descriptor is found
	static func getDescriptorString(_ edid: EDID, _ type: UInt8) -> String? {
		for (_, descriptor) in Mirror(reflecting: edid.descriptors).children {
			if let descriptor = descriptor as? descriptor {
				if descriptor.text.type == UInt8(type) {
					return getEdidString(descriptor)
				}
			}
		}

		return nil
	}

	/// Get the name of a display
	///
	/// - Parameter edid: the EDID of a display
	/// - Returns: a string
	static func getDisplayName(forEdid edid: EDID) -> String {
		return getDescriptorString(edid, 0xFC) ?? NSLocalizedString("Display", comment: "")
	}

	/// Get the serial of a display
	///
	/// - Parameter edid: the EDID of a display
	/// - Returns: a string
	static func getDisplaySerial(forEdid edid: EDID) -> String {
		return getDescriptorString(edid, 0xFF) ?? NSLocalizedString("Unknown", comment: "")
	}

	/// Get the main display from a list of display
	///
	/// - Parameter displays: List of Display
	/// - Returns: the main display or nil if not found
	static func getCurrentDisplay(from displays: [Display]) -> Display? {
		return displays.first { display -> Bool in
			if let main = NSScreen.main {
				if let id = main.deviceDescription[NSDeviceDescriptionKey.init("NSScreenNumber")] as? CGDirectDisplayID {
					return display.identifier == id
				}
			}
			return false
		}
	}

	// MARK: - Enums

	/// UserDefault Keys for the app prefs
	enum PrefKeys: String {
		/// Was the app launched once
		case appAlreadyLaunched

		/// Does the app start at Login
		case startAtLogin

		/// Does the app start when plugged to an external monitor
		case startWhenExternal

		/// Keys listened for (Brightness/Volume)
		case listenFor

		/// Show contrast sliders
		case showContrast

		/// Lower contrast after brightness
		case lowerContrast

		/// Change Brightness/Volume for all screens
		case allScreens
	}

	/// Keys for the value of listenFor option
	enum ListenForKeys: Int {
		/// Listen for Brightness and Volume keys
		case brightnessAndVolumeKeys = 0

		/// Listen for Brightness keys only
		case brightnessOnlyKeys = 1

		/// Listen for Volume keys only
		case volumeOnlyKeys = 2
	}

}
