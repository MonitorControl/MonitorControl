//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Cocoa
import os.log

class SliderHandler {
  var slider: MCSlider?
  var view: NSView?
  var percentageBox: NSTextField?
  var displays: [Display] = []
  var values: [CGDirectDisplayID: Float] = [:]
  var title: String
  let command: Command
  var icon: ClickThroughImageView?

  class MCSliderCell: NSSliderCell {
    let knobFillColor = NSColor(white: 1, alpha: 1)
    let knobFillColorTracking = NSColor(white: 0.8, alpha: 1)
    let knobStrokeColor = NSColor.systemGray.withAlphaComponent(0.5)
    let knobShadowColor = NSColor(white: 0, alpha: 0.03)
    let barFillColor = NSColor.systemGray.withAlphaComponent(0.2)
    let barStrokeColor = NSColor.systemGray.withAlphaComponent(0.5)
    let barFilledFillColor = NSColor(white: 1, alpha: 1)
    let highlightDisplayIndicatorColor = NSColor(white: 0.85, alpha: 1) // This is visible if there is more the 2 displays
    let tickMarkColor = NSColor.systemGray.withAlphaComponent(0.5)

    let inset: CGFloat = 3.5
    let offsetX: CGFloat = -1.5
    let offsetY: CGFloat = -1.5

    let tickMarkKnobExtraInset: CGFloat = 4
    let tickMarkKnobExtraRadiusMultiplier: CGFloat = 0.25

    var numOfTickmarks: Int = 0
    var isHighlightDisplayItems: Bool = false
    var displayHighlightItems: [CGDirectDisplayID: Float] = [:]

    var isTracking: Bool = false

    required init(coder aDecoder: NSCoder) {
      super.init(coder: aDecoder)
    }

    override init() {
      super.init()
    }

    override func barRect(flipped: Bool) -> NSRect {
      let bar = super.barRect(flipped: flipped)
      let knob = super.knobRect(flipped: flipped)
      return NSRect(x: bar.origin.x, y: knob.origin.y, width: bar.width, height: knob.height).insetBy(dx: 0, dy: self.inset).offsetBy(dx: self.offsetX, dy: self.offsetY)
    }

    override func startTracking(at startPoint: NSPoint, in controlView: NSView) -> Bool {
      self.isTracking = true
      return super.startTracking(at: startPoint, in: controlView)
    }

    override func stopTracking(last lastPoint: NSPoint, current stopPoint: NSPoint, in controlView: NSView, mouseIsUp flag: Bool) {
      self.isTracking = false
      return super.stopTracking(last: lastPoint, current: stopPoint, in: controlView, mouseIsUp: flag)
    }

    override func drawKnob(_ knobRect: NSRect) {
      guard !DEBUG_MACOS10, #available(macOS 11.0, *) else {
        super.drawKnob(knobRect)
        return
      }
      // This is intentionally empty as the knob is inside the bar. Please leave it like this!
    }

    override func drawBar(inside aRect: NSRect, flipped: Bool) {
      guard !DEBUG_MACOS10, #available(macOS 11.0, *) else {
        super.drawBar(inside: aRect, flipped: flipped)
        return
      }
      var maxValue: Float = self.floatValue
      var minValue: Float = self.floatValue

      if self.isHighlightDisplayItems {
        maxValue = max(self.displayHighlightItems.values.max() ?? 0, maxValue)
        minValue = min(self.displayHighlightItems.values.min() ?? 1, minValue)
      }

      let barRadius = aRect.height * 0.5 * (self.numOfTickmarks == 0 ? 1 : self.tickMarkKnobExtraRadiusMultiplier)
      let bar = NSBezierPath(roundedRect: aRect, xRadius: barRadius, yRadius: barRadius)
      self.barFillColor.setFill()
      bar.fill()

      let barFilledWidth = (aRect.width - aRect.height) * CGFloat(maxValue) + aRect.height
      let barFilledRect = NSRect(x: aRect.origin.x, y: aRect.origin.y, width: barFilledWidth, height: aRect.height)
      let barFilled = NSBezierPath(roundedRect: barFilledRect, xRadius: barRadius, yRadius: barRadius)
      self.barFilledFillColor.setFill()
      barFilled.fill()

      let knobMinX = aRect.origin.x + (aRect.width - aRect.height) * CGFloat(minValue)
      let knobMaxX = aRect.origin.x + (aRect.width - aRect.height) * CGFloat(maxValue)
      let knobRect = NSRect(x: knobMinX + (self.numOfTickmarks == 0 ? CGFloat(0) : self.tickMarkKnobExtraInset), y: aRect.origin.y, width: aRect.height + CGFloat(knobMaxX - knobMinX), height: aRect.height).insetBy(dx: self.numOfTickmarks == 0 ? CGFloat(0) : self.tickMarkKnobExtraInset, dy: 0)
      let knobRadius = knobRect.height * 0.5 * (self.numOfTickmarks == 0 ? 1 : self.tickMarkKnobExtraRadiusMultiplier)

      if self.numOfTickmarks > 0 {
        for i in 1 ... self.numOfTickmarks - 2 {
          let currentMarkLocation = CGFloat((Float(1) / Float(self.numOfTickmarks - 1)) * Float(i))
          let tickMarkBounds = NSRect(x: aRect.origin.x + aRect.height + self.tickMarkKnobExtraInset - knobRect.height + self.tickMarkKnobExtraInset * 2 + CGFloat(Float((aRect.width - self.tickMarkKnobExtraInset * 5) * currentMarkLocation)), y: aRect.origin.y + aRect.height * (1 / 3), width: 4, height: aRect.height / 3)
          let tickmark = NSBezierPath(roundedRect: tickMarkBounds, xRadius: 1, yRadius: 1)
          self.tickMarkColor.setFill()
          tickmark.fill()
        }
      }

      let knobAlpha = CGFloat(max(0, min(1, (minValue - 0.08) * 5)))
      for i in 1 ... 3 {
        let knobShadow = NSBezierPath(roundedRect: knobRect.offsetBy(dx: CGFloat(-1 * 2 * i), dy: 0), xRadius: knobRadius, yRadius: knobRadius)
        self.knobShadowColor.withAlphaComponent(self.knobShadowColor.alphaComponent * knobAlpha).setFill()
        knobShadow.fill()
      }

      let knob = NSBezierPath(roundedRect: knobRect, xRadius: knobRadius, yRadius: knobRadius)
      (self.isTracking ? self.knobFillColorTracking : self.knobFillColor).withAlphaComponent(knobAlpha).setFill()
      knob.fill()

      if self.isHighlightDisplayItems, self.displayHighlightItems.count > 2 {
        for currentMarkLocation in self.displayHighlightItems.values {
          let highlightKnobX = aRect.origin.x + (aRect.width - aRect.height) * CGFloat(currentMarkLocation)
          let highlightKnobRect = NSRect(x: highlightKnobX + (self.numOfTickmarks == 0 ? CGFloat(0) : self.tickMarkKnobExtraInset), y: aRect.origin.y, width: aRect.height, height: aRect.height).insetBy(dx: (self.numOfTickmarks == 0 ? CGFloat(0) : self.tickMarkKnobExtraInset) + CGFloat(self.numOfTickmarks == 0 ? 6 : 3), dy: CGFloat(self.numOfTickmarks == 0 ? 6 : 6))
          let highlightKnobRadius = highlightKnobRect.height * 0.5 * (self.numOfTickmarks == 0 ? 1 : self.tickMarkKnobExtraRadiusMultiplier)
          let highlightKnob = NSBezierPath(roundedRect: highlightKnobRect, xRadius: highlightKnobRadius, yRadius: highlightKnobRadius)
          let highlightDisplayIndicatorAlpha = CGFloat(max(0, min(1, (currentMarkLocation - 0.08) * 5)))
          self.highlightDisplayIndicatorColor.withAlphaComponent(self.highlightDisplayIndicatorColor.alphaComponent * highlightDisplayIndicatorAlpha).setFill()
          highlightKnob.fill()
        }
      }

      self.knobStrokeColor.withAlphaComponent(self.knobStrokeColor.alphaComponent * knobAlpha).setStroke()
      knob.stroke()
      self.barStrokeColor.setStroke()
      bar.stroke()
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

    func setNumOfCustomTickmarks(_ numOfCustomTickmarks: Int) {
      if let cell = self.cell as? MCSliderCell {
        cell.numOfTickmarks = numOfCustomTickmarks
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

    //  Credits for this class go to @thompsonate - https://github.com/thompsonate/Scrollable-NSSlider
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

  public init(display: Display?, command: Command, title: String = "", position _: Int = 0) {
    self.command = command
    self.title = title
    let slider = SliderHandler.MCSlider(value: 0, minValue: 0, maxValue: 1, target: self, action: #selector(SliderHandler.valueChanged))
    let showPercent = prefs.bool(forKey: PrefKey.enableSliderPercent.rawValue)
    slider.isEnabled = true
    slider.setNumOfCustomTickmarks(prefs.bool(forKey: PrefKey.showTickMarks.rawValue) ? 5 : 0)
    self.slider = slider
    if !DEBUG_MACOS10, #available(macOS 11.0, *) {
      slider.frame.size.width = 180
      slider.frame.origin = NSPoint(x: 15, y: 5)
      let view = NSView(frame: NSRect(x: 0, y: 0, width: slider.frame.width + 30 + (showPercent ? 38 : 0), height: slider.frame.height + 14))
      view.frame.origin = NSPoint(x: 12, y: 0)
      var iconName: String = "circle.dashed"
      switch command {
      case .audioSpeakerVolume: iconName = "speaker.wave.2.fill"
      case .brightness: iconName = "sun.max.fill"
      case .contrast: iconName = "circle.lefthalf.fill"
      default: break
      }
      let icon = SliderHandler.ClickThroughImageView()
      icon.image = NSImage(systemSymbolName: iconName, accessibilityDescription: title)
      icon.contentTintColor = NSColor.black.withAlphaComponent(0.6)
      icon.frame = NSRect(x: view.frame.origin.x + 6.5, y: view.frame.origin.y + 13, width: 15, height: 15)
      icon.imageAlignment = .alignCenter
      view.addSubview(slider)
      view.addSubview(icon)
      self.icon = icon
      if showPercent {
        let percentageBox = NSTextField(frame: NSRect(x: 15 + slider.frame.size.width - 2, y: 17, width: 40, height: 12))
        self.setupPercentageBox(percentageBox)
        self.percentageBox = percentageBox
        view.addSubview(percentageBox)
      }
      self.view = view
    } else {
      slider.frame.size.width = 180
      slider.frame.origin = NSPoint(x: 15, y: 5)
      let view = NSView(frame: NSRect(x: 0, y: 0, width: slider.frame.width + 30 + (showPercent ? 38 : 0), height: slider.frame.height + 10))
      view.addSubview(slider)
      if showPercent {
        let percentageBox = NSTextField(frame: NSRect(x: 15 + slider.frame.size.width - 2, y: 18, width: 40, height: 12))
        self.setupPercentageBox(percentageBox)
        self.percentageBox = percentageBox
        view.addSubview(percentageBox)
      }
      self.view = view
    }
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
    percentageBox.font = NSFont.systemFont(ofSize: 12)
    percentageBox.isEditable = false
    percentageBox.isBordered = false
    percentageBox.drawsBackground = false
    percentageBox.alignment = .right
    percentageBox.alphaValue = 0.7
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
    self.updateIcon()
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

  func updateIcon() {
    // This looks hideous so I disable it for now. Maybe after a bit of tinkering it will look better
    /*
     if self.command == .audioSpeakerVolume {
       let value = self.slider?.floatValue ?? 0.5
       if value > 2/3 {
         self.icon?.image = NSImage(systemSymbolName: "speaker.wave.3.fill", accessibilityDescription: "")
       } else if value > 1/3 {
         self.icon?.image = NSImage(systemSymbolName: "speaker.wave.2.fill", accessibilityDescription: "")
       } else if value != 0 {
         self.icon?.image = NSImage(systemSymbolName: "speaker.wave.1.fill", accessibilityDescription: "")
       } else {
         self.icon?.image = NSImage(systemSymbolName: "speaker.slash.fill", accessibilityDescription: "")
       }
     }
     */
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
      self.updateIcon()
      if abs(maxVal - minVal) > 0.001 {
        slider.setDisplayHighlightItems(true)
      } else {
        slider.setDisplayHighlightItems(false)
      }
      if self.percentageBox == self.percentageBox {
        self.percentageBox?.stringValue = "" + String(Int(value * 100)) + "%"
      }
    }
  }
}
