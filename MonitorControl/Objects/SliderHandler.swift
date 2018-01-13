//
//  SliderHandler.swift
//  MonitorControl
//
//  Created by Guillaume BRODER on 9/17/2017.
//  MIT Licensed. 2017.
//

import Cocoa

/// Handle the slider
class SliderHandler {
	var slider: NSSlider?
	var display: Display
	var command: Int32 = 0

	public init(display: Display, command: Int32) {
		self.display = display
		self.command = command
	}

	@objc func valueChanged(slider: NSSlider) {
		let snapInterval = 25
		let snapThreshold = 3

		var value = slider.integerValue

		let closest = (value + snapInterval / 2) / snapInterval * snapInterval
		if abs(closest - value) <= snapThreshold {
			value = closest
			slider.integerValue = value
		}

		Utils.sendCommand(command, toMonitor: display.identifier, withValue: value)
		display.saveValue(value, for: command)
	}
}
