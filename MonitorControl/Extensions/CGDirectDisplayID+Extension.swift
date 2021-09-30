//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Cocoa

public extension CGDirectDisplayID {
  var vendorNumber: UInt32? {
    return CGDisplayVendorNumber(self)
  }

  var modelNumber: UInt32? {
    return CGDisplayModelNumber(self)
  }

  var serialNumber: UInt32? {
    return CGDisplaySerialNumber(self)
  }
}
