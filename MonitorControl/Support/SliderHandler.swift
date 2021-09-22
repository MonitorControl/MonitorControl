//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Cocoa
import os.log

class SliderHandler {
  var slider: MCSlider?
  var percentageBox: NSTextField?
  var displays: [Display] = []
  var values: [CGDirectDisplayID: Float] = [:]
  let cmd: Command

  class MCSliderCell: NSSliderCell {
    var numOfCustomTickmarks: Int = 0
    var isFillBar: Bool = true
    var isHighlightDisplayItems: Bool = false
    var displayHighlightItems: [CGDirectDisplayID: Float] = [:]

    required init(coder aDecoder: NSCoder) {
      super.init(coder: aDecoder)
    }

    override init() {
      super.init()
    }

    override func drawKnob(_ knobRect: NSRect) {
      var sliderKnob: NSBezierPath
      if self.numOfCustomTickmarks > 0 {
        sliderKnob = NSBezierPath(roundedRect: NSRect(x: knobRect.origin.x + 2, y: knobRect.origin.y - 2, width: knobRect.height * 0.75, height: knobRect.height).insetBy(dx: 4, dy: 4), xRadius: 5, yRadius: 5)
      } else {
        sliderKnob = NSBezierPath(ovalIn: NSRect(x: knobRect.origin.x - 1.5, y: knobRect.origin.y - 2, width: knobRect.height, height: knobRect.height).insetBy(dx: 4, dy: 4))
      }
      NSColor(white: 1, alpha: 1).setFill()
      sliderKnob.fill()
      NSColor.tertiaryLabelColor.setStroke()
      sliderKnob.stroke()
    }

    override func drawBar(inside aRect: NSRect, flipped _: Bool) {
      let knobRect = knobRect(flipped: false)
      let sliderBar = NSBezierPath(roundedRect: aRect.insetBy(dx: 2, dy: 0), xRadius: aRect.height * 0.5, yRadius: aRect.height * 0.5)
      NSColor.tertiaryLabelColor.setFill()
      sliderBar.fill()

      if self.isFillBar {
        let sliderBarFillBounds = NSRect(x: aRect.insetBy(dx: 2, dy: 0).minX, y: aRect.minY, width: knobRect.midX - 3, height: aRect.height)
        let sliderBarFill = NSBezierPath(roundedRect: sliderBarFillBounds, xRadius: aRect.height * 0.5, yRadius: aRect.height * 0.5)
        NSColor.controlAccentColor.setFill()
        sliderBarFill.fill()
      }

      if self.numOfCustomTickmarks > 0 {
        for i in 0 ... self.numOfCustomTickmarks - 1 {
          let currentMarkLocation = (Float(1) / Float(self.numOfCustomTickmarks - 1)) * Float(i)
          let tickMarkBounds = NSRect(x: aRect.minX + 2 + 7 + CGFloat(Float(aRect.width - 6 - 14) * currentMarkLocation), y: aRect.minY - 3, width: 2, height: aRect.height + 6)
          let tickmark = NSBezierPath(roundedRect: tickMarkBounds, xRadius: 0.5, yRadius: 0.5)
          NSColor.quaternaryLabelColor.setFill()
          tickmark.fill()
        }
      }

      if self.isHighlightDisplayItems {
        var minValue: Float = 1
        var maxValue: Float = 0
        for displayID in self.displayHighlightItems.keys {
          if let currentMarkLocation = self.displayHighlightItems[displayID] {
            minValue = min(minValue, currentMarkLocation)
            maxValue = max(maxValue, currentMarkLocation)
            let HighlightBounds = NSRect(x: aRect.minX + (aRect.height + 6) / 2 + 0.5 + CGFloat(Float(aRect.width - 6 - 14) * currentMarkLocation), y: aRect.minY - 3, width: aRect.height + 6, height: aRect.height + 6)
            let highlight = NSBezierPath(ovalIn: HighlightBounds)
            NSColor(white: 1, alpha: 1).setFill()
            highlight.fill()
            NSColor.tertiaryLabelColor.setStroke()
            highlight.stroke()
          }
        }
        let sliderBarFillBounds = NSRect(x: aRect.minX + (aRect.height + 6) / 2 + 0.5 + CGFloat(Float(aRect.width - 6 - 14) * minValue) + 1, y: aRect.minY + 1, width: CGFloat(Float(aRect.width - 6 - 14) * maxValue) - CGFloat(Float(aRect.width - 6 - 14) * minValue) + 3, height: aRect.height - 2)
        let sliderBarFill = NSBezierPath(roundedRect: sliderBarFillBounds, xRadius: aRect.height * 0.5, yRadius: aRect.height * 0.5)
        NSColor(white: 1, alpha: 1).setFill()
        sliderBarFill.fill()
      }
    }
  }

  //  Credits for this class go to @thompsonate - https://github.com/thompsonate/Scrollable-NSSlider
  class MCSlider: NSSlider {
    required init?(coder: NSCoder) {
      super.init(coder: coder)
    }

    override init(frame frameRect: NSRect) {
      super.init(frame: frameRect)
      self.cell = MCSliderCell()
    }

    func setNumOfCustomTickmarks(_ numOfCustomTickmarks: Int) {
      if let cell = self.cell as? MCSliderCell {
        cell.numOfCustomTickmarks = numOfCustomTickmarks
      }
    }

    func setDisplayHighlightItems(_ isHighlightDisplayItems: Bool) {
      if let cell = self.cell as? MCSliderCell {
        cell.isHighlightDisplayItems = isHighlightDisplayItems
      }
    }

    func setHighlightItem(_ displayID: CGDirectDisplayID, value: Float) {
      if let cell = self.cell as? MCSliderCell {
        cell.displayHighlightItems[displayID] = value
      }
    }

    func removeHighlightItem(_ displayID: CGDirectDisplayID) {
      if let cell = self.cell as? MCSliderCell {
        if cell.displayHighlightItems[displayID] != nil {
          cell.displayHighlightItems[displayID] = nil
        }
      }
    }

    func resetHighlightItems() {
      if let cell = self.cell as? MCSliderCell {
        cell.displayHighlightItems.removeAll()
      }
    }

    override func scrollWheel(with event: NSEvent) {
      guard self.isEnabled else { return }
      let range = Float(self.maxValue - self.minValue)
      var delta = Float(0)
      if self.isVertical, self.sliderType == .linear {
        delta = Float(event.deltaY)
      } else if self.userInterfaceLayoutDirection == .rightToLeft {
        delta = Float(event.deltaY + event.deltaX)
      } else {
        delta = Float(event.deltaY - event.deltaX)
      }
      if event.isDirectionInvertedFromDevice {
        delta *= -1
      }
      let increment = range * delta / 100
      let value = self.floatValue + increment
      self.floatValue = value
      self.sendAction(self.action, to: self.target)
    }
  }

  public init(display: Display?, command: Command) {
    self.cmd = command
    if let displayToAppend = display {
      self.add(displayToAppend)
    }
  }

  func add(_ display: Display) {
    self.displays.append(display)
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

  @objc func valueChanged(slider: MCSlider) {
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
    for display in self.displays {
      slider.setHighlightItem(display.identifier, value: value)
      if self.cmd == .brightness, let appleDisplay = display as? AppleDisplay {
        _ = appleDisplay.setBrightness(value)
      } else if let otherDisplay = display as? OtherDisplay {
        self.valueChangedOtherDisplay(otherDisplay: otherDisplay, value: value)
      }
    }
    slider.setDisplayHighlightItems(false)
  }

  func setValue(_ value: Float, displayID: CGDirectDisplayID = 0) {
    if let slider = self.slider {
      if displayID != 0 {
        self.values[displayID] = value
        slider.setHighlightItem(displayID, value: value)
      }
      var sumVal: Float = 0
      var maxVal: Float = 0
      var minVal: Float = 1
      var num: Int = 0
      for key in self.values.keys {
        if let val = values[key] {
          sumVal += val
          maxVal = max(maxVal, val)
          minVal = min(minVal, val)
          num += 1
        }
      }
      // let average = sumVal / Float(num)
      slider.floatValue = value
      if abs(maxVal - minVal) > (2 / 100) {
        slider.setDisplayHighlightItems(true)
      } else {
        slider.setDisplayHighlightItems(false)
      }
      if self.percentageBox == self.percentageBox {
        self.percentageBox?.stringValue = "" + String(Int(value * 100)) + "%"
      }
    }
  }

  // Static and managerial functions

  static func setupPercentageBox(_ percentageBox: NSTextField) {
    percentageBox.font = NSFont.systemFont(ofSize: 12)
    percentageBox.isEditable = false
    percentageBox.isBordered = false
    percentageBox.drawsBackground = false
    percentageBox.alignment = .right
    percentageBox.alphaValue = 0.7
  }

  static func addSliderMenuItem(toMenu menu: NSMenu, forDisplay display: Display, command: Command, title: String, numOfTickMarks: Int = 0, sliderHandler: SliderHandler? = nil, position: Int = 0) -> SliderHandler {
    var handler: SliderHandler
    if sliderHandler != nil {
      handler = sliderHandler!
      handler.add(display)
    } else {
      let item = NSMenuItem()
      handler = SliderHandler(display: display, command: command)
      let slider = MCSlider(value: 0, minValue: 0, maxValue: 1, target: handler, action: #selector(SliderHandler.valueChanged))
      let showPercent = prefs.bool(forKey: PrefKey.enableSliderPercent.rawValue)
      slider.isEnabled = true
      slider.setNumOfCustomTickmarks(numOfTickMarks)
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
        menu.insertItem(item, at: position)
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
        menu.insertItem(item, at: position)
        menu.insertItem(sliderHeaderItem, at: position)
      }
      slider.maxValue = 1
    }
    if let otherDisplay = display as? OtherDisplay {
      let value = otherDisplay.setupSliderCurrentValue(command: command)
      handler.setValue(value, displayID: otherDisplay.identifier)
    } else if let appleDisplay = display as? AppleDisplay {
      if command == .brightness {
        handler.setValue(appleDisplay.getAppleBrightness(), displayID: appleDisplay.identifier)
      }
    }
    return handler
  }
}
