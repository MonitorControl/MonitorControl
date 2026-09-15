// Adapted from Crisp. Copyright (c) 2026 Didrik Galteland.
// Distributed under the MIT license; see MonitorControl/UI/Crisp-LICENSE.txt.

import Foundation

/// Runtime-only bridge, like the existing Night Shift toggle. No private framework
/// linkage or stored preference writes; CoreBrightness commits the system setting.
final class NightShiftTemperatureClient: @unchecked Sendable {
  private let client: NSObject
  private let queue = DispatchQueue(label: "me.guillaumeb.MonitorControl.nightShiftTemperature", qos: .userInitiated)
  private let getSelector = NSSelectorFromString("getStrength:")
  private let setSelector = NSSelectorFromString("setStrength:commit:")

  init?(client: NSObject) {
    guard client.responds(to: self.getSelector), client.responds(to: self.setSelector) else { return nil }
    self.client = client
  }

  func read() async -> Float? {
    await withCheckedContinuation { continuation in
      self.queue.async { [self] in
        typealias Get = @convention(c) (NSObject, Selector, UnsafeMutablePointer<Float>) -> Bool
        var value: Float = 0
        let success = unsafeBitCast(client.method(for: self.getSelector), to: Get.self)(self.client, self.getSelector, &value)
        continuation.resume(returning: success ? value : nil)
      }
    }
  }

  func write(_ value: Float) async -> Bool {
    await withCheckedContinuation { continuation in
      self.queue.async { [self] in
        typealias Set = @convention(c) (NSObject, Selector, Float, Bool) -> Bool
        let success = unsafeBitCast(client.method(for: self.setSelector), to: Set.self)(self.client, self.setSelector, value, true)
        continuation.resume(returning: success)
      }
    }
  }
}
