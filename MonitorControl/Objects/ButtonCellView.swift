//
//  ButtonCellView.swift
//  MonitorControl
//
//  Created by Guillaume BRODER on 07/01/2018.
//  Copyright © 2018 Mathew Kurian. All rights reserved.
//

import Cocoa

class ButtonCellView: NSTableCellView {

	@IBOutlet var button: NSButton!
	var display: Display?
	let prefs = UserDefaults.standard

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }

	@IBAction func buttonToggled(_ sender: NSButton) {
		if let display = display {
			switch sender.state {
			case .on:
				prefs.set(true, forKey: "\(display.identifier)-state")
			case .off:
				prefs.set(false, forKey: "\(display.identifier)-state")
			default:
				break
			}

			#if DEBUG
			print("Toggle enabled display state -> \(sender.state == .on ? "on" : "off")")
			#endif
		}
	}
}
