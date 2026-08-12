//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Foundation
import os.log

/// Sets the brightness of the affected displays to an absolute level, or
/// changes it by a relative amount.
///
/// The preset keyboard shortcuts and the `monitorcontrol://` URL scheme both
/// call in here, so the two entry points always behave the same way.
enum BrightnessActions {
  /// The lowest level an outside caller can set. It stops a stray URL from
  /// making every screen fully black.
  static let externalMinimumValue: Float = 0.01

  /// Sets the brightness of the affected displays.
  ///
  /// - Parameters:
  ///   - value: The new brightness, from 0 to 1. Values outside that range are
  ///     clamped.
  ///   - allDisplays: Set this to true to change every display. If it is false,
  ///     the app uses the display selection from the settings.
  ///   - minimum: The lowest level to allow. Outside callers use this to keep a
  ///     screen from going fully black.
  /// - Returns: The number of displays that changed.
  @discardableResult static func setLevel(_ value: Float, allDisplays: Bool = false, minimum: Float = 0) -> Int {
    let target = max(minimum, min(1, value))
    var changed = 0
    for display in self.targetDisplays(allDisplays: allDisplays) where self.apply(target, to: display) {
      changed += 1
    }
    os_log("Brightness set to %{public}@ on %{public}@ display(s)", type: .info, String(target), String(changed))
    return changed
  }

  /// Changes the brightness of the affected displays by a relative amount.
  ///
  /// The app does the arithmetic per display, so a caller does not need to read
  /// the current level first.
  ///
  /// - Parameters:
  ///   - delta: The amount to add, from -1 to 1.
  ///   - allDisplays: Set this to true to change every display.
  ///   - minimum: The lowest level to allow.
  /// - Returns: The number of displays that changed.
  @discardableResult static func changeLevel(by delta: Float, allDisplays: Bool = false, minimum: Float = 0) -> Int {
    var changed = 0
    for display in self.targetDisplays(allDisplays: allDisplays) {
      let target = max(minimum, min(1, display.getBrightness() + delta))
      if self.apply(target, to: display) {
        changed += 1
      }
    }
    os_log("Brightness changed by %{public}@ on %{public}@ display(s)", type: .info, String(delta), String(changed))
    return changed
  }

  /// Returns the displays a brightness action applies to, without the ones the
  /// user disabled.
  private static func targetDisplays(allDisplays: Bool) -> [Display] {
    guard app.sleepID == 0, app.reconfigureID == 0 else {
      return []
    }
    let displays: [Display]
    if allDisplays {
      displays = DisplayManager.shared.getAllDisplays()
    } else {
      displays = DisplayManager.shared.getAffectedDisplays(isBrightness: true, isVolume: false) ?? []
    }
    return displays.filter { !$0.readPrefAsBool(key: .isDisabled) }
  }

  /// Sets one display and performs the same side effects as a brightness key
  /// press: the OSD, the menu slider, and the value the brightness sync reads.
  private static func apply(_ value: Float, to display: Display) -> Bool {
    guard !display.readPrefAsBool(key: .unavailableDDC, for: .brightness), display.setBrightness(value) else {
      return false
    }
    if !display.readPrefAsBool(key: .hideOsd) {
      OSDUtils.showOsd(displayID: display.identifier, command: .brightness, value: value * 64, maxValue: 64)
    }
    if let slider = display.sliderHandler[.brightness] {
      slider.setValue(value, displayID: display.identifier)
    }
    // Always update this, even without a slider. The brightness sync in
    // AppDelegate.job() compares against it, and a stale value makes the sync
    // push the difference to every other display.
    display.brightnessSyncSourceValue = value
    return true
  }
}

/// A fixed brightness level the user can put on a keyboard shortcut.
///
/// A preset always changes every display. A preset is a scene, so a level that
/// reached only the display under the pointer would be of little use.
enum BrightnessPreset: Int, CaseIterable {
  case first
  case second
  case third
  case fourth

  /// The level to use while the user has not set one. Without this a new
  /// install would put every preset at 0 percent, which is a black screen.
  var defaultPercentage: Int {
    switch self {
    case .first: return 10
    case .second: return 50
    case .third: return 75
    case .fourth: return 100
    }
  }

  var prefKey: PrefKey {
    switch self {
    case .first: return .brightnessPreset1
    case .second: return .brightnessPreset2
    case .third: return .brightnessPreset3
    case .fourth: return .brightnessPreset4
    }
  }

  /// The level this preset sets, from 0 to 100.
  var percentage: Int {
    get {
      guard prefs.object(forKey: self.prefKey.rawValue) != nil else {
        return self.defaultPercentage
      }
      return max(0, min(100, prefs.integer(forKey: self.prefKey.rawValue)))
    }
    nonmutating set {
      prefs.set(max(0, min(100, newValue)), forKey: self.prefKey.rawValue)
    }
  }

  /// Sets every display to the level of this preset.
  func apply() {
    BrightnessActions.setLevel(Float(self.percentage) / 100, allDisplays: true)
  }
}
