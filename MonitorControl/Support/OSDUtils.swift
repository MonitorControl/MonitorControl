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

  static func showOSDLockOnAllDisplays(osdImage: Int64) {
    var displayCount: UInt32 = 0
    var onlineDisplays = [CGDirectDisplayID](repeating: 0, count: Int(16))
    if CGGetOnlineDisplayList(16, &onlineDisplays, &displayCount) == CGError.success {
      let displayIDs = onlineDisplays.prefix(Int(displayCount))
      for id in displayIDs {
        if let manager = OSDManager.sharedManager() as? OSDManager {
          manager.showImage(osdImage, onDisplayID: id, priority: 0x1F4, msecUntilFade: 1000, filledChiclets: 0, totalChiclets: 100, locked: true)
        }
      }
    }
  }
}
