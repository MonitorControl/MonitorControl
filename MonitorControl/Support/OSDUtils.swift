//  Copyright © MonitorControl. @victorchabbert, @JoniVR, @theOneyouseek, @waydabber and others

import Cocoa
import os.log

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

  static func showOsd(displayID: CGDirectDisplayID, command: Command, value: Float, maxValue: Float = 1, roundChiclet: Bool = false, lock: Bool = false) {
    self.withOSD { manager in
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
  }

  static func showOsdVolumeDisabled(displayID: CGDirectDisplayID) {
    self.withOSD { manager in
      manager.showImage(22, onDisplayID: displayID, priority: 0x1F4, msecUntilFade: 1000)
    }
  }

  static func showOsdMuteDisabled(displayID: CGDirectDisplayID) {
    self.withOSD { manager in
      manager.showImage(21, onDisplayID: displayID, priority: 0x1F4, msecUntilFade: 1000)
    }
  }

  static func popEmptyOsd(displayID: CGDirectDisplayID, command: Command) {
    self.withOSD { manager in
      let osdImage = self.getOSDImageByCommand(command: command)
      manager.showImage(osdImage.rawValue, onDisplayID: displayID, priority: 0x1F4, msecUntilFade: 0)
    }
  }

  private static func withOSD(_ show: @escaping (OSDUIHelperProtocol) -> Void) {
    if #available(macOS 26.0, *), ProcessInfo.processInfo.operatingSystemVersion.majorVersion <= 27 {
      TraditionalOSD.show(show)
    } else if let manager = OSDManager.sharedManager() as? OSDManager {
      show(manager)
    }
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

@available(macOS 26.0, *)
private enum TraditionalOSD {
  private static var connection: NSXPCConnection?

  static func show(_ show: @escaping (OSDUIHelperProtocol) -> Void) {
    guard Thread.isMainThread else {
      DispatchQueue.main.async {
        self.show(show)
      }
      return
    }
    guard let helper = self.helper() else { return }
    show(helper)
  }

  private static func helper() -> OSDUIHelperProtocol? {
    let connection: NSXPCConnection
    if let existingConnection = self.connection {
      connection = existingConnection
    } else {
      connection = NSXPCConnection(machServiceName: "com.apple.OSDUIHelper", options: [])
      connection.remoteObjectInterface = NSXPCInterface(with: OSDUIHelperProtocol.self)
      connection.interruptionHandler = { [weak connection] in
        os_log("Traditional OSD XPC connection interrupted", type: .error)
        guard let connection = connection else { return }
        DispatchQueue.main.async {
          self.reset(connection)
        }
      }
      connection.invalidationHandler = { [weak connection] in
        guard let connection = connection else { return }
        DispatchQueue.main.async {
          if self.connection === connection {
            self.connection = nil
          }
        }
      }
      self.connection = connection
      connection.resume()
    }
    let proxy = connection.remoteObjectProxyWithErrorHandler { [weak connection] error in
      os_log("Traditional OSD XPC proxy error: %{public}@", type: .error, error.localizedDescription)
      guard let connection = connection else { return }
      DispatchQueue.main.async {
        self.reset(connection)
      }
    }
    guard let helper = proxy as? OSDUIHelperProtocol else {
      os_log("Unable to obtain Traditional OSD XPC proxy", type: .error)
      self.reset(connection)
      return nil
    }
    return helper
  }

  private static func reset(_ connection: NSXPCConnection) {
    guard self.connection === connection else { return }
    connection.interruptionHandler = nil
    connection.invalidationHandler = nil
    connection.invalidate()
    self.connection = nil
  }
}
