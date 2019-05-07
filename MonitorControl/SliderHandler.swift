import Cocoa
import DDC

class SliderHandler {
  var slider: NSSlider?
  var display: Display
  let cmd: DDC.Command

  public init(display: Display, command: DDC.Command) {
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

    _ = self.display.ddc?.write(command: self.cmd, value: UInt8(value))
    self.display.saveValue(value, for: self.cmd)
  }
}
