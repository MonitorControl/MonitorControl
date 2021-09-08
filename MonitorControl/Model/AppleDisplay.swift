//
//  AppleDisplay.swift
//  MonitorControl
//
//  Created by Joni Van Roost on 24/01/2020.
//  Copyright © 2020 MonitorControl. All rights reserved.
//

import Foundation

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
    return brightness
  }

  public func setBrightness(value: Float) {
    self.displayQueue.sync {
      DisplayServicesSetBrightness(self.identifier, Float(value))
      DisplayServicesBrightnessChanged(self.identifier, Double(value))
    }
  }

  override func stepBrightness(isUp: Bool, isSmallIncrement: Bool) {
    let value = self.calcNewBrightness(isUp: isUp, isSmallIncrement: isSmallIncrement)
    self.setBrightness(value: value)
    self.showOsd(command: .brightness, value: Int(value * 64), maxValue: 64)
    if let slider = brightnessSliderHandler?.slider {
      slider.integerValue = Int(value * 100)
    }
  }

  override func refreshBrightness() -> Bool {
    let brightness = Int(getBrightness() * 100)
    if let sliderHandler = brightnessSliderHandler, let slider = sliderHandler.slider {
      if slider.integerValue != brightness {
        slider.integerValue = brightness
        return true
      }
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
