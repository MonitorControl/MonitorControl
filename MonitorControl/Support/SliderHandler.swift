//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Cocoa
import os.log

class SliderHandler {
  var slider: NSSlider?
  var percentageBox: NSTextField?
  var display: Display
  let cmd: Command

  public init(display: Display, command: Command) {
    self.display = display
    self.cmd = command
  }

  func valueChangedOtherDisplay(value: Float) {
    guard let otherDisplay = self.display as? OtherDisplay else {
      return
    }
    // For the speaker volume slider, also set/unset the mute command when the value is changed from/to 0
    if self.cmd == .audioSpeakerVolume, (otherDisplay.readPrefValueInt(for: .audioMuteScreenBlank) == 1 && value > 0) || (otherDisplay.readPrefValueInt(for: .audioMuteScreenBlank) != 1 && value == 0) {
      otherDisplay.toggleMute(fromVolumeSlider: true)
    }

    if !otherDisplay.isSw() {
      if self.cmd == Command.brightness, prefs.bool(forKey: PrefKey.lowerSwAfterBrightness.rawValue) {
        var brightnessValue: Float = 0
        var brightnessSwValue: Float = 1
        if value >= 0.5 {
          brightnessValue = (value - 0.5) * 2
          brightnessSwValue = 1
        } else {
          brightnessValue = 0
          brightnessSwValue = (value / 0.5)
        }
        _ = otherDisplay.writeDDCValues(command: self.cmd, value: otherDisplay.convValueToDDC(for: self.cmd, from: brightnessValue))
        _ = otherDisplay.setSwBrightness(value: brightnessSwValue)
      } else if self.cmd == Command.audioSpeakerVolume {
        if !otherDisplay.enableMuteUnmute || value != 0 {
          _ = otherDisplay.writeDDCValues(command: self.cmd, value: otherDisplay.convValueToDDC(for: self.cmd, from: value))
        }
      } else {
        _ = otherDisplay.writeDDCValues(command: self.cmd, value: otherDisplay.convValueToDDC(for: self.cmd, from: value))
      }
    } else if self.cmd == Command.brightness {
      _ = otherDisplay.setSwBrightness(value: value)
    }
    otherDisplay.savePrefValue(value, for: self.cmd)
  }

  @objc func valueChanged(slider: NSSlider) {
    guard app.sleepID == 0, app.reconfigureID == 0 else {
      return
    }

    var value = slider.floatValue

    if prefs.bool(forKey: PrefKey.enableSliderSnap.rawValue) {
      let intPercent = Int(value * 100)
      let snapInterval = 25
      let snapThreshold = 3
      let closest = (intPercent + snapInterval / 2) / snapInterval * snapInterval
      if abs(closest - intPercent) <= snapThreshold {
        value = Float(closest) / 100
        slider.floatValue = value
      }
    }

    if self.percentageBox == self.percentageBox {
      self.percentageBox?.stringValue = "" + String(Int(value * 100)) + "%"
    }

    if let appleDisplay = self.display as? AppleDisplay {
      _ = appleDisplay.setBrightness(value)
    } else {
      self.valueChangedOtherDisplay(value: value)
    }
  }

  func setValue(_ value: Float) {
    if let slider = self.slider {
      slider.floatValue = value
    }
    if self.percentageBox == self.percentageBox {
      self.percentageBox?.stringValue = "" + String(Int(value * 100)) + "%"
    }
  }

  static func addSliderMenuItem(toMenu menu: NSMenu, forDisplay display: Display, command: Command, title: String, numOfTickMarks: Int = 0) -> SliderHandler {
    let item = NSMenuItem()

    let handler = SliderHandler(display: display, command: command)

    let slider = NSSlider(value: 0, minValue: 0, maxValue: 1, target: handler, action: #selector(SliderHandler.valueChanged))
    slider.isEnabled = true
    slider.numberOfTickMarks = numOfTickMarks
    handler.slider = slider
    let showPercent = prefs.bool(forKey: PrefKey.enableSliderPercent.rawValue)

    if #available(macOS 11.0, *) {
      slider.frame.size.width = 160
      slider.frame.origin = NSPoint(x: 35, y: 5)
      let view = NSView(frame: NSRect(x: 0, y: 0, width: slider.frame.width + 47 + (showPercent ? 38 : 0), height: slider.frame.height + 14))
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
      if showPercent {
        let percentageBox = NSTextField(frame: NSRect(x: 35 + slider.frame.size.width - 2, y: 18, width: 40, height: 12))
        percentageBox.font = NSFont.systemFont(ofSize: 12)
        percentageBox.isEditable = false
        percentageBox.isBordered = false
        percentageBox.drawsBackground = false
        percentageBox.alignment = .right
        percentageBox.alphaValue = 0.7
        handler.percentageBox = percentageBox
        view.addSubview(percentageBox)
      }
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

    slider.maxValue = 1
    if let otherDisplay = display as? OtherDisplay {
      otherDisplay.setupCurrentAndMaxValues(command: command)
      let value = otherDisplay.setupSliderCurrentValue(command: command)
      handler.setValue(value)
    } else if let appleDisplay = display as? AppleDisplay {
      if command == .brightness {
        handler.setValue(appleDisplay.getAppleBrightness())
      }
    }
    return handler
  }
}
