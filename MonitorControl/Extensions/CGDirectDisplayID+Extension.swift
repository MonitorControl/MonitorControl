//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Cocoa

public extension CGDirectDisplayID {
  var vendorNumber: UInt32? {
    CGDisplayVendorNumber(self)
  }

  var modelNumber: UInt32? {
    CGDisplayModelNumber(self)
  }

  var serialNumber: UInt32? {
    CGDisplaySerialNumber(self)
  }
}
