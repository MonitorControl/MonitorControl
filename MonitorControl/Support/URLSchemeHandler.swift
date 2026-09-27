//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Foundation
import os.log

/// Handles the `monitorcontrol://` URL scheme.
///
/// The scheme lets scripts, launchers and automation apps change the
/// brightness. It accepts these URLs:
///
///     monitorcontrol://brightness/set?value=10
///     monitorcontrol://brightness/set?value=10&display=all
///     monitorcontrol://brightness/change?delta=-10
///     monitorcontrol://brightness/change?delta=10&display=all
///
/// `value` and `delta` are percentages, not fractions. Give `display=all` to
/// change every display. Without it the app uses the display selection from
/// the settings, the same one the brightness keys use.
///
/// To switch the scheme off:
///
///     defaults write app.monitorcontrol.MonitorControl disableExternalControl -bool true
enum URLSchemeHandler {
  static let scheme = "monitorcontrol"

  /// Handles the URLs macOS delivered to the app.
  static func handle(_ urls: [URL]) {
    guard !prefs.bool(forKey: PrefKey.disableExternalControl.rawValue) else {
      os_log("Ignoring a URL because control from other apps is off.", type: .info)
      return
    }
    for url in urls where url.scheme?.lowercased() == self.scheme {
      self.handle(url)
    }
  }

  private static func handle(_ url: URL) {
    guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
      os_log("Ignoring a URL that cannot be read.", type: .info)
      return
    }
    let group = components.host?.lowercased() ?? ""
    let action = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
    var query: [String: String] = [:]
    for item in components.queryItems ?? [] {
      query[item.name.lowercased()] = item.value
    }
    let allDisplays = query["display"]?.lowercased() == "all"

    guard group == "brightness" else {
      os_log("Ignoring a URL with the unknown group %{public}@.", type: .info, group)
      return
    }
    switch action {
    case "set":
      guard let percent = self.percentage(query["value"]), percent >= 0 else {
        os_log("Ignoring a brightness URL without a usable value.", type: .info)
        return
      }
      BrightnessActions.setLevel(percent / 100, allDisplays: allDisplays, minimum: BrightnessActions.externalMinimumValue)
    case "change":
      guard let percent = self.percentage(query["delta"]) else {
        os_log("Ignoring a brightness URL without a usable delta.", type: .info)
        return
      }
      BrightnessActions.changeLevel(by: percent / 100, allDisplays: allDisplays, minimum: BrightnessActions.externalMinimumValue)
    default:
      os_log("Ignoring a brightness URL with the unknown action %{public}@.", type: .info, action)
    }
  }

  /// Reads a percentage from a query value. Returns nil if it is missing, not a
  /// number, or infinite.
  private static func percentage(_ raw: String?) -> Float? {
    guard let raw = raw, let value = Float(raw), value.isFinite else {
      return nil
    }
    return value
  }
}
