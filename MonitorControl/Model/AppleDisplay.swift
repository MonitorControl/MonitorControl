//
//  AppleDisplay.swift
//  MonitorControl
//
//  Created by Joni Van Roost on 24/01/2020.
//  Copyright © 2020 MonitorControl. All rights reserved.
//

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
    return min(max(0, ceil((self.getBrightness() + delta) / step) * step), 1)
  }

  public func getBrightness() -> Float {
    var brightness: Float = 0
    DisplayServicesGetBrightness(self.identifier, &brightness)
    return brightness * SCALE
  }

  public func setBrightness(value: Float) {
    self.displayQueue.sync {
      DisplayServicesSetBrightness(self.identifier, value / SCALE)
      DisplayServicesBrightnessChanged(self.identifier, Double(value / SCALE))
    }
  }

  override func stepBrightness(isUp: Bool, isSmallIncrement: Bool) {
    let value = self.calcNewBrightness(isUp: isUp, isSmallIncrement: isSmallIncrement)
    self.setBrightness(value: value)
    self.showOsd(command: .brightness, value: value * 64, maxValue: 64)
    if let slider = brightnessSliderHandler?.slider {
      slider.floatValue = value * SCALE
    }
  }

  override func refreshBrightness() -> Bool {
    let brightness = self.getBrightness() * SCALE
    if let sliderHandler = brightnessSliderHandler, let slider = sliderHandler.slider, brightness != slider.floatValue {
      os_log("Pushing slider towards actual brightness for Apple display %{public}@", type: .debug, self.name)
      if abs(brightness - slider.floatValue) < 0.01 * SCALE {
        slider.floatValue = brightness
        return false
      } else if brightness > slider.floatValue {
        slider.floatValue += max((brightness - slider.floatValue) / 3, 0.005 * SCALE)
      } else {
        slider.floatValue += min((brightness - slider.floatValue) / 3, -0.005 * SCALE)
      }
      return true
    }
    return false
  }

  func isBuiltIn() -> Bool {
    if CGDisplayIsBuiltin(self.identifier) != 0 {
      return true
    } else {
      return false
    }
  }
}
