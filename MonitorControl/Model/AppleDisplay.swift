//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Foundation
import os.log

class AppleDisplay: Display {
  private var displayQueue: DispatchQueue

  override init(_ identifier: CGDirectDisplayID, name: String, vendorNumber: UInt32?, modelNumber: UInt32?, isVirtual: Bool = false) {
    self.displayQueue = DispatchQueue(label: String("displayQueue-\(identifier)"))
    super.init(identifier, name: name, vendorNumber: vendorNumber, modelNumber: modelNumber, isVirtual: isVirtual)
  }

  func calcNewBrightness(isUp: Bool, isSmallIncrement: Bool) -> Float {
    var step: Float = (isUp ? 1 : -1) / 16.0
    let delta = step / 4
    if isSmallIncrement {
      step = delta
    }
    return min(max(0, ceil((self.getAppleBrightness() + delta) / step) * step), 1)
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

  override func stepBrightness(isUp: Bool, isSmallIncrement: Bool) {
    let value = self.calcNewBrightness(isUp: isUp, isSmallIncrement: isSmallIncrement)
    self.setAppleBrightness(value: value)
    OSDUtils.showOsd(displayID: self.identifier, command: .brightness, value: value * 64, maxValue: 64)
    if let slider = brightnessSliderHandler {
      slider.setValue(value)
    }
  }

  override func refreshBrightness() -> Bool {
    let brightness = self.getAppleBrightness()
    if let sliderHandler = brightnessSliderHandler, let slider = sliderHandler.slider, brightness != slider.floatValue {
      os_log("Pushing slider towards actual brightness for Apple display %{public}@", type: .debug, self.name)
      if abs(brightness - slider.floatValue) < 0.01 {
        sliderHandler.setValue(brightness)
        return false
      } else if brightness > slider.floatValue {
        sliderHandler.setValue(slider.floatValue + max((brightness - slider.floatValue) / 3, 0.005))
      } else {
        sliderHandler.setValue(slider.floatValue + min((brightness - slider.floatValue) / 3, -0.005))
      }
      return true
    }
    return false
  }
}
