import Cocoa

extension CGDirectDisplayID {
  public var vendorNumber: UInt32? {
    return CGDisplayVendorNumber(self)
  }

  public var modelNumber: UInt32? {
    return CGDisplayModelNumber(self)
  }

  public var serialNumber: UInt32? {
    return CGDisplaySerialNumber(self)
  }
}
