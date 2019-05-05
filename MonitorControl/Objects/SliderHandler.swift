import Cocoa

class SliderHandler {
  var slider: NSSlider?
  var display: Display
  var command: Int32 = 0

  public init(display: Display, command: Int32) {
    self.display = display
    self.command = command
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

    Utils.sendCommand(self.command, toMonitor: self.display.identifier, withValue: value)
    self.display.saveValue(value, for: self.command)
  }
}
