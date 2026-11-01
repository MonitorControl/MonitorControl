//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Foundation
import os.log

class AppleDisplay: Display {
  private var displayQueue: DispatchQueue
  private var cachedMaxSDRNits: Float?

  override init(_ identifier: CGDirectDisplayID, name: String, vendorNumber: UInt32?, modelNumber: UInt32?, serialNumber: UInt32?, isVirtual: Bool = false, isDummy: Bool = false) {
    self.displayQueue = DispatchQueue(label: String("displayQueue-\(identifier)"))
    super.init(identifier, name: name, vendorNumber: vendorNumber, modelNumber: modelNumber, serialNumber: serialNumber, isVirtual: isVirtual, isDummy: isDummy)
    self.cachedMaxSDRNits = self.queryMaxSDRNits()
  }

  private func queryMaxSDRNits() -> Float {
    if !DEBUG_MACOS10, #available(macOS 11.0, *) {
      if let dictionary = (CoreDisplay_DisplayCreateInfoDictionary(self.identifier)?.takeRetainedValue() as NSDictionary?) {
        if let sdrNits = dictionary["NonReferencePeakSDRLuminance"] as? NSNumber, sdrNits.floatValue > 0 {
          return sdrNits.floatValue
        }
        if let refSdrNits = dictionary["ReferencePeakSDRLuminance"] as? NSNumber, refSdrNits.floatValue > 0 {
          return refSdrNits.floatValue
        }
      }
    }
    return 500.0
  }

  override func getNits(forValue value: Float? = nil) -> Int? {
    guard !self.isDummy else {
      return nil
    }
    let maxNits = self.cachedMaxSDRNits ?? 500.0
    var linearBrightness: Float = -1
    if DisplayServicesGetLinearBrightness(self.identifier, &linearBrightness) == 0, linearBrightness >= 0 {
      if let targetValue = value {
        let currentUserBrightness = self.getAppleBrightness()
        if abs(targetValue - currentUserBrightness) < 0.02 {
          return max(0, Int((linearBrightness * maxNits).rounded()))
        }
      } else {
        return max(0, Int((linearBrightness * maxNits).rounded()))
      }
    }
    let userBrightness = max(0, min(1, value ?? self.getBrightness()))
    let approxLinear = pow(userBrightness, 2.2)
    return max(0, Int((approxLinear * maxNits).rounded()))
  }

  func getAppleBrightness() -> Float {
    guard !self.isDummy else {
      return 1
    }
    var brightness: Float = 0
    DisplayServicesGetBrightness(self.identifier, &brightness)
    return brightness
  }

  func setAppleBrightness(value: Float) {
    guard !self.isDummy else {
      return
    }
    _ = self.displayQueue.sync {
      DisplayServicesSetBrightness(self.identifier, value)
    }
  }

  override func setDirectBrightness(_ to: Float, transient: Bool = false) -> Bool {
    guard !self.isDummy else {
      return false
    }
    let value = max(min(to, 1), 0)
    self.setAppleBrightness(value: value)
    if !transient {
      self.savePref(value, for: .brightness)
      self.brightnessSyncSourceValue = value
      self.smoothBrightnessTransient = value
    }
    return true
  }

  override func getBrightness() -> Float {
    guard !self.isDummy else {
      return 1
    }
    if self.prefExists(for: .brightness) {
      return self.readPrefAsFloat(for: .brightness)
    } else {
      return self.getAppleBrightness()
    }
  }

  override func refreshBrightness() -> Float {
    guard !self.smoothBrightnessRunning else {
      return 0
    }
    let brightness = self.getAppleBrightness()
    let oldValue = self.brightnessSyncSourceValue
    self.savePref(brightness, for: .brightness)
    if brightness != oldValue {
      os_log("Pushing slider and reporting delta for Apple display %{public}@", type: .info, String(self.identifier))
      var newValue: Float

      if abs(brightness - oldValue) < 0.01 {
        newValue = brightness
      } else if brightness > oldValue {
        newValue = oldValue + max((brightness - oldValue) / 3, 0.005)
      } else {
        newValue = oldValue + min((brightness - oldValue) / 3, -0.005)
      }
      self.brightnessSyncSourceValue = newValue
      if let sliderHandler = self.sliderHandler[.brightness] {
        sliderHandler.setValue(newValue, displayID: self.identifier)
      }
      return newValue - oldValue
    }
    return 0
  }
}
