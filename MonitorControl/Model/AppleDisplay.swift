//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Foundation
import os.log

class AppleDisplay: Display {
  private var displayQueue: DispatchQueue

  override init(_ identifier: CGDirectDisplayID, name: String, vendorNumber: UInt32?, modelNumber: UInt32?, serialNumber: UInt32?, isVirtual: Bool = false, isDummy: Bool = false) {
    self.displayQueue = DispatchQueue(label: String("displayQueue-\(identifier)"))
    super.init(identifier, name: name, vendorNumber: vendorNumber, modelNumber: modelNumber, serialNumber: serialNumber, isVirtual: isVirtual, isDummy: isDummy)
  }

  public func getAppleBrightness() -> Float {
    guard !self.isDummy else {
      return 1
    }
    var brightness: Float = 0
    DisplayServicesGetBrightness(self.identifier, &brightness)
    return brightness
  }

  public func setAppleBrightness(value: Float) {
    guard !self.isDummy else {
      return
    }
    self.displayQueue.sync {
      DisplayServicesSetBrightness(self.identifier, value)
      DisplayServicesBrightnessChanged(self.identifier, Double(value))
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
