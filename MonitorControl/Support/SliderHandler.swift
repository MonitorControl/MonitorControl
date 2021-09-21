//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Cocoa
import os.log

class SliderHandler {
  var slider: ScrollableSlider?
  var percentageBox: NSTextField?
  var display: Display?
  let cmd: Command

  //  Credits for this class go to @thompsonate - https://github.com/thompsonate/Scrollable-NSSlider
  class ScrollableSlider: NSSlider {
    override func scrollWheel(with event: NSEvent) {
      guard self.isEnabled else { return }
      let range = Float(self.maxValue - self.minValue)
      var delta = Float(0)
      // Allow horizontal scrolling on horizontal and circular sliders
      if self.isVertical, self.sliderType == .linear {
        delta = Float(event.deltaY)
      } else if self.userInterfaceLayoutDirection == .rightToLeft {
        delta = Float(event.deltaY + event.deltaX)
      } else {
        delta = Float(event.deltaY - event.deltaX)
      }
      // Account for natural scrolling
      if event.isDirectionInvertedFromDevice {
        delta *= -1
      }
      let increment = range * delta / 100
      var value = self.floatValue + increment
      // Wrap around if slider is circular
      if self.sliderType == .circular {
        let minValue = Float(self.minValue)
        let maxValue = Float(self.maxValue)
        if value < minValue {
          value = maxValue - abs(increment)
        } else if value > maxValue {
          value = minValue + abs(increment)
        }
      }
      self.floatValue = value
      self.sendAction(self.action, to: self.target)
    }
  }

  public init(display: Display?, command: Command) {
    if display == display {
      self.display = display
    }
    self.cmd = command
  }

  func valueChangedOtherDisplay(otherDisplay: OtherDisplay, value: Float) {
    // For the speaker volume slider, also set/unset the mute command when the value is changed from/to 0
    if self.cmd == .audioSpeakerVolume, (otherDisplay.readPrefValueInt(for: .audioMuteScreenBlank) == 1 && value > 0) || (otherDisplay.readPrefValueInt(for: .audioMuteScreenBlank) != 1 && value == 0) {
      otherDisplay.toggleMute(fromVolumeSlider: true)
    }
    if self.cmd == Command.brightness {
      _ = otherDisplay.setBrightness(value)
      return
    } else if !otherDisplay.isSw() {
      if self.cmd == Command.audioSpeakerVolume {
        if !otherDisplay.enableMuteUnmute || value != 0 {
          _ = otherDisplay.writeDDCValues(command: self.cmd, value: otherDisplay.convValueToDDC(for: self.cmd, from: value))
        }
      } else {
        _ = otherDisplay.writeDDCValues(command: self.cmd, value: otherDisplay.convValueToDDC(for: self.cmd, from: value))
      }
      otherDisplay.savePrefValue(value, for: self.cmd)
    }
  }

  func valueChangedUnified(value _: Float) {
    // TODO: What happens if the slider is unified?
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
    } else if let otherDisplay = self.display as? OtherDisplay {
      self.valueChangedOtherDisplay(otherDisplay: otherDisplay, value: value)
    } else {
      self.valueChangedUnified(value: value)
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

  static func setupPercentageBox(_ percentageBox: NSTextField) {
    percentageBox.font = NSFont.systemFont(ofSize: 12)
    percentageBox.isEditable = false
    percentageBox.isBordered = false
    percentageBox.drawsBackground = false
    percentageBox.alignment = .right
    percentageBox.alphaValue = 0.7
  }

  static func addSliderMenuItem(toMenu menu: NSMenu, forDisplay display: Display, command: Command, title: String, numOfTickMarks: Int = 0) -> SliderHandler {
    let item = NSMenuItem()
    let handler = SliderHandler(display: display, command: command)
    let slider = ScrollableSlider(value: 0, minValue: 0, maxValue: 1, target: handler, action: #selector(SliderHandler.valueChanged))
    let showPercent = prefs.bool(forKey: PrefKey.enableSliderPercent.rawValue)
    slider.isEnabled = true
    slider.numberOfTickMarks = numOfTickMarks
    handler.slider = slider
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
        self.setupPercentageBox(percentageBox)
        handler.percentageBox = percentageBox
        view.addSubview(percentageBox)
      }
      item.view = view
      menu.insertItem(item, at: 0)
    } else {
      slider.frame.size.width = 180
      slider.frame.origin = NSPoint(x: 15, y: 5)
      let view = NSView(frame: NSRect(x: 0, y: 0, width: slider.frame.width + 30 + (showPercent ? 38 : 0), height: slider.frame.height + 10))
      let sliderHeaderItem = NSMenuItem()
      let attrs: [NSAttributedString.Key: Any] = [.foregroundColor: NSColor.systemGray, .font: NSFont.systemFont(ofSize: 12)]
      sliderHeaderItem.attributedTitle = NSAttributedString(string: title, attributes: attrs)
      view.addSubview(slider)
      if showPercent {
        let percentageBox = NSTextField(frame: NSRect(x: 15 + slider.frame.size.width - 2, y: 18, width: 40, height: 12))
        self.setupPercentageBox(percentageBox)
        handler.percentageBox = percentageBox
        view.addSubview(percentageBox)
      }
      item.view = view
      menu.insertItem(item, at: 0)
      menu.insertItem(sliderHeaderItem, at: 0)
    }
    slider.maxValue = 1
    if let otherDisplay = display as? OtherDisplay {
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
