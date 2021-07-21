//
//  InternalDisplay.swift
//  MonitorControl
//
//  Created by Joni Van Roost on 24/01/2020.
//  Copyright © 2020 MonitorControl. All rights reserved.
//
//  Most of the code in this file was sourced from:
//  https://github.com/fnesveda/ExternalDisplayBrightness
//  all credit goes to @fnesveda

import Foundation

class InternalDisplay: Display {
  // the queue for dispatching display operations, so they're not performed directly and concurrently
  private var displayQueue: DispatchQueue

  override init(_ identifier: CGDirectDisplayID, name: String, vendorNumber: UInt32?, modelNumber: UInt32?) {
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

  #if arch(arm64)
  
  public func getBrightness() -> Float {
    var brightness: Float = 0
    let _ = type(of: self).DisplayServicesGetBrightness?(self.identifier, &brightness)
    return brightness
  }

  override func stepBrightness(isUp: Bool, isSmallIncrement: Bool) {
    let value = self.calcNewBrightness(isUp: isUp, isSmallIncrement: isSmallIncrement)
    self.displayQueue.sync {
      let _ = type(of: self).DisplayServicesSetBrightness?(self.identifier, Float(value))
      type(of: self).DisplayServicesBrightnessChanged?(self.identifier, Double(value))
      self.showOsd(command: .brightness, value: Int(value * 64), maxValue: 64)
    }
  }
  
  #else

  public func getBrightness() -> Float {
    self.displayQueue.sync {
      Float(type(of: self).CoreDisplayGetUserBrightness?(self.identifier) ?? 0.5)
    }
  }

  override func stepBrightness(isUp: Bool, isSmallIncrement: Bool) {
    let value = self.calcNewBrightness(isUp: isUp, isSmallIncrement: isSmallIncrement)
    self.displayQueue.sync {
      type(of: self).CoreDisplaySetUserBrightness?(self.identifier, Double(value))
      type(of: self).DisplayServicesBrightnessChanged?(self.identifier, Double(value))
      self.showOsd(command: .brightness, value: Int(value * 64), maxValue: 64)
    }
  }
  
  #endif

  // notifies the system that the brightness of a specified display has changed (to update System Preferences etc.)
  // unfortunately Apple doesn't provide a public API for this, so we have to manually extract the function from the DisplayServices framework
  private static var DisplayServicesBrightnessChanged: ((CGDirectDisplayID, Double) -> Void)? {
    let displayServicesPath = CFURLCreateWithString(kCFAllocatorDefault, "/System/Library/PrivateFrameworks/DisplayServices.framework" as CFString, nil)
    if let displayServicesBundle = CFBundleCreate(kCFAllocatorDefault, displayServicesPath) {
      if let funcPointer = CFBundleGetFunctionPointerForName(displayServicesBundle, "DisplayServicesBrightnessChanged" as CFString) {
        typealias DSBCFunctionType = @convention(c) (UInt32, Double) -> Void
        return unsafeBitCast(funcPointer, to: DSBCFunctionType.self)
      }
    }
    return nil
  }

  #if arch(arm64)
  
  // For Apple Silicon
  private static var DisplayServicesGetBrightness: ((CGDirectDisplayID, UnsafePointer<Float>) -> Int)? {
    let displayServicesPath = CFURLCreateWithString(kCFAllocatorDefault, "/System/Library/PrivateFrameworks/DisplayServices.framework" as CFString, nil)
    if let displayServicesBundle = CFBundleCreate(kCFAllocatorDefault, displayServicesPath) {
      if let funcPointer = CFBundleGetFunctionPointerForName(displayServicesBundle, "DisplayServicesGetBrightness" as CFString) {
        typealias DSBCFunctionType = @convention(c) (UInt32, UnsafePointer<Float>) -> Int
        return unsafeBitCast(funcPointer, to: DSBCFunctionType.self)
      }
    }
    return nil
  }

  // For Apple Silicon
  private static var DisplayServicesSetBrightness: ((CGDirectDisplayID, Float) -> Int)? {
    let displayServicesPath = CFURLCreateWithString(kCFAllocatorDefault, "/System/Library/PrivateFrameworks/DisplayServices.framework" as CFString, nil)
    if let displayServicesBundle = CFBundleCreate(kCFAllocatorDefault, displayServicesPath) {
      if let funcPointer = CFBundleGetFunctionPointerForName(displayServicesBundle, "DisplayServicesSetBrightness" as CFString) {
        typealias DSBCFunctionType = @convention(c) (UInt32, Float) -> Int
        return unsafeBitCast(funcPointer, to: DSBCFunctionType.self)
      }
    }
    return nil
  }
  
  #else

  // reads the brightness of a display through the CoreDisplay framework
  // unfortunately Apple doesn't provide a public API for this, so we have to manually extract the function from the CoreDisplay framework
  private static var CoreDisplayGetUserBrightness: ((CGDirectDisplayID) -> Double)? {
    let coreDisplayPath = CFURLCreateWithString(kCFAllocatorDefault, "/System/Library/Frameworks/CoreDisplay.framework" as CFString, nil)
    if let coreDisplayBundle = CFBundleCreate(kCFAllocatorDefault, coreDisplayPath) {
      if let funcPointer = CFBundleGetFunctionPointerForName(coreDisplayBundle, "CoreDisplay_Display_GetUserBrightness" as CFString) {
        typealias CDGUBFunctionType = @convention(c) (UInt32) -> Double
        return unsafeBitCast(funcPointer, to: CDGUBFunctionType.self)
      }
    }
    return nil
  }

  // sets the brightness of a display through the CoreDisplay framework
  // unfortunately Apple doesn't provide a public API for this, so we have to manually extract the function from the CoreDisplay framework
  private static var CoreDisplaySetUserBrightness: ((CGDirectDisplayID, Double) -> Void)? {
    let coreDisplayPath = CFURLCreateWithString(kCFAllocatorDefault, "/System/Library/Frameworks/CoreDisplay.framework" as CFString, nil)
    if let coreDisplayBundle = CFBundleCreate(kCFAllocatorDefault, coreDisplayPath) {
      if let funcPointer = CFBundleGetFunctionPointerForName(coreDisplayBundle, "CoreDisplay_Display_SetUserBrightness" as CFString) {
        typealias CDSUBFunctionType = @convention(c) (UInt32, Double) -> Void
        return unsafeBitCast(funcPointer, to: CDSUBFunctionType.self)
      }
    }
    return nil
  }
  
  #endif
  
}
