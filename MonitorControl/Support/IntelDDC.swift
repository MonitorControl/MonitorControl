//
//  IntelDDC.swift
//  MonitorControl
//
//  Original code: https://github.com/reitermarkus/DDC.swift
//  Adapted for MonitorControl
//  Credits to @reitermarkus
//

import Foundation
import IOKit.i2c
import os.log

public class IntelDDC {
  let displayId: CGDirectDisplayID
  let framebuffer: io_service_t
  let replyTransactionType: IOOptionBits
  var enabled: Bool = false

  deinit {
    assert(IOObjectRelease(self.framebuffer) == KERN_SUCCESS)
  }

  public init?(for displayId: CGDirectDisplayID, withReplyTransactionType replyTransactionType: IOOptionBits? = nil) {
    self.displayId = displayId
    guard let framebuffer = IntelDDC.ioFramebufferPortFromDisplayId(displayId: displayId) else {
      return nil
    }
    self.framebuffer = framebuffer
    if let replyTransactionType = replyTransactionType {
      self.replyTransactionType = replyTransactionType
    } else if let replyTransactionType = IntelDDC.supportedTransactionType() {
      self.replyTransactionType = replyTransactionType
    } else {
      os_log("No supported reply transaction type found for display with ID %u.", type: .error, displayId)
      return nil
    }
  }

  public func write(command: UInt8, value: UInt16, errorRecoveryWaitTime: UInt32? = nil, writeSleepTime: UInt32 = 10000, numofWriteCycles: UInt8 = 2) -> Bool {
    let message: [UInt8] = [0x03, command, UInt8(value >> 8), UInt8(value & 0xFF)]
    var replyData: [UInt8] = []
    var success: Bool = false
    for _ in 1 ... numofWriteCycles {
      usleep(writeSleepTime)
      if self.sendMessage(message, replyData: &replyData, errorRecoveryWaitTime: errorRecoveryWaitTime ?? 20000) != nil {
        success = true
      }
    }
    return success
  }

  public func sendMessage(_ message: [UInt8], replyData: inout [UInt8], minReplyDelay: UInt64? = nil, errorRecoveryWaitTime: UInt32? = nil) -> IOI2CRequest? {
    var data: [UInt8] = [UInt8(0x51), UInt8(0x80 + message.count)] + message + [UInt8(0x6E)]
    for i in 0 ..< (data.count - 1) {
      data[data.count - 1] ^= data[i]
    }
    var request = IOI2CRequest()
    request.commFlags = 0
    request.sendAddress = 0x6E
    request.sendTransactionType = IOOptionBits(kIOI2CSimpleTransactionType)
    request.sendBytes = UInt32(data.count)
    request.sendBuffer = withUnsafePointer(to: &data[0]) { vm_address_t(bitPattern: $0) }
    if replyData.count == 0 {
      request.replyTransactionType = IOOptionBits(kIOI2CNoTransactionType)
      request.replyBytes = 0
    } else {
      request.minReplyDelay = minReplyDelay ?? 10
      request.replyAddress = 0x6F
      request.replySubAddress = 0x51
      request.replyTransactionType = self.replyTransactionType
      request.replyBytes = UInt32(replyData.count)
      request.replyBuffer = withUnsafePointer(to: &replyData[0]) { vm_address_t(bitPattern: $0) }
    }
    guard IntelDDC.send(request: &request, to: self.framebuffer, errorRecoveryWaitTime: errorRecoveryWaitTime) else {
      return nil
    }
    if replyData.count > 0 {
      let checksum = replyData.last!
      var calculated = UInt8(0x50)
      for i in 0 ..< (replyData.count - 1) {
        calculated ^= replyData[i]
      }
      guard checksum == calculated else {
        os_log("Checksum of reply does not match. Expected %u, got %u.", type: .error, checksum, calculated)
        os_log("Response was: %{public}@", type: .debug, replyData.map { String(format: "%02X", $0) }.joined(separator: " "))
        return nil
      }
    }
    return request
  }

  public func read(command: UInt8, tries: UInt = 1, replyTransactionType _: IOOptionBits? = nil, minReplyDelay: UInt64? = nil, errorRecoveryWaitTime: UInt32? = nil) -> (UInt16, UInt16)? {
    assert(tries > 0)
    let message: [UInt8] = [0x01, command]
    var replyData: [UInt8] = Array(repeating: 0, count: 11)
    for i in 1 ... tries {
      guard self.sendMessage(message, replyData: &replyData, minReplyDelay: minReplyDelay, errorRecoveryWaitTime: errorRecoveryWaitTime ?? 40000) != nil else {
        continue
      }
      guard replyData[2] == 0x02 else {
        os_log("Got wrong response type for %{public}@. Expected %u, got %u.", type: .debug, String(reflecting: command), 0x02, replyData[2])
        os_log("Response was: %{public}@", type: .debug, replyData.map { String(format: "%02X", $0) }.joined(separator: " "))
        continue
      }
      guard replyData[3] == 0x00 else {
        os_log("Reading %{public}@ is not supported.", type: .debug, String(reflecting: command))
        return nil
      }
      if i > 1 {
        os_log("Reading %{public}@ took %u tries.", type: .debug, String(reflecting: command), i)
      }
      let (mh, ml, sh, sl) = (replyData[6], replyData[7], replyData[8], replyData[9])
      let maxValue = UInt16(mh << 8) + UInt16(ml)
      let currentValue = UInt16(sh << 8) + UInt16(sl)
      return (currentValue, maxValue)
    }
    os_log("Reading %{public}@ failed.", type: .error, String(reflecting: command))
    return nil
  }

  private static func supportedTransactionType() -> IOOptionBits? {
    var ioIterator = io_iterator_t()
    guard IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceNameMatching("IOFramebufferI2CInterface"), &ioIterator) == KERN_SUCCESS else {
      return nil
    }
    defer {
      assert(IOObjectRelease(ioIterator) == KERN_SUCCESS)
    }
    while case let ioService = IOIteratorNext(ioIterator), ioService != 0 {
      var serviceProperties: Unmanaged<CFMutableDictionary>?
      guard IORegistryEntryCreateCFProperties(ioService, &serviceProperties, kCFAllocatorDefault, IOOptionBits()) == KERN_SUCCESS, serviceProperties != nil else {
        continue
      }
      let dict = serviceProperties!.takeRetainedValue() as NSDictionary
      if let types = dict[kIOI2CTransactionTypesKey] as? UInt64 {
        if (1 << kIOI2CDDCciReplyTransactionType) & types != 0 {
          os_log("kIOI2CDDCciReplyTransactionType is supported.", type: .debug)
          return IOOptionBits(kIOI2CDDCciReplyTransactionType)
        }
        if (1 << kIOI2CSimpleTransactionType) & types != 0 {
          os_log("kIOI2CSimpleTransactionType is supported.", type: .debug)
          return IOOptionBits(kIOI2CSimpleTransactionType)
        }
      }
    }
    return nil
  }

  static func send(request: inout IOI2CRequest, to framebuffer: io_service_t, errorRecoveryWaitTime: UInt32? = nil) -> Bool {
    if let errorRecoveryWaitTime = errorRecoveryWaitTime {
      usleep(errorRecoveryWaitTime)
    }
    var busCount: IOItemCount = 0
    guard IOFBGetI2CInterfaceCount(framebuffer, &busCount) == KERN_SUCCESS else {
      os_log("Failed to get interface count for framebuffer with ID %u.", type: .error, framebuffer)
      return false
    }
    for bus: IOOptionBits in 0 ..< busCount {
      var interface = io_service_t()
      guard IOFBCopyI2CInterfaceForBus(framebuffer, bus, &interface) == KERN_SUCCESS else {
        os_log("Failed to get interface %u for framebuffer with ID %u.", type: .error, bus, framebuffer)
        continue
      }
      var connect: IOI2CConnectRef?
      guard IOI2CInterfaceOpen(interface, IOOptionBits(), &connect) == KERN_SUCCESS else {
        os_log("Failed to connect to interface %u for framebuffer with ID %u.", type: .error, bus, framebuffer)
        continue
      }
      defer { IOI2CInterfaceClose(connect, IOOptionBits()) }
      guard IOI2CSendRequest(connect, IOOptionBits(), &request) == KERN_SUCCESS else {
        os_log("Failed to send request to interface %u for framebuffer with ID %u.", type: .error, bus, framebuffer)
        continue
      }
      guard request.result == KERN_SUCCESS else {
        os_log("Request to interface %u for framebuffer with ID %u failed.", type: .error, bus, framebuffer)
        continue
      }
      return true
    }
    return false
  }

  static func servicePortUsingDisplayPropertiesMatching(from displayId: CGDirectDisplayID) -> io_object_t? {
    var portIterator = io_iterator_t()
    let status: kern_return_t = IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching(IOFRAMEBUFFER_CONFORMSTO), &portIterator)
    guard status == KERN_SUCCESS else {
      os_log("No matching services found for display with ID %u.", type: .error, displayId)
      return nil
    }
    defer {
      assert(IOObjectRelease(portIterator) == KERN_SUCCESS)
    }
    while case let port = IOIteratorNext(portIterator), port != 0 {
      let dict = IODisplayCreateInfoDictionary(port, IOOptionBits(kIODisplayOnlyPreferredName)).takeRetainedValue() as NSDictionary
      let valueForKey = { (k: String) in
        (dict[k] as? CFIndex).flatMap { Int32(exactly: $0) }.flatMap { UInt32(bitPattern: $0) } ?? 0
      }
      let portVendorId = valueForKey(kDisplayVendorID)
      let displayVendorId = CGDisplayVendorNumber(displayId)
      guard portVendorId == displayVendorId else {
        os_log("Service port vendor ID %u differs from display product ID %u.", type: .debug,
               portVendorId, displayVendorId)
        continue
      }
      let portProductId = valueForKey(kDisplayProductID)
      let displayProductId = CGDisplayModelNumber(displayId)
      guard portProductId == displayProductId else {
        os_log("Service port product ID %u differs from display product ID %u.", type: .debug,
               portProductId, displayProductId)
        continue
      }
      let portSerialNumber = valueForKey(kDisplaySerialNumber)
      let displaySerialNumber = CGDisplaySerialNumber(displayId)
      guard portSerialNumber == displaySerialNumber else {
        os_log("Service port serial number %u differs from display serial number %u.", type: .debug,
               portSerialNumber, displaySerialNumber)
        continue
      }
      if let displayLocation = dict[kIODisplayLocationKey] as? NSString {
        // the unit number is the number right after the last "@" sign in the display location
        // swiftlint:disable:next force_try
        let regex = try! NSRegularExpression(pattern: "@([0-9]+)[^@]+$", options: [])
        if let match = regex.firstMatch(in: displayLocation as String, options: [], range: NSRange(location: 0, length: displayLocation.length)) {
          let unitNumber = UInt32(displayLocation.substring(with: match.range(at: 1)))
          guard unitNumber == CGDisplayUnitNumber(displayId) else {
            continue
          }
        }
      }
      os_log("Vendor ID: %u, Product ID: %u, Serial Number: %u", type: .debug, portVendorId, portProductId, portSerialNumber)
      os_log("Unit Number: %u", type: .debug, CGDisplayUnitNumber(displayId))
      os_log("Service Port: %u", type: .debug, port)
      return port
    }
    os_log("No service port found for display with ID %u.", type: .error, displayId)
    return nil
  }

  static func ioFramebufferPortFromDisplayId(displayId: CGDirectDisplayID) -> io_service_t? {
    if CGDisplayIsBuiltin(displayId) == boolean_t(truncating: true) {
      return nil
    }
    var servicePortUsingCGSServiceForDisplayNumber: io_service_t = 0
    CGSServiceForDisplayNumber(displayId, &servicePortUsingCGSServiceForDisplayNumber)
    if servicePortUsingCGSServiceForDisplayNumber != 0 {
      os_log("Using CGSServiceForDisplayNumber to acquire framebuffer port for %u.", type: .debug, displayId)
      return servicePortUsingCGSServiceForDisplayNumber
    }
    guard let servicePort = self.servicePortUsingDisplayPropertiesMatching(from: displayId) else {
      return nil
    }
    var busCount: IOItemCount = 0
    guard IOFBGetI2CInterfaceCount(servicePort, &busCount) == KERN_SUCCESS, busCount >= 1 else {
      os_log("No framebuffer port found for display with ID %u.", type: .error, displayId)
      return nil
    }
    return servicePort
  }
}
