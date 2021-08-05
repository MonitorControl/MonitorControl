//
//  InternalDisplay.swift
//  MonitorControl
//
//  Created by Joni Van Roost on 24/01/2020.
//  Copyright © 2020 MonitorControl. All rights reserved.
//
//  Some of the code in this file was sourced from:
//  https://github.com/fnesveda/ExternalDisplayBrightness
//  all credit goes to @fnesveda

import Foundation

class InternalDisplay: Display {
  // the queue for dispatching display operations, so they're not performed directly and concurrently
  private var displayQueue: DispatchQueue

  override init(_ identifier: CGDirectDisplayID, name: String, vendorNumber: UInt32?, modelNumber: UInt32?, isVirtual _: Bool = false) {
    self.displayQueue = DispatchQueue(label: String("displayQueue-\(identifier)"))
    super.init(identifier, name: name, vendorNumber: vendorNumber, modelNumber: modelNumber)
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

  override func stepBrightness(isUp: Bool, isSmallIncrement: Bool) {
    let value = self.calcNewBrightness(isUp: isUp, isSmallIncrement: isSmallIncrement)
    self.displayQueue.sync {
      DisplayServicesSetBrightness(self.identifier, Float(value))
      DisplayServicesBrightnessChanged(self.identifier, Double(value))
      self.showOsd(command: .brightness, value: Int(value * 64), maxValue: 64)
    }
  }
}
