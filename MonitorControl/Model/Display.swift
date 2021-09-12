//
//  Display.swift
//  MonitorControl
//
//  Created by Joni Van Roost on 24/01/2020.
//  Copyright © 2020 MonitorControl. All rights reserved.
//

import Foundation
import os.log

enum OSDImage: Int64 {
  case brightness = 1
  case audioSpeaker = 3
  case audioSpeakerMuted = 4
}

class Display {
  internal let identifier: CGDirectDisplayID
  internal let prefsId: String
  internal var name: String
  internal var vendorNumber: UInt32?
  internal var modelNumber: UInt32?
  internal var isEnabled: Bool {
    get {
      self.prefs.object(forKey: PrefKeys.state.rawValue + self.prefsId) as? Bool ?? true
    }
    set {
      self.prefs.set(newValue, forKey: PrefKeys.state.rawValue + self.prefsId)
    }
  }

  var forceSw: Bool {
    get {
      return self.prefs.bool(forKey: PrefKeys.forceSw.rawValue + self.prefsId)
    }
    set {
      self.prefs.set(newValue, forKey: PrefKeys.forceSw.rawValue + self.prefsId)
    }
  }

  var brightnessSliderHandler: SliderHandler?
  var isVirtual: Bool = false

  var defaultGammaTableRed = [CGGammaValue](repeating: 0, count: 256)
  var defaultGammaTableGreen = [CGGammaValue](repeating: 0, count: 256)
  var defaultGammaTableBlue = [CGGammaValue](repeating: 0, count: 256)
  var defaultGammaTableSampleCount: UInt32 = 0
  var defaultGammaTablePeak: Float = 1

  private let prefs = UserDefaults.standard

  internal init(_ identifier: CGDirectDisplayID, name: String, vendorNumber: UInt32?, modelNumber: UInt32?, isVirtual: Bool = false) {
    self.identifier = identifier
    self.name = name
    self.vendorNumber = vendorNumber
    self.modelNumber = modelNumber
    self.prefsId = "(" + String(name.filter { !$0.isWhitespace }) + String(vendorNumber ?? 0) + String(modelNumber ?? 0) + "@" + String(identifier) + ")"
    os_log("Display init with prefsIdentifier %{public}@", type: .info, self.prefsId)
    self.isVirtual = isVirtual
    self.swUpdateDefaultGammaTable()
  }

  func stepBrightness(isUp _: Bool, isSmallIncrement _: Bool) {}

  func setFriendlyName(_ value: String) {
    self.prefs.set(value, forKey: PrefKeys.friendlyName.rawValue + self.prefsId)
  }

  func getFriendlyName() -> String {
    return self.prefs.string(forKey: PrefKeys.friendlyName.rawValue + self.prefsId) ?? self.name
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

  func swUpdateDefaultGammaTable() {
    CGGetDisplayTransferByTable(self.identifier, 256, &self.defaultGammaTableRed, &self.defaultGammaTableGreen, &self.defaultGammaTableBlue, &self.defaultGammaTableSampleCount)
    let redPeak = self.defaultGammaTableRed.max() ?? 0
    let greenPeak = self.defaultGammaTableGreen.max() ?? 0
    let bluePeak = self.defaultGammaTableBlue.max() ?? 0
    self.defaultGammaTablePeak = max(redPeak, greenPeak, bluePeak)
  }

  func swBrightnessTransform(value: Float, reverse: Bool = false) -> Float {
    let lowTreshold: Float = 0.0 // If we don't want to allow zero brightness for safety reason, this value can be modified (for example to 0.1 for a 10% minimum)
    if !reverse {
      return value * (1 - lowTreshold) + lowTreshold
    } else {
      return (value - lowTreshold) / (1 - lowTreshold)
    }
  }

  let swBrightnessSemaphore = DispatchSemaphore(value: 1)
  func setSwBrightness(value: Float, smooth: Bool = false) -> Bool {
    let brightnessValue = min(1, value)
    var currentValue = self.getSwBrightnessPrefValue()
    self.saveSwBirghtnessPrefValue(brightnessValue)
    var newValue = brightnessValue
    currentValue = self.swBrightnessTransform(value: currentValue)
    newValue = self.swBrightnessTransform(value: newValue)
    if smooth {
      DispatchQueue.global(qos: .userInteractive).async {
        self.swBrightnessSemaphore.wait()
        for transientValue in stride(from: currentValue, to: newValue, by: 0.005 * (currentValue > newValue ? -1 : 1)) {
          let gammaTableRed = self.defaultGammaTableRed.map { $0 * transientValue }
          let gammaTableGreen = self.defaultGammaTableGreen.map { $0 * transientValue }
          let gammaTableBlue = self.defaultGammaTableBlue.map { $0 * transientValue }
          guard app.reconfigureID == 0 else {
            return
          }
          CGSetDisplayTransferByTable(self.identifier, self.defaultGammaTableSampleCount, gammaTableRed, gammaTableGreen, gammaTableBlue)
          Thread.sleep(forTimeInterval: 0.001) // Let's make things quick if not performed in the background
        }
        self.swBrightnessSemaphore.signal()
      }
    } else {
      let gammaTableRed = self.defaultGammaTableRed.map { $0 * newValue }
      let gammaTableGreen = self.defaultGammaTableGreen.map { $0 * newValue }
      let gammaTableBlue = self.defaultGammaTableBlue.map { $0 * newValue }
      CGSetDisplayTransferByTable(self.identifier, self.defaultGammaTableSampleCount, gammaTableRed, gammaTableGreen, gammaTableBlue)
    }
    return true
  }

  func getSwBrightness() -> Float {
    var gammaTableRed = [CGGammaValue](repeating: 0, count: 256)
    var gammaTableGreen = [CGGammaValue](repeating: 0, count: 256)
    var gammaTableBlue = [CGGammaValue](repeating: 0, count: 256)
    var gammaTableSampleCount: UInt32 = 0
    if CGGetDisplayTransferByTable(self.identifier, 256, &gammaTableRed, &gammaTableGreen, &gammaTableBlue, &gammaTableSampleCount) == CGError.success {
      let redPeak = gammaTableRed.max() ?? 0
      let greenPeak = gammaTableGreen.max() ?? 0
      let bluePeak = gammaTableBlue.max() ?? 0
      let gammaTablePeak = max(redPeak, greenPeak, bluePeak)
      let peakRatio = gammaTablePeak / self.defaultGammaTablePeak
      let brightnessValue = round(self.swBrightnessTransform(value: peakRatio, reverse: true) * 10000) / 10000
      return brightnessValue
    }
    return 1
  }

  func resetSwBrightness() -> Bool {
    return self.setSwBrightness(value: 1)
  }

  func saveSwBirghtnessPrefValue(_ value: Float) {
    self.prefs.set(value, forKey: PrefKeys.SwBrightness.rawValue + self.prefsId)
  }

  func getSwBrightnessPrefValue() -> Float {
    return self.prefs.float(forKey: PrefKeys.SwBrightness.rawValue + self.prefsId)
  }

  func isSwBrightnessNotDefault() -> Bool {
    guard !self.isVirtual else {
      return false
    }
    if self.getSwBrightness() < 1 {
      return true
    }
    return false
  }

  func refreshBrightness() -> Bool {
    return false
  }

  func showOsd(command: Command, value: Float, maxValue: Float = 1, roundChiclet: Bool = false, lock: Bool = false) {
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
      let osdChiclet = OSDUtils.chiclet(fromValue: value, maxValue: maxValue)

      filledChiclets = Int(round(osdChiclet))
      totalChiclets = 16
    } else {
      filledChiclets = Int(value * 100)
      totalChiclets = Int(maxValue * 100)
    }

    manager.showImage(osdImage.rawValue, onDisplayID: self.getShowOsdDisplayId(), priority: 0x1F4, msecUntilFade: 1000, filledChiclets: UInt32(filledChiclets), totalChiclets: UInt32(totalChiclets), locked: lock)
  }
}
