//
//  Display.swift
//  MonitorControl
//
//  Created by Guillaume BRODER on 02/01/2018.
//  MIT Licensed.
//

import Cocoa

/// A display
class Display {
	let identifier: CGDirectDisplayID
	let name: String
	let serial: String
	var isEnabled: Bool
	var isMuted: Bool = false
	var brightnessSliderHandler: SliderHandler?
	var volumeSliderHandler: SliderHandler?

	init(_ identifier: CGDirectDisplayID, name: String, serial: String, isEnabled: Bool = true) {
		self.identifier = identifier
		self.name = name
		self.serial = serial
		self.isEnabled = isEnabled
	}

	func mute() {
		var value = 0
		if isMuted {
			value = UserDefaults.standard.integer(forKey: "\(AUDIO_SPEAKER_VOLUME)-\(identifier)")
			isMuted = false
		} else {
			isMuted = true
		}

		Utils.ddcctl(monitor: identifier, command: AUDIO_SPEAKER_VOLUME, value: value)
		if let slider = volumeSliderHandler?.slider {
			slider.intValue = Int32(value)
		}
		showOsd(command: AUDIO_SPEAKER_VOLUME, value: value)
	}

	func setVolume(to value: Int) {
		if value > 0 {
			isMuted = false
		}

		Utils.ddcctl(monitor: identifier, command: AUDIO_SPEAKER_VOLUME, value: value)
		if let slider = volumeSliderHandler?.slider {
			slider.intValue = Int32(value)
		}
		showOsd(command: AUDIO_SPEAKER_VOLUME, value: value)
		saveValue(value, for: AUDIO_SPEAKER_VOLUME)
	}

	func setBrightness(to value: Int) {
		Utils.ddcctl(monitor: identifier, command: BRIGHTNESS, value: value)
		if let slider = brightnessSliderHandler?.slider {
			slider.intValue = Int32(value)
		}
		showOsd(command: BRIGHTNESS, value: value)
		saveValue(value, for: BRIGHTNESS)
	}

	func calcNewValue(for command: Int32, withRel rel: Int) -> Int {
		let currentValue = UserDefaults.standard.integer(forKey: "\(command)-\(identifier)")
		return max(0, min(100, currentValue + rel))
	}

	func saveValue(_ value: Int, for command: Int32) {
		UserDefaults.standard.set(value, forKey: "\(command)-\(identifier)")
	}

	private func showOsd(command: Int32, value: Int) {
		if let manager = OSDManager.sharedManager() as? OSDManager {
			var osdImage: Int64 = 1 // Brightness Image
			if command == AUDIO_SPEAKER_VOLUME {
				osdImage = 3 // Speaker image
				if isMuted {
					osdImage = 4 // Mute speaker
				}
			}
			let step = 100/16
			manager.showImage(osdImage,
							  onDisplayID: identifier,
							  priority: 0x1f4,
							  msecUntilFade: 2000,
							  filledChiclets: UInt32(value/step),
							  totalChiclets: UInt32(100/step),
							  locked: false)
		}
	}
}
