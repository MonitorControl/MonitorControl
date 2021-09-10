import Cocoa

extension NSNotification.Name {
  static let accessibilityApi = NSNotification.Name(rawValue: "com.apple.accessibility.api")
  static let listenFor = NSNotification.Name(rawValue: PrefKeys.listenFor.rawValue)
  static let friendlyName = NSNotification.Name(rawValue: PrefKeys.friendlyName.rawValue)
  static let preferenceReset = NSNotification.Name(rawValue: PrefKeys.preferenceReset.rawValue)
  static let displayListUpdate = NSNotification.Name(rawValue: PrefKeys.displayListUpdate.rawValue)
}
