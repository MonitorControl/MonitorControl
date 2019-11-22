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

    switch self.cmd {
    case .audioSpeakerVolume:
      if self.cmd == .audioSpeakerVolume {
        // Only change volume after the mouse is released, like the native volume slider.
        if NSApplication.shared.currentEvent?.type == NSEvent.EventType.leftMouseUp {
          self.display.setVolume(to: value, fromVolumeSlider: true)
        }

        return
      }
    case .brightness:
      // Also instruct the display to set the contrast value, if necessary.
      self.display.setContrastValueForBrightness(value)
    case .contrast:
      // Erase the previous value for the contrast to restore after brightness is increased.
      self.display.setRestoreValue(nil, for: .contrast)
    default:
      assertionFailure("unsupported command for slider: \(self.cmd)")
    }

    if self.display.ddc?.write(command: self.cmd, value: UInt16(value)) == true {
      self.display.saveValue(value, for: self.cmd)
    }
  }
}
