//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Cocoa

extension NSNotification.Name {
  static let accessibilityApi = NSNotification.Name(rawValue: "com.apple.accessibility.api")
  static let listenFor = NSNotification.Name(rawValue: PrefKey.listenFor.rawValue)
  static let friendlyName = NSNotification.Name(rawValue: PrefKey.friendlyName.rawValue)
  static let preferenceReset = NSNotification.Name(rawValue: PrefKey.preferenceReset.rawValue)
  static let displayListUpdate = NSNotification.Name(rawValue: PrefKey.displayListUpdate.rawValue)
}
