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

  func addSliderItem(monitorSubMenu: NSMenu, sliderHandler: SliderHandler, position: Int, title: String) {
    var macOS11orUp = false
    if !DEBUG_MACOS10, #available(macOS 11.0, *) {
      macOS11orUp = true
    }
    let item = NSMenuItem()
    item.view = sliderHandler.view
    monitorSubMenu.insertItem(item, at: position)
    if !macOS11orUp {
      let sliderHeaderItem = NSMenuItem()
      let attrs: [NSAttributedString.Key: Any] = [.foregroundColor: NSColor.systemGray, .font: NSFont.systemFont(ofSize: 12)]
      sliderHeaderItem.attributedTitle = NSAttributedString(string: title, attributes: attrs)
      monitorSubMenu.insertItem(sliderHeaderItem, at: position)
    }
  }

  func updateDisplayMenu(display: Display, asSubMenu: Bool, numOfDisplays: Int) {
    let relevant = prefs.bool(forKey: PrefKey.slidersRelevant.rawValue)
    let combine = prefs.bool(forKey: PrefKey.slidersCombine.rawValue)
    os_log("Addig menu item for display %{public}@", type: .info, "\(display.identifier)")
    let monitorSubMenu: NSMenu = asSubMenu ? NSMenu() : self
    var hasSlider = false
    display.brightnessSliderHandler = nil
    if let otherDisplay = display as? OtherDisplay, !otherDisplay.isSw() {
      otherDisplay.contrastSliderHandler = nil
      otherDisplay.volumeSliderHandler = nil
      if !display.readPrefAsBool(key: .unavailableDDC, for: .audioSpeakerVolume), !prefs.bool(forKey: PrefKey.hideVolume.rawValue) {
        let position = (combine && self.combinedBrightnessSliderHandler != nil) ? (self.combinedContrastSliderHandler != nil ? 2 : 1) : 0
        let title = NSLocalizedString("Volume", comment: "Shown in menu")
        let volumeSliderHandler = SliderHandler.sliderHandlerFactory(display: otherDisplay, command: .audioSpeakerVolume, title: title, combinedSliderHandler: combine ? self.combinedVolumeSliderHandler : nil)
        self.combinedVolumeSliderHandler = combine ? volumeSliderHandler : nil
        otherDisplay.volumeSliderHandler = volumeSliderHandler
        hasSlider = true
        addSliderItem(monitorSubMenu: monitorSubMenu, sliderHandler: volumeSliderHandler, position: position, title: title)
      }
      if prefs.bool(forKey: PrefKey.showContrast.rawValue), !display.readPrefAsBool(key: .unavailableDDC, for: .contrast) {
        let position = (combine && self.combinedBrightnessSliderHandler != nil) ? 1 : 0
        let title = NSLocalizedString("Contrast", comment: "Shown in menu")
        let contrastSliderHandler = SliderHandler.sliderHandlerFactory(display: otherDisplay, command: .contrast, title: title, combinedSliderHandler: combine ? self.combinedContrastSliderHandler : nil)
        self.combinedContrastSliderHandler = combine ? contrastSliderHandler : nil
        otherDisplay.contrastSliderHandler = contrastSliderHandler
        hasSlider = true
        addSliderItem(monitorSubMenu: monitorSubMenu, sliderHandler: contrastSliderHandler, position: position, title: title)
      }
    }
    if !prefs.bool(forKey: PrefKey.hideBrightness.rawValue), !display.readPrefAsBool(key: .unavailableDDC, for: .brightness) {
      let position = 0
      let title = NSLocalizedString("Brightness", comment: "Shown in menu")
      let brightnessSliderHandler = SliderHandler.sliderHandlerFactory(display: display, command: .brightness, title: title, combinedSliderHandler: combine ? self.combinedBrightnessSliderHandler : nil)
      display.brightnessSliderHandler = brightnessSliderHandler
      self.combinedBrightnessSliderHandler = combine ? brightnessSliderHandler : nil
      hasSlider = true
      addSliderItem(monitorSubMenu: monitorSubMenu, sliderHandler: brightnessSliderHandler, position: position, title: title)
    }
    if hasSlider, !relevant, !combine, numOfDisplays > 1 {
      self.appendMenuHeader(friendlyName: (display.readPrefAsString(key: .friendlyName) != "" ? display.readPrefAsString(key: .friendlyName) : display.name), monitorSubMenu: monitorSubMenu, asSubMenu: asSubMenu)
    }
    if prefs.integer(forKey: PrefKey.menuIcon.rawValue) == MenuIcon.sliderOnly.rawValue {
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
    if !DEBUG_MACOS10, #available(macOS 11.0, *), prefs.integer(forKey: PrefKey.menuItemStyle.rawValue) == MenuItemStyle.icon.rawValue {
      let iconSize = CGFloat(22)
      let viewWidth = CGFloat(194 + 16)

      let menuItemView = NSView(frame: NSRect(x: 0, y: 0, width: viewWidth, height: iconSize + 10))

      let preferencesIcon = NSButton()
      preferencesIcon.bezelStyle = .regularSquare
      preferencesIcon.isBordered = false
      preferencesIcon.setButtonType(.momentaryChange)
      preferencesIcon.image = NSImage(systemSymbolName: "ellipsis.circle", accessibilityDescription: NSLocalizedString("Preferences...", comment: "Shown in menu"))
      preferencesIcon.alternateImage = NSImage(systemSymbolName: "ellipsis.circle.fill", accessibilityDescription: NSLocalizedString("Preferences...", comment: "Shown in menu"))
      preferencesIcon.alphaValue = 0.3
      preferencesIcon.frame = NSRect(x: menuItemView.frame.maxX - iconSize - 16, y: menuItemView.frame.origin.y + 5, width: iconSize, height: iconSize)
      preferencesIcon.imageScaling = .scaleProportionallyUpOrDown
      preferencesIcon.action = #selector(app.prefsClicked)

      let quitIcon = NSButton()
      quitIcon.bezelStyle = .regularSquare
      quitIcon.isBordered = false
      quitIcon.setButtonType(.momentaryChange)
      quitIcon.image = NSImage(systemSymbolName: "xmark.circle", accessibilityDescription: NSLocalizedString("Quit", comment: "Shown in menu"))
      quitIcon.alternateImage = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: NSLocalizedString("Preferences...", comment: "Shown in menu"))
      quitIcon.alphaValue = 0.3
      quitIcon.frame = NSRect(x: menuItemView.frame.maxX - iconSize*2 - 10 - 16, y: menuItemView.frame.origin.y + 5, width: iconSize, height: iconSize)
      quitIcon.imageScaling = .scaleProportionallyUpOrDown
      quitIcon.action = #selector(app.quitClicked)

      menuItemView.addSubview(preferencesIcon)
      menuItemView.addSubview(quitIcon)
      let item = NSMenuItem()
      item.view = menuItemView
      self.addItem(item)
    } else if prefs.integer(forKey: PrefKey.menuItemStyle.rawValue) == MenuItemStyle.text.rawValue {
      self.addItem(withTitle: NSLocalizedString("Preferences...", comment: "Shown in menu"), action: #selector(app.prefsClicked), keyEquivalent: "")
      self.addItem(withTitle: NSLocalizedString("Quit", comment: "Shown in menu"), action: #selector(app.quitClicked), keyEquivalent: "")
      self.insertItem(NSMenuItem.separator(), at: 0)
    }
  }
}
