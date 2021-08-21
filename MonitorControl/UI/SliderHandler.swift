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
      if self.cmd == DDC.Command.brightness, prefs.bool(forKey: Utils.PrefKeys.lowerSwAfterBrightness.rawValue) {
        var brightnessDDCValue: Int = 0
        var brightnessSwValue: Int = 100
        if value >= Int(slider.maxValue / 2) {
          brightnessDDCValue = slider.integerValue - Int(slider.maxValue / 2)
          brightnessSwValue = Int(self.display.getSwMaxBrightness())
        } else {
          brightnessDDCValue = 0
          brightnessSwValue = Int((Float(value) / Float(slider.maxValue / 2)) * Float(self.display.getSwMaxBrightness()))
        }
        _ = self.display.writeDDCValues(command: self.cmd, value: UInt16(brightnessDDCValue))
        _ = self.display.setSwBrightness(value: UInt8(brightnessSwValue))
        self.display.saveValue(brightnessDDCValue, for: self.cmd)
      } else {
        _ = self.display.writeDDCValues(command: self.cmd, value: UInt16(value))
        self.display.saveValue(value, for: self.cmd)
      }
    } else if self.cmd == DDC.Command.brightness {
      _ = self.display.setSwBrightness(value: UInt8(value))
      self.display.saveValue(value, for: self.cmd)
    }
  }
}
