//
//  Display.swift
//  MonitorControl
//
//  Created by Joni Van Roost on 24/01/2020.
//  Copyright © 2020 Guillaume Broder. All rights reserved.
//

import DDC
import Foundation
import os.log

class Display {
  internal let identifier: CGDirectDisplayID
  internal let name: String
  internal var vendorNumber: UInt32?
  internal var modelNumber: UInt32?
  internal var isEnabled: Bool {
    get {
      return self.prefs.object(forKey: "\(self.identifier)-state") as? Bool ?? true
    }
    set {
      self.prefs.set(newValue, forKey: "\(self.identifier)-state")
    }
  }

  private let prefs = UserDefaults.standard

  internal init(_ identifier: CGDirectDisplayID, name: String, vendorNumber: UInt32?, modelNumber: UInt32?) {
    self.identifier = identifier
    self.name = name
    self.vendorNumber = vendorNumber
    self.modelNumber = modelNumber
  }

  func stepBrightness(isUp _: Bool, isSmallIncrement _: Bool) {}

  func setFriendlyName(_ value: String) {
    self.prefs.set(value, forKey: "friendlyName-\(self.identifier)")
  }

  func getFriendlyName() -> String {
    return self.prefs.string(forKey: "friendlyName-\(self.identifier)") ?? self.name
  }

  func showOsd(command: DDC.Command, value: Int, maxValue: Int = 100, roundChiclet: Bool = false) {
    guard let manager = OSDManager.sharedManager() as? OSDManager else {
      return
    }

    var osdImage: Int64!
    switch command {
    case .brightness:
      osdImage = 1 // Brightness Image
    case .audioSpeakerVolume:
      osdImage = 3 // Speaker image
    case .audioMuteScreenBlank:
      osdImage = 4 // Mute image
    default:
      osdImage = 1
    }

    if roundChiclet {
      let osdChiclet = OSDUtils.chiclet(fromValue: Float(value), maxValue: Float(maxValue))
      let filledChiclets = round(osdChiclet)

      manager.showImage(osdImage,
                        onDisplayID: self.identifier,
                        priority: 0x1F4,
                        msecUntilFade: 1000,
                        filledChiclets: UInt32(filledChiclets),
                        totalChiclets: UInt32(16),
                        locked: false)
    } else {
      manager.showImage(osdImage,
                        onDisplayID: self.identifier,
                        priority: 0x1F4,
                        msecUntilFade: 1000,
                        filledChiclets: UInt32(value),
                        totalChiclets: UInt32(maxValue),
                        locked: false)
    }
  }
}
