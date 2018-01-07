//
//  Display.swift
//  MonitorControl
//
//  Created by Guillaume BRODER on 02/01/2018.
//  MIT Licensed.
//

import Cocoa

/// A display
struct Display {
	var identifier: CGDirectDisplayID
	var name: String
	var serial: String
	var isEnabled: Bool = true
}
