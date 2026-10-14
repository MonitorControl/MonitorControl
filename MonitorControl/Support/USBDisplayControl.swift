//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Foundation
import IOKit.hid
import os.log

/// Brightness control over USB for older Apple displays that macOS no longer drives itself, such as the ADC Studio and
/// Cinema Displays. They don't speak DDC: they implement the USB Monitor Control class, where brightness is a HID feature control.
class USBDisplayControl {
  static let appleUSBVendorID = 0x05AC
  static let appleEDIDVendorNumber: UInt32 = 0x0610
  static let monitorUsagePage = 0x80
  static let vesaVirtualControlsUsagePage = 0x82
  static let brightnessUsage = 0x10

  let productID: Int
  let locationID: UInt32
  /// Displays macOS supports natively are driven by Apple's AppleUSBDisplays driver, the rest by the generic HID driver
  let isDrivenByMacOS: Bool
  private let manager: IOHIDManager
  private let device: IOHIDDevice
  private let element: IOHIDElement
  private let minValue: Int
  private let maxValue: Int
  private var isOpen = false

  private init?(device: IOHIDDevice, manager: IOHIDManager) {
    let match = [kIOHIDElementUsagePageKey: USBDisplayControl.vesaVirtualControlsUsagePage, kIOHIDElementUsageKey: USBDisplayControl.brightnessUsage] as CFDictionary
    let elements = IOHIDDeviceCopyMatchingElements(device, match, IOOptionBits(kIOHIDOptionsTypeNone)) as? [IOHIDElement] ?? []
    guard let element = elements.first(where: { IOHIDElementGetType($0) == kIOHIDElementTypeFeature }), IOHIDElementGetLogicalMax(element) > IOHIDElementGetLogicalMin(element) else {
      return nil
    }
    self.manager = manager
    self.device = device
    self.element = element
    self.minValue = IOHIDElementGetLogicalMin(element)
    self.maxValue = IOHIDElementGetLogicalMax(element)
    self.productID = IOHIDDeviceGetProperty(device, kIOHIDProductIDKey as CFString) as? Int ?? 0
    self.locationID = UInt32(truncatingIfNeeded: IOHIDDeviceGetProperty(device, kIOHIDLocationIDKey as CFString) as? Int ?? 0)
    self.isDrivenByMacOS = IOObjectConformsTo(IOHIDDeviceGetService(device), "AppleUSBDisplays") != 0
  }

  deinit {
    if self.isOpen {
      IOHIDDeviceClose(self.device, IOOptionBits(kIOHIDOptionsTypeNone))
    }
  }

  /// Apple displays connected over USB that expose a brightness control
  static func connectedDisplays() -> [USBDisplayControl] {
    let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    IOHIDManagerSetDeviceMatching(manager, [kIOHIDVendorIDKey: self.appleUSBVendorID, kIOHIDDeviceUsagePageKey: self.monitorUsagePage] as CFDictionary)
    let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> ?? []
    return devices.compactMap { USBDisplayControl(device: $0, manager: manager) }.sorted { $0.locationID < $1.locationID }
  }

  /// Current brightness on the 0...DDC_MAX_DETECT_LIMIT scale the rest of the app uses for DDC
  func read() -> (current: UInt16, max: UInt16)? {
    guard self.open() else {
      return nil
    }
    let placeholder = IOHIDValueCreateWithIntegerValue(kCFAllocatorDefault, self.element, 0, 0)
    var value = Unmanaged.passUnretained(placeholder)
    // Asks the display itself instead of returning the last value seen
    guard IOHIDDeviceGetValueWithOptions(self.device, self.element, &value, IOHIDDeviceGetValueOptions.withUpdate.rawValue) == kIOReturnSuccess else {
      return nil
    }
    let raw = min(max(IOHIDValueGetIntegerValue(value.takeUnretainedValue()), self.minValue), self.maxValue)
    let scaled = Double(raw - self.minValue) / Double(self.maxValue - self.minValue) * Double(DDC_MAX_DETECT_LIMIT)
    return (UInt16(scaled.rounded()), UInt16(DDC_MAX_DETECT_LIMIT))
  }

  /// Sets the brightness from a 0...DDC_MAX_DETECT_LIMIT value
  func write(_ value: UInt16) -> Bool {
    guard self.open() else {
      return false
    }
    let fraction = Double(min(Int(value), DDC_MAX_DETECT_LIMIT)) / Double(DDC_MAX_DETECT_LIMIT)
    let raw = self.minValue + Int((fraction * Double(self.maxValue - self.minValue)).rounded())
    let hidValue = IOHIDValueCreateWithIntegerValue(kCFAllocatorDefault, self.element, mach_absolute_time(), raw)
    return IOHIDDeviceSetValue(self.device, self.element, hidValue) == kIOReturnSuccess
  }

  private func open() -> Bool {
    if !self.isOpen {
      let result = IOHIDDeviceOpen(self.device, IOOptionBits(kIOHIDOptionsTypeNone))
      self.isOpen = result == kIOReturnSuccess
      if !self.isOpen {
        os_log("Unable to open USB display %{public}@: %{public}@", type: .info, String(format: "0x%04x", self.productID), String(result))
      }
    }
    return self.isOpen
  }
}
