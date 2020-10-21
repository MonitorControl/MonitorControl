import Cocoa

extension NSNotification.Name {
  static let accessibilityApi = NSNotification.Name(rawValue: "com.apple.accessibility.api")
  static let listenFor = NSNotification.Name(rawValue: Utils.PrefKeys.listenFor.rawValue)
  static let showVolume = NSNotification.Name(rawValue: Utils.PrefKeys.showVolume.rawValue)
  static let showContrast = NSNotification.Name(rawValue: Utils.PrefKeys.showContrast.rawValue)
  static let friendlyName = NSNotification.Name(rawValue: Utils.PrefKeys.friendlyName.rawValue)
  static let preferenceReset = NSNotification.Name(rawValue: Utils.PrefKeys.preferenceReset.rawValue)
  static let displayListUpdate = NSNotification.Name(rawValue: Utils.PrefKeys.displayListUpdate.rawValue)
}
