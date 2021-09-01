import Cocoa
import os.log

class SliderHandler {
  var slider: NSSlider?
  var display: ExternalDisplay
  let cmd: Command

  public init(display: ExternalDisplay, command: Command) {
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
      if self.cmd == Command.brightness, prefs.bool(forKey: Utils.PrefKeys.lowerSwAfterBrightness.rawValue) {
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
      } else if self.cmd == Command.audioSpeakerVolume {
        if !self.display.enableMuteUnmute || value != 0 {
          _ = self.display.writeDDCValues(command: self.cmd, value: UInt16(value))
        }
        self.display.saveValue(value, for: self.cmd)
      } else {
        _ = self.display.writeDDCValues(command: self.cmd, value: UInt16(value))
        self.display.saveValue(value, for: self.cmd)
      }
    } else if self.cmd == Command.brightness {
      _ = self.display.setSwBrightness(value: UInt8(value))
      self.display.saveValue(value, for: self.cmd)
    }
  }

  static func addSliderMenuItem(toMenu menu: NSMenu, forDisplay display: ExternalDisplay, command: Command, title: String, numOfTickMarks: Int = 0) -> SliderHandler {
    let item = NSMenuItem()

    let handler = SliderHandler(display: display, command: command)

    let slider = NSSlider(value: 0, minValue: 0, maxValue: 100, target: handler, action: #selector(SliderHandler.valueChanged))
    slider.isEnabled = false
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

    var values: (UInt16, UInt16)?
    let delay = display.needsLongerDelay ? UInt64(40 * kMillisecondScale) : nil

    var (currentValue, maxValue) = (UInt16(0), UInt16(0))

    let tries = UInt(display.getPollingCount())

    if display.isSw(), command == Command.brightness {
      (currentValue, maxValue) = (UInt16(display.getSwBrightnessPrefValue()), UInt16(display.getSwMaxBrightness()))
    } else {
      if tries != 0, !(app.safeMode) {
        os_log("Polling %{public}@ times", type: .info, String(tries))
        values = display.readDDCValues(for: command, tries: tries, minReplyDelay: delay)
      }
      (currentValue, maxValue) = values ?? (UInt16(display.getValueExists(for: command) ? display.getValue(for: command) : 75), 100) // We set 100 as max value if we could not read DDC, the previous setting as current value or 75 if not present.
    }
    display.saveMaxValue(Int(maxValue), for: command)
    display.saveValue(min(Int(currentValue), display.getMaxValue(for: command)), for: command) // We won't allow currrent value to be higher than the max. value
    os_log("%{public}@ (%{public}@):", type: .info, display.name, String(reflecting: command))
    os_log(" - current value: %{public}@ - from display? %{public}@", type: .info, String(currentValue), String(values != nil))
    os_log(" - maximum value: %{public}@ - from display? %{public}@", type: .info, String(display.getMaxValue(for: command)), String(values != nil))

    if command == .brightness {
      if !display.isSw(), prefs.bool(forKey: Utils.PrefKeys.lowerSwAfterBrightness.rawValue) {
        slider.maxValue = Double(display.getMaxValue(for: command) * 2)
        slider.integerValue = Int(slider.maxValue) / 2 + Int(currentValue)
      } else {
        slider.integerValue = Int(currentValue)
        slider.maxValue = Double(display.getMaxValue(for: command))
      }
    } else if command == .audioSpeakerVolume {
      // If we're looking at the audio speaker volume, also retrieve the values for the mute command
      var muteValues: (current: UInt16, max: UInt16)?

      if display.enableMuteUnmute, tries != 0, !app.safeMode {
        os_log("Polling %{public}@ times", type: .info, String(tries))
        os_log("%{public}@ (%{public}@):", type: .info, display.name, String(reflecting: Command.audioMuteScreenBlank))
        muteValues = display.readDDCValues(for: .audioMuteScreenBlank, tries: tries, minReplyDelay: delay)
      }

      if let muteValues = muteValues {
        os_log(" - current ddc value: %{public}@", type: .info, String(muteValues.current))
        os_log(" - maximum ddc value: %{public}@", type: .info, String(muteValues.max))
        display.saveValue(Int(muteValues.current), for: .audioMuteScreenBlank)
        display.saveMaxValue(Int(muteValues.max), for: .audioMuteScreenBlank)
      } else {
        os_log(" - current ddc value: unknown", type: .info)
        os_log(" - stored maximum ddc value: %{public}@", type: .info, String(display.getMaxValue(for: .audioMuteScreenBlank)))
      }

      // If the system is not currently muted, or doesn't support the mute command, display the current volume as the slider value
      if muteValues == nil || muteValues!.current == 2 {
        slider.integerValue = Int(currentValue)
      } else {
        slider.integerValue = 0
      }

      slider.maxValue = Double(display.getMaxValue(for: command))
    } else {
      slider.integerValue = Int(currentValue)
      slider.maxValue = Double(display.getMaxValue(for: command))
    }

    slider.numberOfTickMarks = numOfTickMarks
    slider.isEnabled = true
    return handler
  }
}
