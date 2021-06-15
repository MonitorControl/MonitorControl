//
//  OSDUtils.swift
//  MonitorControl
//
//  Created by Victor Chabbert on 19/06/2020.
//  Copyright © 2020 MonitorControl. All rights reserved.
//

import Cocoa

class OSDUtils: NSObject {
  static let chicletCount: Float = 16

  static func chiclet(fromValue value: Float, maxValue: Float) -> Float {
    return (value * self.chicletCount) / maxValue
  }

  static func value(fromChiclet chiclet: Float, maxValue: Float) -> Float {
    return (chiclet * maxValue) / self.chicletCount
  }

  static func getDistance(fromNearestChiclet chiclet: Float) -> Float {
    return abs(chiclet.rounded(.towardZero) - chiclet)
  }
}
