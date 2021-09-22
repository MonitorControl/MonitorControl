//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Foundation
import os.log

class AppleDisplay: Display {
  private var displayQueue: DispatchQueue

  override init(_ identifier: CGDirectDisplayID, name: String, vendorNumber: UInt32?, modelNumber: UInt32?, isVirtual: Bool = false) {
    self.displayQueue = DispatchQueue(label: String("displayQueue-\(identifier)"))
    super.init(identifier, name: name, vendorNumber: vendorNumber, modelNumber: modelNumber, isVirtual: isVirtual)
  }

  public func getAppleBrightness() -> Float {
    var brightness: Float = 0
    DisplayServicesGetBrightness(self.identifier, &brightness)
    return brightness
  }

  public func setAppleBrightness(value: Float) {
    self.displayQueue.sync {
      DisplayServicesSetBrightness(self.identifier, value)
      DisplayServicesBrightnessChanged(self.identifier, Double(value))
    }
  }

  override func setDirectBrightness(_ to: Float, transient: Bool = false) -> Bool {
    let value = max(min(to, 1), 0)
    self.setAppleBrightness(value: value)
    if !transient {
      self.savePrefValue(value, for: .brightness)
      self.brightnessSyncSourceValue = value
      self.smoothBrightnessTransient = value
    }
    return true
  }

  override func getBrightness() -> Float {
    if self.prefValueExists(for: .brightness) {
      return self.readPrefValue(for: .brightness)
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
    self.savePrefValue(brightness, for: .brightness)
    if brightness != oldValue {
      os_log("Pushing slider and reporting delta for Apple display %{public}@", type: .debug, String(self.identifier))
      var newValue: Float

      if abs(brightness - oldValue) < 0.01 {
        newValue = brightness
      } else if brightness > oldValue {
        newValue = oldValue + max((brightness - oldValue) / 3, 0.005)
      } else {
        newValue = oldValue + min((brightness - oldValue) / 3, -0.005)
      }
      self.brightnessSyncSourceValue = newValue
      if let sliderHandler = brightnessSliderHandler {
        sliderHandler.setValue(newValue, displayID: self.identifier)
      }
      return newValue - oldValue
    }
    return 0
  }
}
