import Cocoa
import DDC

class SliderHandler {
  var slider: NSSlider?
  var display: ExternalDisplay
  let cmd: DDC.Command

  public init(display: ExternalDisplay, command: DDC.Command) {
    self.display = display
    self.cmd = command
  }

  @objc func valueChanged(slider: NSSlider) {
    let snapInterval = 25
    let snapThreshold = 3

    var value = slider.integerValue

    let closest = (value + snapInterval / 2) / snapInterval * snapInterval
    if abs(closest - value) <= snapThreshold {
      value = closest
      slider.integerValue = value
    }

    // For the speaker volume slider, also set/unset the mute command when the value is changed from/to 0
    if self.cmd == .audioSpeakerVolume, (self.display.isMuted() && value > 0) || (!self.display.isMuted() && value == 0) {
      self.display.toggleMute(fromVolumeSlider: true)
    }

    // If the command is to adjust contrast, exit ContrastAfterBirghtness mode if contrast is higher than the restore value
    if self.cmd == .contrast {
      if self.display.isContrastAfterBrightnessMode {
        if value >= self.display.getRestoreValue(for: .contrast) {
          self.display.isContrastAfterBrightnessMode = false
        }
      }
    }

    guard app.displaySleep == 0, !app.willReconfigureDisplay else {
      return
    }

    _ = self.display.writeDDCValues(command: self.cmd, value: UInt16(value))
    self.display.saveValue(value, for: self.cmd)
  }
}
