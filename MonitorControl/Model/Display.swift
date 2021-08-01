//
//  Display.swift
//  MonitorControl
//
//  Created by Joni Van Roost on 24/01/2020.
//  Copyright © 2020 MonitorControl. All rights reserved.
//

import DDC
import Foundation
import os.log

private enum OSDImage: Int64 {
  case brightness = 1
  case audioSpeaker = 3
  case audioSpeakerMuted = 4
}

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

  var isVirtual: Bool = false

  private let prefs = UserDefaults.standard

  internal init(_ identifier: CGDirectDisplayID, name: String, vendorNumber: UInt32?, modelNumber: UInt32?, isVirtual _: Bool = false) {
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

    var osdImage: OSDImage
    switch command {
    case .audioSpeakerVolume:
      osdImage = value > 0 ? .audioSpeaker : .audioSpeakerMuted
    case .audioMuteScreenBlank:
      osdImage = .audioSpeakerMuted
    default:
      osdImage = .brightness
    }

    let filledChiclets: Int
    let totalChiclets: Int

    if roundChiclet {
      let osdChiclet = OSDUtils.chiclet(fromValue: Float(value), maxValue: Float(maxValue))

      filledChiclets = Int(round(osdChiclet))
      totalChiclets = 16
    } else {
      filledChiclets = value
      totalChiclets = maxValue
    }

    manager.showImage(osdImage.rawValue,
                      onDisplayID: self.identifier,
                      priority: 0x1F4,
                      msecUntilFade: 1000,
                      filledChiclets: UInt32(filledChiclets),
                      totalChiclets: UInt32(totalChiclets),
                      locked: false)
  }
}
