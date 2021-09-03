import Cocoa
import os.log

class SliderHandler {
  var slider: NSSlider?
  var display: Display
  let cmd: Command

  public init(display: Display, command: Command) {
    self.display = display
    self.cmd = command
  }

  func valueChangedExternalDisplay(value: Int, maxValue: Double) {
    guard let externalDisplay = self.display as? ExternalDisplay else {
      return
    }
    // For the speaker volume slider, also set/unset the mute command when the value is changed from/to 0
    if self.cmd == .audioSpeakerVolume, (externalDisplay.isMuted() && value > 0) || (!externalDisplay.isMuted() && value == 0) {
      externalDisplay.toggleMute(fromVolumeSlider: true)
    }

    if !externalDisplay.isSw() {
      if self.cmd == Command.brightness, prefs.bool(forKey: Utils.PrefKeys.lowerSwAfterBrightness.rawValue) {
        var brightnessDDCValue: Int = 0
        var brightnessSwValue: Int = 100
        if value >= Int(maxValue / 2) {
          brightnessDDCValue = value - Int(maxValue / 2)
          brightnessSwValue = Int(self.display.getSwMaxBrightness())
        } else {
          brightnessDDCValue = 0
          brightnessSwValue = Int((Float(value) / Float(maxValue / 2)) * Float(self.display.getSwMaxBrightness()))
        }
        _ = externalDisplay.writeDDCValues(command: self.cmd, value: UInt16(brightnessDDCValue))
        _ = externalDisplay.setSwBrightness(value: UInt8(brightnessSwValue))
        externalDisplay.saveValue(brightnessDDCValue, for: self.cmd)
      } else if self.cmd == Command.audioSpeakerVolume {
        if !externalDisplay.enableMuteUnmute || value != 0 {
          _ = externalDisplay.writeDDCValues(command: self.cmd, value: UInt16(value))
        }
        externalDisplay.saveValue(value, for: self.cmd)
      } else {
        _ = externalDisplay.writeDDCValues(command: self.cmd, value: UInt16(value))
        externalDisplay.saveValue(value, for: self.cmd)
      }
    } else if self.cmd == Command.brightness {
      _ = externalDisplay.setSwBrightness(value: UInt8(value))
      externalDisplay.saveValue(value, for: self.cmd)
    }
  }

  @objc func valueChanged(slider: NSSlider) {
    guard app.sleepID == 0, app.reconfigureID == 0 else {
      return
    }

    var value = slider.integerValue
    let maxValue = slider.maxValue

    if !prefs.bool(forKey: Utils.PrefKeys.disableSliderSnap.rawValue) {
      let snapInterval = 25
      let snapThreshold = 3
      let closest = (value + snapInterval / 2) / snapInterval * snapInterval
      if abs(closest - value) <= snapThreshold {
        value = closest
        slider.integerValue = value
      }
    }

    if let appleDisplay = self.display as? AppleDisplay {
      appleDisplay.setBrightness(value: Float(value) / 100)
    } else {
      self.valueChangedExternalDisplay(value: value, maxValue: maxValue)
    }
  }

  static func addSliderMenuItem(toMenu menu: NSMenu, forDisplay display: Display, command: Command, title: String, numOfTickMarks: Int = 0) -> SliderHandler {
    let item = NSMenuItem()

    let handler = SliderHandler(display: display, command: command)

    let slider = NSSlider(value: 0, minValue: 0, maxValue: 100, target: handler, action: #selector(SliderHandler.valueChanged))
    slider.isEnabled = true
    slider.numberOfTickMarks = numOfTickMarks
    handler.slider = slider

    if #available(macOS 11.0, *) {
      slider.frame.size.width = 160
      slider.frame.origin = NSPoint(x: 35, y: 5)
      let view = NSView(frame: NSRect(x: 0, y: 0, width: slider.frame.width + 47, height: slider.frame.height + 14))
      view.frame.origin = NSPoint(x: 12, y: 0)
      var iconName: String = "circle.dashed"
      switch command {
      case .audioSpeakerVolume: iconName = "speaker.wave.2"
      case .brightness: iconName = "sun.max"
      case .contrast: iconName = "circle.lefthalf.fill"
      default: break
      }
      let icon = NSImageView(image: NSImage(systemSymbolName: iconName, accessibilityDescription: title)!)
      icon.frame = view.frame
      icon.wantsLayer = true
      icon.alphaValue = 0.7
      icon.imageAlignment = NSImageAlignment.alignLeft
      view.addSubview(icon)
      view.addSubview(slider)
      item.view = view
      menu.insertItem(item, at: 0)
    } else {
      slider.frame.size.width = 180
      slider.frame.origin = NSPoint(x: 15, y: 5)
      let view = NSView(frame: NSRect(x: 0, y: 0, width: slider.frame.width + 30, height: slider.frame.height + 10))
      let sliderHeaderItem = NSMenuItem()
      let attrs: [NSAttributedString.Key: Any] = [.foregroundColor: NSColor.systemGray, .font: NSFont.systemFont(ofSize: 12)]
      sliderHeaderItem.attributedTitle = NSAttributedString(string: title, attributes: attrs)
      view.addSubview(slider)
      item.view = view
      menu.insertItem(item, at: 0)
      menu.insertItem(sliderHeaderItem, at: 0)
    }

    if let externalDisplay = display as? ExternalDisplay {
      let (integerValue, maxValue) = externalDisplay.setupCurrentAndMaxValues(command: command)
      slider.maxValue = Double(maxValue)
      slider.integerValue = integerValue
    } else if let appleDisplay = display as? AppleDisplay {
      if command == .brightness {
        slider.maxValue = 100
        slider.integerValue = Int(appleDisplay.getBrightness() * 100)
      }
    }
    return handler
  }
}
