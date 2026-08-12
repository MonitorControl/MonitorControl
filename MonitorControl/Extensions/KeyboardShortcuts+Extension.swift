//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import KeyboardShortcuts

extension KeyboardShortcuts.Name {
  static let brightnessUp = Self("brightnessUp")
  static let brightnessDown = Self("brightnessDown")
  static let contrastUp = Self("contrastUp")
  static let contrastDown = Self("contrastDown")
  static let volumeUp = Self("volumeUp")
  static let volumeDown = Self("volumeDown")
  static let mute = Self("mute")

  static let brightnessPreset1 = Self("brightnessPreset1")
  static let brightnessPreset2 = Self("brightnessPreset2")
  static let brightnessPreset3 = Self("brightnessPreset3")
  static let brightnessPreset4 = Self("brightnessPreset4")

  static let none = Self("none")
}

extension BrightnessPreset {
  var shortcutName: KeyboardShortcuts.Name {
    switch self {
    case .first: return .brightnessPreset1
    case .second: return .brightnessPreset2
    case .third: return .brightnessPreset3
    case .fourth: return .brightnessPreset4
    }
  }
}
