//
//  Utils.swift
//  MonitorControl
//
//  Created by Guillaume BRODER on 9/17/2017.
//  MIT Licensed.
//

import Cocoa

class Utils: NSObject {
	
	/// Send command to ddcctl
	///
	/// - Parameters:
	///   - monitor: The id of the Monitor to send the command to
	///   - command: The command to send
	///   - value: the value of the command
	static func ddcctl(monitor: CGDirectDisplayID, command: Int32, value: Int) {
		var wrcmd = DDCWriteCommand(control_id: UInt8(command), new_value: UInt8(value))
		DDCWrite(monitor, &wrcmd)
		print(value)
	}
	
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


	/// Enum for hardware independent keyCode
	///
	/// - keyLeftArrow: keyCode for the left arrow
	/// - keyRightArrow: keyCode for the right arrow
	/// - keyDownArrow: keyCode for the down arrow
	/// - keyUpArrow: keyCode for the up arrow
	enum key : Int {
		case keyLeftArrow = 123
		case keyRightArrow = 124
		case keyDownArrow = 125
		case keyUpArrow = 126
		case keyMute = 24
	}
}
