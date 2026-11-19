//  Copyright © MonitorControl contributors.

/// A starting point on MonitorControl's slider, not a measurement of panel luminance.
struct StartingBrightness: Equatable {
  let percent: Int

  init?(builtInLevel: Float) {
    guard builtInLevel.isFinite, builtInLevel > 0, builtInLevel <= 1 else { return nil }
    // Leave headroom for panels with different brightness curves. Avoid suggesting black
    // in a dark room. Both choices are heuristics and the user previews the level first.
    self.percent = max(15, Int((builtInLevel * 100 * 2 / 3).rounded()))
  }

  static func permitsSoftwareTarget(_ target: Float, reading: Float?) -> Bool {
    guard let current = reading, current.isFinite else { return false }
    return target <= current
  }

  // Only a normal zero hardware command is known to be dim-only without readback.
  static func permitsHardwareTarget(_ target: UInt16, inverted: Bool, reading: (current: UInt16, max: UInt16)?) -> Bool {
    if !inverted, target == 0 { return true }
    guard let reading = reading, reading.max > 0, reading.current <= reading.max, target <= reading.max else { return false }
    return inverted ? target >= reading.current : target <= reading.current
  }

  var level: Float { Float(self.percent) / 100 }

  func wouldDim(_ current: Float) -> Bool {
    current.isFinite && (0 ... 1).contains(current) && Int((current * 100).rounded()) > self.percent
  }
}
