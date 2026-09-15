//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Cocoa
import os.log

enum MenuLayout {
  static let width: CGFloat = 300
  static let inset: CGFloat = 12
}

class SliderHandler {
  var slider: MCSlider?
  var view: NSView?
  var percentageBox: NSTextField?
  var displays: [Display] = []
  var values: [CGDirectDisplayID: Float] = [:]
  var title: String
  let command: Command

  class MCSliderCell: NSSliderCell {
    var isHighlightDisplayItems = false
    var displayHighlightItems: [CGDirectDisplayID: Float] = [:]

    override func drawBar(inside aRect: NSRect, flipped: Bool) {
      super.drawBar(inside: aRect, flipped: flipped)
      // Keep individual display values visible when the combined slider differs.
      if self.isHighlightDisplayItems {
        NSColor.secondaryLabelColor.setFill()
        for value in self.displayHighlightItems.values {
          let fraction = CGFloat(min(1, max(0, value)))
          let position = self.controlView?.userInterfaceLayoutDirection == .rightToLeft ? 1 - fraction : fraction
          NSBezierPath(ovalIn: NSRect(x: aRect.minX + position * (aRect.width - 3), y: aRect.midY - 1.5, width: 3, height: 3)).fill()
        }
      }
    }
  }

  class MCSlider: NSSlider {
    required init?(coder: NSCoder) {
      super.init(coder: coder)
    }

    override init(frame frameRect: NSRect) {
      super.init(frame: frameRect)
      self.cell = MCSliderCell()
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

    ///  Credits for this class go to @thompsonate - https://github.com/thompsonate/Scrollable-NSSlider
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

  class ClickThroughImageView: NSImageView {
    override func hitTest(_ point: NSPoint) -> NSView? {
      subviews.first { subview in subview.hitTest(point) != nil
      }
    }
  }

  init(display: Display?, command: Command, title: String = "", position _: Int = 0) {
    self.command = command
    self.title = title
    let slider = SliderHandler.MCSlider(value: 0, minValue: 0, maxValue: 1, target: self, action: #selector(SliderHandler.valueChanged))
    let showPercent = prefs.bool(forKey: PrefKey.enableSliderPercent.rawValue)
    slider.isEnabled = true
    slider.numberOfTickMarks = prefs.bool(forKey: PrefKey.showTickMarks.rawValue) ? 5 : 0
    slider.allowsTickMarkValuesOnly = false
    self.slider = slider
    slider.setAccessibilityLabel(title)
    slider.trackFillColor = .controlAccentColor
    let width = MenuLayout.width
    let percentageBox = NSTextField(labelWithString: "100%")
    self.setupPercentageBox(percentageBox)
    percentageBox.maximumNumberOfLines = 1
    percentageBox.sizeToFit()
    let percentageWidth = ceil(percentageBox.frame.width)
    let endIconX = width - MenuLayout.inset - 18
    let sliderHeight: CGFloat = prefs.bool(forKey: PrefKey.showTickMarks.rawValue) ? 38 : 32
    let height = sliderHeight + (showPercent ? 10 : 0)
    let view = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))
    slider.frame = NSRect(x: 34, y: 6, width: endIconX - 42, height: sliderHeight - 12)
    view.addSubview(slider)
    let symbols: (String, String)
    switch command {
    case .brightness: symbols = ("sun.min.fill", "sun.max.fill")
    case .audioSpeakerVolume: symbols = ("speaker.fill", "speaker.wave.3.fill")
    default: symbols = ("circle.lefthalf.fill", "circle.righthalf.fill")
    }
    for (symbol, x) in [(symbols.0, CGFloat(12)), (symbols.1, endIconX)] {
      let icon = SliderHandler.ClickThroughImageView()
      icon.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
      icon.contentTintColor = .secondaryLabelColor
      icon.imageScaling = .scaleProportionallyUpOrDown
      icon.frame = NSRect(x: x, y: (sliderHeight - 18) / 2, width: 18, height: 18)
      view.addSubview(icon)
    }
    if showPercent {
      percentageBox.frame = NSRect(x: MenuLayout.inset, y: sliderHeight - 6, width: percentageWidth, height: 16)
      self.percentageBox = percentageBox
      view.addSubview(percentageBox)
    }
    self.view = view
    slider.maxValue = 1
    if let displayToAppend = display {
      self.addDisplay(displayToAppend)
    }
  }

  func addDisplay(_ display: Display) {
    self.displays.append(display)
    if let otherDisplay = display as? OtherDisplay {
      let value = otherDisplay.setupSliderCurrentValue(command: self.command)
      self.setValue(value, displayID: otherDisplay.identifier)
    } else if let appleDisplay = display as? AppleDisplay {
      if self.command == .brightness {
        self.setValue(appleDisplay.getAppleBrightness(), displayID: appleDisplay.identifier)
      }
    }
  }

  func setupPercentageBox(_ percentageBox: NSTextField) {
    percentageBox.font = NSFont.systemFont(ofSize: 11)
    percentageBox.isEditable = false
    percentageBox.isBordered = false
    percentageBox.drawsBackground = false
    percentageBox.alignment = .left
    percentageBox.textColor = .secondaryLabelColor
  }

  func valueChangedOtherDisplay(otherDisplay: OtherDisplay, value: Float) {
    // For the speaker volume slider, also set/unset the mute command when the value is changed from/to 0
    if self.command == .audioSpeakerVolume, (otherDisplay.readPrefAsInt(for: .audioMuteScreenBlank) == 1 && value > 0) || (otherDisplay.readPrefAsInt(for: .audioMuteScreenBlank) != 1 && value == 0) {
      otherDisplay.toggleMute(fromVolumeSlider: true)
    }
    if self.command == Command.brightness {
      _ = otherDisplay.setBrightness(value)
      return
    } else if !otherDisplay.isSw() {
      if self.command == Command.audioSpeakerVolume {
        if !otherDisplay.readPrefAsBool(key: .enableMuteUnmute) || value != 0 {
          otherDisplay.writeDDCValues(command: self.command, value: otherDisplay.convValueToDDC(for: self.command, from: value))
        }
      } else {
        otherDisplay.writeDDCValues(command: self.command, value: otherDisplay.convValueToDDC(for: self.command, from: value))
      }
      otherDisplay.savePref(value, for: self.command)
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
      if self.command == .brightness, let appleDisplay = display as? AppleDisplay {
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
      var num = 0
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
      if abs(maxVal - minVal) > 0.001 {
        slider.setDisplayHighlightItems(true)
      } else {
        slider.setDisplayHighlightItems(false)
      }
      if self.percentageBox == self.percentageBox {
        self.percentageBox?.stringValue = "\(String(format: "%.0f%%", Double(value) * 100))"
      }
    }
  }
}
