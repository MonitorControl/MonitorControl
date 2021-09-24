//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Cocoa

extension NSNotification.Name {
  static let accessibilityApi = NSNotification.Name(rawValue: "com.apple.accessibility.api")
  static let friendlyName = NSNotification.Name(rawValue: PrefKey.friendlyName.rawValue)
  static let preferenceReset = NSNotification.Name(rawValue: PrefKey.preferenceReset.rawValue)
}
