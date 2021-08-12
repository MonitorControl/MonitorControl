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
    guard app.sleepID == 0, app.reconfigureID == 0 else {
      return
    }
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

    if !self.display.isSw() {
      _ = self.display.writeDDCValues(command: self.cmd, value: UInt16(value))
    } else if self.cmd == DDC.Command.brightness {
      _ = self.display.setSwBrightness(value: UInt8(value))
    }
    self.display.saveValue(value, for: self.cmd)
  }
}
