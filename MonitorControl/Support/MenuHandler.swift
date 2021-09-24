//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import AppKit
import os.log

class MenuHandler: NSMenu {

  var combinedBrightnessSliderHandler: SliderHandler?
  var combinedVolumeSliderHandler: SliderHandler?
  var combinedContrastSliderHandler: SliderHandler?
  var lastMenuRelevantDisplayId: CGDirectDisplayID = 0

  func clearMenu() {
    var items: [NSMenuItem] = []
    for i in 0 ..< self.items.count {
      items.append(self.items[i])
    }
    for item in items {
      self.removeItem(item)
    }
    self.addDefaultMenuOptions()
    self.combinedBrightnessSliderHandler = nil
    self.combinedVolumeSliderHandler = nil
    self.combinedContrastSliderHandler = nil
  }

  func updateMenus() {
    self.clearMenu()
    let currentDisplay = DisplayManager.shared.getCurrentDisplay()
    var displays: [Display] = []
    if !prefs.bool(forKey: PrefKey.hideAppleFromMenu.rawValue) {
      displays.append(contentsOf: DisplayManager.shared.getAppleDisplays())
    }
    if !prefs.bool(forKey: PrefKey.disableSoftwareFallback.rawValue) {
      displays.append(contentsOf: DisplayManager.shared.getOtherDisplays())
    } else {
      displays.append(contentsOf: DisplayManager.shared.getDdcCapableDisplays())
    }
    let relevant = prefs.bool(forKey: PrefKey.slidersRelevant.rawValue)
    let combine = prefs.bool(forKey: PrefKey.slidersCombine.rawValue)
    let numOfDisplays = displays.count
    if numOfDisplays != 0 {
      let asSubMenu: Bool = (displays.count > 3 && relevant && !combine) ? true : false
      var iterator = 0
      for display in displays where !relevant || display == currentDisplay {
        iterator += 1
        if !relevant, !combine, iterator != 1 {
          self.insertItem(NSMenuItem.separator(), at: 0)
        }
        self.updateDisplayMenu(display: display, asSubMenu: asSubMenu, numOfDisplays: numOfDisplays)
      }
    }
  }

  private func updateDisplayMenu(display: Display, asSubMenu: Bool, numOfDisplays: Int) {
    let relevant = prefs.bool(forKey: PrefKey.slidersRelevant.rawValue)
    let combine = prefs.bool(forKey: PrefKey.slidersCombine.rawValue)
    os_log("Addig menu item for display %{public}@", type: .info, "\(display.identifier)")
    let monitorSubMenu: NSMenu = asSubMenu ? NSMenu() : self
    let numOfTickMarks = prefs.bool(forKey: PrefKey.showTickMarks.rawValue) ? 5 : 0
    var hasSlider = false
    display.brightnessSliderHandler = nil
    if let otherDisplay = display as? OtherDisplay, !otherDisplay.isSw() {
      otherDisplay.contrastSliderHandler = nil
      otherDisplay.volumeSliderHandler = nil
      if !display.readPrefValueKeyBool(forkey: PrefKey.unavailableDDC, for: .audioSpeakerVolume), !prefs.bool(forKey: PrefKey.hideVolume.rawValue) {
        let position = (combine && self.combinedBrightnessSliderHandler != nil) ? (self.combinedContrastSliderHandler != nil ? 2 : 1) : 0
        let volumeSliderHandler = self.addSliderMenuItem(toMenu: monitorSubMenu, forDisplay: otherDisplay, command: .audioSpeakerVolume, title: NSLocalizedString("Volume", comment: "Shown in menu"), numOfTickMarks: numOfTickMarks, sliderHandler: combine ? self.combinedVolumeSliderHandler : nil, position: position)
        self.combinedVolumeSliderHandler = combine ? volumeSliderHandler : nil
        otherDisplay.volumeSliderHandler = volumeSliderHandler
        hasSlider = true
      }
      if prefs.bool(forKey: PrefKey.showContrast.rawValue), !display.readPrefValueKeyBool(forkey: PrefKey.unavailableDDC, for: .contrast) {
        let position = (combine && self.combinedBrightnessSliderHandler != nil) ? 1 : 0
        let contrastSliderHandler = self.addSliderMenuItem(toMenu: monitorSubMenu, forDisplay: otherDisplay, command: .contrast, title: NSLocalizedString("Contrast", comment: "Shown in menu"), numOfTickMarks: numOfTickMarks, sliderHandler: combine ? self.combinedContrastSliderHandler : nil, position: position)
        self.combinedContrastSliderHandler = combine ? contrastSliderHandler : nil
        otherDisplay.contrastSliderHandler = contrastSliderHandler
        hasSlider = true
      }
    }
    if !prefs.bool(forKey: PrefKey.hideBrightness.rawValue), !display.readPrefValueKeyBool(forkey: PrefKey.unavailableDDC, for: .brightness) {
      let brightnessSliderHandler = self.addSliderMenuItem(toMenu: monitorSubMenu, forDisplay: display, command: .brightness, title: NSLocalizedString("Brightness", comment: "Shown in menu"), numOfTickMarks: numOfTickMarks, sliderHandler: combine ? self.combinedBrightnessSliderHandler : nil)
      display.brightnessSliderHandler = brightnessSliderHandler
      self.combinedBrightnessSliderHandler = combine ? brightnessSliderHandler : nil
      hasSlider = true
    }
    if hasSlider, !relevant, !combine, numOfDisplays > 1 {
      self.appendMenuHeader(friendlyName: display.friendlyName, monitorSubMenu: monitorSubMenu, asSubMenu: asSubMenu)
    }
    if prefs.string(forKey: PrefKey.menuIcon.rawValue) == "sliderOnly" {
      app.statusItem.isVisible = hasSlider
    }
  }

  private func appendMenuHeader(friendlyName: String, monitorSubMenu: NSMenu, asSubMenu: Bool) {
    let monitorMenuItem = NSMenuItem()
    if asSubMenu {
      monitorMenuItem.title = "\(friendlyName)"
      monitorMenuItem.submenu = monitorSubMenu
    } else {
      let attrs: [NSAttributedString.Key: Any] = [.foregroundColor: NSColor.systemGray, .font: NSFont.boldSystemFont(ofSize: 12)]
      monitorMenuItem.attributedTitle = NSAttributedString(string: "\(friendlyName)", attributes: attrs)
    }
    self.insertItem(monitorMenuItem, at: 0)
  }

  func updateMenuRelevantDisplay() {
    if prefs.bool(forKey: PrefKey.slidersRelevant.rawValue) {
      if let display = DisplayManager.shared.getCurrentDisplay(), display.identifier != self.lastMenuRelevantDisplayId {
        os_log("Menu must be refreshed as relevant display changed since last time.")
        self.lastMenuRelevantDisplayId = display.identifier
        self.updateMenus()
      }
    }
  }

  func addDefaultMenuOptions() {
    if !DEBUG_MACOS10, #available(macOS 11.0, *) {
      let iconSize = CGFloat(22)
      let viewWidth = CGFloat(194)

      let menuItemView = NSView(frame: NSRect(x: 0, y: 0, width: viewWidth, height: iconSize + 10))

      let preferencesIcon = NSButton()
      preferencesIcon.bezelStyle = .inline
      preferencesIcon.isBordered = false
      preferencesIcon.setButtonType(.momentaryChange)
      preferencesIcon.image = NSImage(systemSymbolName: "ellipsis.circle", accessibilityDescription: NSLocalizedString("Preferences...", comment: "Shown in menu"))
      preferencesIcon.alternateImage = NSImage(systemSymbolName: "ellipsis.circle.fill", accessibilityDescription: NSLocalizedString("Preferences...", comment: "Shown in menu"))
      preferencesIcon.alphaValue = 0.3
      preferencesIcon.frame = NSRect(x: menuItemView.frame.maxX - iconSize, y: menuItemView.frame.origin.y + 5, width: iconSize, height: iconSize)
      preferencesIcon.imageScaling = .scaleProportionallyUpOrDown
      preferencesIcon.action = #selector(app.prefsClicked)

      let quitIcon = NSButton()
      quitIcon.bezelStyle = .inline
      quitIcon.isBordered = false
      quitIcon.setButtonType(.momentaryChange)
      quitIcon.image = NSImage(systemSymbolName: "xmark.circle", accessibilityDescription: NSLocalizedString("Quit", comment: "Shown in menu"))
      quitIcon.alternateImage = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: NSLocalizedString("Preferences...", comment: "Shown in menu"))
      quitIcon.alphaValue = 0.3
      quitIcon.frame = NSRect(x: menuItemView.frame.maxX - iconSize*2 - 10, y: menuItemView.frame.origin.y + 5, width: iconSize, height: iconSize)
      quitIcon.imageScaling = .scaleProportionallyUpOrDown
      quitIcon.action = #selector(app.quitClicked)

      menuItemView.addSubview(preferencesIcon)
      menuItemView.addSubview(quitIcon)
      let item = NSMenuItem()
      item.view = menuItemView
      self.addItem(item)
    } else {
      self.addItem(withTitle: NSLocalizedString("Preferences...", comment: "Shown in menu"), action: #selector(app.prefsClicked), keyEquivalent: "")
      self.addItem(withTitle: NSLocalizedString("Quit", comment: "Shown in menu"), action: #selector(app.quitClicked), keyEquivalent: "")
      self.insertItem(NSMenuItem.separator(), at: 0)
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

  func addSliderMenuItem(toMenu menu: NSMenu, forDisplay display: Display, command: Command, title: String, numOfTickMarks: Int = 0, sliderHandler: SliderHandler? = nil, position: Int = 0) -> SliderHandler {
    var handler: SliderHandler
    if sliderHandler != nil {
      handler = sliderHandler!
      handler.add(display)
    } else {
      let item = NSMenuItem()
      handler = SliderHandler(display: display, command: command)
      let slider = SliderHandler.MCSlider(value: 0, minValue: 0, maxValue: 1, target: handler, action: #selector(SliderHandler.valueChanged))
      let showPercent = prefs.bool(forKey: PrefKey.enableSliderPercent.rawValue)
      slider.isEnabled = true
      slider.setNumOfCustomTickmarks(numOfTickMarks)
      handler.slider = slider
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
        handler.icon = icon
        if showPercent {
          let percentageBox = NSTextField(frame: NSRect(x: 15 + slider.frame.size.width - 2, y: 17, width: 40, height: 12))
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
