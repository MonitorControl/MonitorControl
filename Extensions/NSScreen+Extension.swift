import Cocoa

extension NSScreen {
  public var displayID: CGDirectDisplayID {
    return (self.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID)!
  }

  public var vendorNumber: UInt32? {
    switch CGDisplayVendorNumber(self.displayID) {
    case 0xFFFF_FFFF:
      return nil
    case let vendorNumber:
      return vendorNumber
    }
  }

  public var modelNumber: UInt32? {
    switch CGDisplayModelNumber(self.displayID) {
    case 0xFFFF_FFFF:
      return nil
    case let modelNumber:
      return modelNumber
    }
  }

  public var serialNumber: UInt32? {
    switch CGDisplaySerialNumber(self.displayID) {
    case 0x0000_0000:
      return nil
    case let serialNumber:
      return serialNumber
    }
  }

  public var displayName: String? {
    var servicePortIterator = io_iterator_t()

    let status = IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching("IODisplayConnect"), &servicePortIterator)
    guard status == KERN_SUCCESS else {
      return nil
    }

    defer {
      assert(IOObjectRelease(servicePortIterator) == KERN_SUCCESS)
    }

    while case let object = IOIteratorNext(servicePortIterator), object != 0 {
      let dict = (IODisplayCreateInfoDictionary(object, UInt32(kIODisplayOnlyPreferredName)).takeRetainedValue() as NSDictionary as? [String: AnyObject])!

      if dict[kDisplayVendorID] as? UInt32 == self.vendorNumber,
        dict[kDisplayProductID] as? UInt32 == self.modelNumber,
        dict[kDisplaySerialNumber] as? UInt32 == self.serialNumber {
        if let productName = dict["DisplayProductName"] as? [String: String],
          let firstKey = Array(productName.keys).first {
          return productName[firstKey]!
        }
      }
    }

    return nil
  }

  public static func getByDisplayID(displayID: CGDirectDisplayID) -> NSScreen? {
    return NSScreen.screens.first { $0.displayID == displayID }
  }
}
