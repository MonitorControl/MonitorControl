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

  internal init(_ identifier: CGDirectDisplayID, name: String, vendorNumber: UInt32?, modelNumber: UInt32?, isVirtual: Bool = false) {
    self.identifier = identifier
    self.name = name
    self.vendorNumber = vendorNumber
    self.modelNumber = modelNumber
    self.isVirtual = isVirtual
  }

  func stepBrightness(isUp _: Bool, isSmallIncrement _: Bool) {}

  func setFriendlyName(_ value: String) {
    self.prefs.set(value, forKey: "friendlyName-\(self.identifier)")
  }

  func getFriendlyName() -> String {
    return self.prefs.string(forKey: "friendlyName-\(self.identifier)") ?? self.name
  }

  func getShowOsdDisplayId() -> CGDirectDisplayID {
    if CGDisplayIsInHWMirrorSet(self.identifier) != 0 || CGDisplayIsInMirrorSet(self.identifier) != 0, CGDisplayMirrorsDisplay(self.identifier) != 0 {
      for mirrorMaestro in DisplayManager.shared.getAllNonVirtualDisplays() where CGDisplayMirrorsDisplay(self.identifier) == mirrorMaestro.identifier {
        if let externalMirrorMaestro = mirrorMaestro as? ExternalDisplay, externalMirrorMaestro.isSw() {
          var thereAreOthers = false
          for mirrorMember in DisplayManager.shared.getAllNonVirtualDisplays() where CGDisplayMirrorsDisplay(mirrorMember.identifier) == CGDisplayMirrorsDisplay(self.identifier) && mirrorMember.identifier != self.identifier {
            thereAreOthers = true
          }
          if !thereAreOthers {
            return externalMirrorMaestro.identifier
          }
        }
      }
    }
    return self.identifier
  }

  func setSwBrightness(value: UInt8) -> Bool {
    let brightnessValue: UInt8 = min(getSwMaxBrightness(), value)
    let floatValue = Float(Float(brightnessValue) / Float(self.getSwMaxBrightness()))
    if CGSetDisplayTransferByFormula(self.identifier, 0, floatValue, 1, 0, floatValue, 1, 0, floatValue, 1) == CGError.success {
      self.saveSwBirghtnessPrefValue(Int(brightnessValue))
      return true
    }
    return false
  }

  func getSwBrightness() -> UInt8 {
    var redMin: CGGammaValue = 0
    var redMax: CGGammaValue = 0
    var redGamma: CGGammaValue = 0
    var greenMin: CGGammaValue = 0
    var greenMax: CGGammaValue = 0
    var greenGamma: CGGammaValue = 0
    var blueMin: CGGammaValue = 0
    var blueMax: CGGammaValue = 0
    var blueGamma: CGGammaValue = 0
    if CGGetDisplayTransferByFormula(self.identifier, &redMin, &redMax, &redGamma, &greenMin, &greenMax, &greenGamma, &blueMin, &blueMax, &blueGamma) == CGError.success {
      let brightnessValue = UInt8(min(max(redMax, greenMax, blueMax), 1) * Float(self.getSwMaxBrightness()))
      return brightnessValue
    }
    return self.getSwMaxBrightness()
  }

  func saveSwBirghtnessPrefValue(_ value: Int) {
    self.prefs.set(value, forKey: "SwBrightness-\(self.identifier)")
  }

  func getSwBrightnessPrefValue() -> Int {
    return self.prefs.integer(forKey: "SwBrightness-\(self.identifier)")
  }

  func getSwMaxBrightness() -> UInt8 {
    return 100
  }

  func isSwBrightnessNotDefault() -> Bool {
    guard self.isVirtual else {
      return false
    }
    if self.getSwBrightness() < self.getSwMaxBrightness() {
      return true
    }
    return false
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
                      onDisplayID: self.getShowOsdDisplayId(),
                      priority: 0x1F4,
                      msecUntilFade: 1000,
                      filledChiclets: UInt32(filledChiclets),
                      totalChiclets: UInt32(totalChiclets),
                      locked: false)
  }
}
