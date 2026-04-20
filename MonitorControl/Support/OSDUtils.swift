//  Copyright © MonitorControl. @victorchabbert, @JoniVR, @theOneyouseek, @waydabber and others

import Cocoa

class OSDUtils: NSObject {
  enum OSDImage: Int64 {
    case brightness = 1
    case audioSpeaker = 3
    case audioSpeakerMuted = 4
    case contrast = 0
  }

  static func getOSDImageByCommand(command: Command, value: Float = 1) -> OSDImage {
    var osdImage: OSDImage
    switch command {
    case .audioSpeakerVolume: osdImage = value > 0 ? .audioSpeaker : .audioSpeakerMuted
    case .audioMuteScreenBlank: osdImage = .audioSpeakerMuted
    case .contrast: osdImage = .contrast
    default: osdImage = .brightness
    }
    return osdImage
  }

  /// Check if we're running on macOS 26 (Tahoe) or later where native OSD is broken
  private static var shouldUseCustomHUD: Bool {
    if #available(macOS 26, *) {
      return true
    }
    return false
  }

  /// Convert Command to HUDType for custom HUD
  private static func getHUDType(command: Command, value: Float) -> HUDType {
    switch command {
    case .audioSpeakerVolume:
      return value > 0 ? .volume : .volumeMuted
    case .audioMuteScreenBlank:
      return .volumeMuted
    case .contrast:
      return .contrast
    default:
      return .brightness
    }
  }

  static func showOsd(displayID: CGDirectDisplayID, command: Command, value: Float, maxValue: Float = 1, roundChiclet: Bool = false, lock: Bool = false) {
    // Use custom HUD on macOS 26+ where native OSD is broken
    if shouldUseCustomHUD {
      let hudType = getHUDType(command: command, value: value)
      CustomHUDManager.shared.showHUD(displayID: displayID, type: hudType, value: value, maxValue: maxValue)
      return
    }
    
    // Fallback to native OSD for older macOS versions
    guard let manager = OSDManager.sharedManager() as? OSDManager else {
      return
    }
    let osdImage = self.getOSDImageByCommand(command: command, value: value)
    let filledChiclets: Int
    let totalChiclets: Int
    if roundChiclet {
      let osdChiclet = OSDUtils.chiclet(fromValue: value, maxValue: maxValue)
      filledChiclets = Int(round(osdChiclet))
      totalChiclets = 16
    } else {
      filledChiclets = Int(value * 100)
      totalChiclets = Int(maxValue * 100)
    }
    manager.showImage(osdImage.rawValue, onDisplayID: displayID, priority: 0x1F4, msecUntilFade: 1000, filledChiclets: UInt32(filledChiclets), totalChiclets: UInt32(totalChiclets), locked: lock)
  }

  static func showOsdVolumeDisabled(displayID: CGDirectDisplayID) {
    if shouldUseCustomHUD {
      CustomHUDManager.shared.showHUD(displayID: displayID, type: .volumeMuted, value: 0, maxValue: 1)
      return
    }
    
    guard let manager = OSDManager.sharedManager() as? OSDManager else {
      return
    }
    manager.showImage(22, onDisplayID: displayID, priority: 0x1F4, msecUntilFade: 1000)
  }

  static func showOsdMuteDisabled(displayID: CGDirectDisplayID) {
    if shouldUseCustomHUD {
      CustomHUDManager.shared.showHUD(displayID: displayID, type: .volumeMuted, value: 0, maxValue: 1)
      return
    }
    
    guard let manager = OSDManager.sharedManager() as? OSDManager else {
      return
    }
    manager.showImage(21, onDisplayID: displayID, priority: 0x1F4, msecUntilFade: 1000)
  }

  static func popEmptyOsd(displayID: CGDirectDisplayID, command: Command) {
    if shouldUseCustomHUD {
      let hudType = getHUDType(command: command, value: 0)
      CustomHUDManager.shared.showHUD(displayID: displayID, type: hudType, value: 0, maxValue: 1)
      return
    }
    
    guard let manager = OSDManager.sharedManager() as? OSDManager else {
      return
    }
    let osdImage = self.getOSDImageByCommand(command: command)
    manager.showImage(osdImage.rawValue, onDisplayID: displayID, priority: 0x1F4, msecUntilFade: 0)
  }

  static let chicletCount: Float = 16

  static func chiclet(fromValue value: Float, maxValue: Float, half: Bool = false) -> Float {
    (value * self.chicletCount * (half ? 2 : 1)) / maxValue
  }

  static func value(fromChiclet chiclet: Float, maxValue: Float, half: Bool = false) -> Float {
    (chiclet * maxValue) / (self.chicletCount * (half ? 2 : 1))
  }

  static func getDistance(fromNearestChiclet chiclet: Float) -> Float {
    abs(chiclet.rounded(.towardZero) - chiclet)
  }
}

