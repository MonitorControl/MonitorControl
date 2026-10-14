//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Foundation

/// Keeps the other displays in step with a display that changed on its own (ambient
/// light, Touch Bar, System Settings or another app) while keeping the difference
/// the user set up between them.
///
/// Adding the reported delta straight to a display and clamping the result to 0...1
/// throws away whatever part of the change did not fit. A display that already sits
/// near the top of its range therefore loses ground on every ambient light swing up
/// but gets the whole change back on the way down, so the displays creep together
/// until every slider is aligned.
///
/// The anchor below is where the display would be if it had no ends, and it is what
/// the change is applied to. The part that did not fit is given back on the way down
/// instead of being lost, which is what keeps the offset intact.
enum BrightnessSync {
  /// A brightness difference smaller than this is neither settable by the user nor
  /// visible, so the display still counts as being where the last sync left it.
  static let tolerance: Float = 0.01

  /// How far outside of 0...1 an anchor is allowed to travel. The offset between two
  /// displays can never be wider than the whole range, so this only keeps the anchor
  /// in bounds if several displays report changes of their own at the same time.
  static let headroom: Float = 1

  struct Step {
    /// Where the display should be driven to now.
    let value: Float
    /// The anchor to hand back the next time this display is synced.
    let anchor: Float
  }

  /// `current` is where the display is now, `anchor` is what the previous step
  /// returned for it (nil if it has not been synced yet) and `delta` is the change
  /// the display that moved on its own reported.
  static func step(current: Float, anchor: Float?, delta: Float) -> Step {
    var anchor = anchor ?? current
    if abs(self.clamp(anchor) - current) > self.tolerance {
      // The display is not where the last sync left it, so the user moved this one
      // on purpose: that is the relationship to keep from here on.
      anchor = current
    }
    anchor = min(max(anchor + delta, -self.headroom), 1 + self.headroom)
    return Step(value: self.clamp(anchor), anchor: anchor)
  }

  static func clamp(_ value: Float) -> Float {
    min(max(value, 0), 1)
  }
}
