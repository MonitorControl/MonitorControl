//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Foundation
import os.log

class AppleDisplay: Display {
  private var displayQueue: DispatchQueue
  var isXDRCapable: Bool = false
  var xdrMaxValue: Float = 1.5

  var effectiveBrightnessMax: Float {
    (self.isXDRCapable && self.readPrefAsBool(key: .xdrEnabled)) ? self.xdrMaxValue : 1.0
  }

  override var brightnessMaxValue: Float { self.effectiveBrightnessMax }

  override init(_ identifier: CGDirectDisplayID, name: String, vendorNumber: UInt32?, modelNumber: UInt32?, serialNumber: UInt32?, isVirtual: Bool = false, isDummy: Bool = false) {
    self.displayQueue = DispatchQueue(label: String("displayQueue-\(identifier)"))
    super.init(identifier, name: name, vendorNumber: vendorNumber, modelNumber: modelNumber, serialNumber: serialNumber, isVirtual: isVirtual, isDummy: isDummy)
    self.detectXDRCapability()
  }

  private func detectXDRCapability() {
    guard CGDisplayIsBuiltin(self.identifier) != 0, !self.isDummy else {
      return
    }
    var currentBrightness: Float = 0
    DisplayServicesGetBrightness(self.identifier, &currentBrightness)
    DisplayServicesSetBrightness(self.identifier, 1.01)
    var readBackBrightness: Float = 0
    DisplayServicesGetBrightness(self.identifier, &readBackBrightness)
    DisplayServicesSetBrightness(self.identifier, currentBrightness)
    if readBackBrightness > 1.0 {
      self.isXDRCapable = true
      let savedMax = self.readPrefAsFloat(key: .xdrMaxBrightness)
      if savedMax > 1.0 {
        self.xdrMaxValue = savedMax
      } else {
        self.xdrMaxValue = 1.5
        self.savePref(self.xdrMaxValue, key: .xdrMaxBrightness)
      }
      os_log("XDR capable display detected: %{public}@, max: %{public}@", type: .info, String(self.identifier), String(self.xdrMaxValue))
    }
  }

  func resetToNormalBrightness() {
    _ = self.setBrightness(1.0)
    if let sliderHandler = self.sliderHandler[.brightness] {
      sliderHandler.setValue(1.0, displayID: self.identifier)
    }
  }

  func disableXDR() {
    self.savePref(false, key: .xdrEnabled)
    _ = self.setBrightness(1.0)
    DispatchQueue.main.async {
      app.updateMenusAndKeys()
    }
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
    _ = self.displayQueue.sync {
      DisplayServicesSetBrightness(self.identifier, value)
    }
  }

  override func setDirectBrightness(_ to: Float, transient: Bool = false) -> Bool {
    guard !self.isDummy else {
      return false
    }
    let value = max(min(to, self.effectiveBrightnessMax), 0)
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
