//
//  Display.swift
//  MonitorControl
//
//  Created by Guillaume BRODER on 02/01/2018.
//  Copyright © 2018 Mathew Kurian. All rights reserved.
//

import Cocoa

/// A display
struct Display {
	var identifier: CGDirectDisplayID
	var name: String
	var serial: String
	var isBuiltIn: Bool = false
}
