//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Cocoa

/// Provides display selection and naming helpers for the equal-brightness editor.
/// 为等亮度编辑器提供显示器选择和命名辅助函数。
enum EqualBrightnessDisplaySupport {
  /// Returns a stable user-facing name with a localized fallback.
  /// 返回稳定的用户可见名称，并提供本地化兜底名称。
  static func userFacingName(for display: Display, fallbackIndex: Int = 0) -> String {
    let friendlyName = display.readPrefAsString(key: .friendlyName).trimmingCharacters(in: .whitespacesAndNewlines)
    if !friendlyName.isEmpty {
      return friendlyName
    }
    let displayName = display.name.trimmingCharacters(in: .whitespacesAndNewlines)
    if !displayName.isEmpty {
      return displayName
    }
    if CGDisplayIsBuiltin(display.identifier) != 0 {
      return NSLocalizedString("Built-in Display", comment: "Fallback built-in display name")
    }
    let externalName = NSLocalizedString("External Display", comment: "Fallback external display name")
    return "\(externalName) \(fallbackIndex + 1)"
  }

  /// Chooses the built-in or first Apple display as the reference display.
  /// 选择内置显示器或第一台 Apple 显示器作为参考显示器。
  static func referenceDisplay(from displays: [Display]) -> Display? {
    DisplayManager.shared.getBuiltInDisplay()
      ?? DisplayManager.shared.getAppleDisplays().first
      ?? displays.first
  }

  /// Removes the reference display from the list of target displays.
  /// 从目标显示器列表中移除参考显示器。
  static func targetDisplays(from displays: [Display], reference: Display?) -> [Display] {
    displays.filter { display in
      guard let reference else {
        return true
      }
      return display != reference
    }
  }
}
