//
//  Preferences+Extension.swift
//  MonitorControl
//
//  Created by Joni Van Roost on 22/11/2020.
//  Copyright © 2020 MonitorControl. All rights reserved.
//

import Preferences

extension Preferences.PaneIdentifier {
  static let main = Self("Main")
  static let menusliders = Self("Menu & Sliders")
  static let keyboard = Self("Keyboard")
  static let advanced = Self("Advanced")
  static let displays = Self("Displays")
  static let about = Self("About")
}
