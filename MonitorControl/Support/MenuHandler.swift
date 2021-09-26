//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import AppKit
import os.log

class MenuHandler: NSMenu {
  var combinedSliderHandler: [Command: SliderHandler] = [:]

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
    combinedSliderHandler.removeAll()
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
          self.insertItem(NSMenuItem.separator(), at: 0) // TODO: This stuff will be needed for macOS10 and classic menu view, but should not be located here!
        }
        self.updateDisplayMenu(display: display, asSubMenu: asSubMenu, numOfDisplays: numOfDisplays)
      }
      if combine {
        self.addCombinedDisplayMenuBlock()
      }
    }
  }

  func addSliderItem(monitorSubMenu: NSMenu, sliderHandler: SliderHandler) {
    var macOS11orUp = false
    if !DEBUG_MACOS10, #available(macOS 11.0, *) {
      macOS11orUp = true
    }
    let item = NSMenuItem()
    item.view = sliderHandler.view
    monitorSubMenu.insertItem(item, at: 0)
    if !macOS11orUp {
      let sliderHeaderItem = NSMenuItem()
      let attrs: [NSAttributedString.Key: Any] = [.foregroundColor: NSColor.systemGray, .font: NSFont.systemFont(ofSize: 12)]
      sliderHeaderItem.attributedTitle = NSAttributedString(string: sliderHandler.title, attributes: attrs)
      monitorSubMenu.insertItem(sliderHeaderItem, at: 0)
    }
  }

  func setupMenuSliderHandler(command: Command, display: Display, title: String) -> SliderHandler {
    if prefs.bool(forKey: PrefKey.slidersCombine.rawValue), let combinedHandler = self.combinedSliderHandler[command] {
      combinedHandler.addDisplay(display)
      display.sliderHandler[command] = combinedHandler
      return combinedHandler
    } else {
      let sliderHandler = SliderHandler(display: display, command: command, title: title)
      if prefs.bool(forKey: PrefKey.slidersCombine.rawValue) {
        self.combinedSliderHandler[command] = sliderHandler
      }
      display.sliderHandler[command] = sliderHandler
      return sliderHandler
    }
  }

  func addDisplayMenuBlock(addedSliderHandlers: [SliderHandler], blockName: String, monitorSubMenu: NSMenu) {
    if false, !DEBUG_MACOS10, #available(macOS 11.0, *) { // TODO: The new menu look is still under construction so it is disabled in the commit
      class BlockView: NSView {
        override func draw(_ dirtyRect: NSRect) {
          let radius = CGFloat(11)
          let outerMargin = CGFloat(15)
          let blockRect = self.frame.insetBy(dx: outerMargin, dy: outerMargin/2 + 2).offsetBy(dx: 0, dy: outerMargin/2 * -1 + 1)
          for i in 1...5 {
            let blockPath = NSBezierPath(roundedRect: blockRect.insetBy(dx: CGFloat(i) * -1, dy: CGFloat(i) * -1), xRadius: radius + CGFloat(i) * 0.5, yRadius: radius + CGFloat(i) * 0.5)
            NSColor.black.withAlphaComponent(0.1 / CGFloat(i)).setStroke()
            blockPath.stroke()
          }
          let blockPath = NSBezierPath(roundedRect: blockRect, xRadius: radius, yRadius: radius)
          if [NSAppearance.Name.darkAqua, NSAppearance.Name.vibrantDark].contains(effectiveAppearance.name) {
            NSColor.systemGray.withAlphaComponent(0.3).setStroke()
            blockPath.stroke()
          }
          if !([NSAppearance.Name.darkAqua, NSAppearance.Name.vibrantDark].contains(effectiveAppearance.name)) {
            NSColor.white.withAlphaComponent(0.5).setFill()
            blockPath.fill()
          }
        }
      }
      var contentWidth: CGFloat = 0
      var contentHeight: CGFloat = 0
      for addedSliderHandler in addedSliderHandlers {
        contentWidth = max(addedSliderHandler.view!.frame.width, contentWidth)
        contentHeight += addedSliderHandler.view!.frame.height
      }
      var blockNameView: NSTextField?
      if blockName != "" {
        contentHeight += 20
        let attrs: [NSAttributedString.Key: Any] = [.foregroundColor: NSColor.systemGray, .font: NSFont.boldSystemFont(ofSize: 12)]
        blockNameView = NSTextField(labelWithAttributedString: NSAttributedString(string: blockName, attributes: attrs))
      }
      let margin = CGFloat(15)
      let itemView = BlockView(frame: NSRect(x: 0, y: 0, width: contentWidth + margin * 2, height: contentHeight + margin * 2))
      var sliderPosition = CGFloat(margin * -1 + 1)
      for addedSliderHandler in addedSliderHandlers {
        addedSliderHandler.view!.setFrameOrigin(NSPoint(x: margin, y: margin + margin/2 + sliderPosition))
        itemView.addSubview(addedSliderHandler.view!)
        sliderPosition += addedSliderHandler.view!.frame.height
      }
      if let blockNameView = blockNameView {
        blockNameView.setFrameOrigin(NSPoint(x: margin + 13, y: contentHeight - 10))
        itemView.addSubview(blockNameView)
      }
      let item = NSMenuItem()
      item.view = itemView
      monitorSubMenu.insertItem(item, at: 0)
    } else {
      for addedSliderHandler in addedSliderHandlers {
        addSliderItem(monitorSubMenu: monitorSubMenu, sliderHandler: addedSliderHandler)
      }
    }
  }

  func addCombinedDisplayMenuBlock() {
    if let sliderHandler = self.combinedSliderHandler[.audioSpeakerVolume] {
      addSliderItem(monitorSubMenu: self, sliderHandler: sliderHandler)
    }
    if let sliderHandler = self.combinedSliderHandler[.contrast] {
      addSliderItem(monitorSubMenu: self, sliderHandler: sliderHandler)
    }
    if let sliderHandler = self.combinedSliderHandler[.brightness] {
      addSliderItem(monitorSubMenu: self, sliderHandler: sliderHandler)
    }
  }

  func updateDisplayMenu(display: Display, asSubMenu: Bool, numOfDisplays: Int) {
    os_log("Addig menu item for display %{public}@", type: .info, "\(display.identifier)")
    let monitorSubMenu: NSMenu = asSubMenu ? NSMenu() : self
    var addedSliderHandlers: [SliderHandler] = []
    display.sliderHandler[.audioSpeakerVolume] = nil
    if let otherDisplay = display as? OtherDisplay, !otherDisplay.isSw(), !display.readPrefAsBool(key: .unavailableDDC, for: .audioSpeakerVolume), !prefs.bool(forKey: PrefKey.hideVolume.rawValue) {
      let title = NSLocalizedString("Volume", comment: "Shown in menu")
      addedSliderHandlers.append(setupMenuSliderHandler(command: .audioSpeakerVolume, display: display, title: title))
    }
    display.sliderHandler[.contrast] = nil
    if let otherDisplay = display as? OtherDisplay, !otherDisplay.isSw(), !display.readPrefAsBool(key: .unavailableDDC, for: .contrast), prefs.bool(forKey: PrefKey.showContrast.rawValue) {
      let title = NSLocalizedString("Contrast", comment: "Shown in menu")
      addedSliderHandlers.append(setupMenuSliderHandler(command: .contrast, display: display, title: title))
    }
    display.sliderHandler[.brightness] = nil
    if !display.readPrefAsBool(key: .unavailableDDC, for: .brightness), !prefs.bool(forKey: PrefKey.hideBrightness.rawValue) {
      let title = NSLocalizedString("Brightness", comment: "Shown in menu")
      addedSliderHandlers.append(setupMenuSliderHandler(command: .brightness, display: display, title: title))
    }
    if !prefs.bool(forKey: PrefKey.slidersCombine.rawValue) {
      self.addDisplayMenuBlock(addedSliderHandlers: addedSliderHandlers, blockName: (display.readPrefAsString(key: .friendlyName) != "" ? display.readPrefAsString(key: .friendlyName) : display.name), monitorSubMenu: monitorSubMenu)
    }
    if addedSliderHandlers.count>0, !prefs.bool(forKey: PrefKey.slidersRelevant.rawValue), !prefs.bool(forKey: PrefKey.slidersCombine.rawValue), numOfDisplays > 1 {
      self.appendMenuHeader(friendlyName: (display.readPrefAsString(key: .friendlyName) != "" ? display.readPrefAsString(key: .friendlyName) : display.name), monitorSubMenu: monitorSubMenu, asSubMenu: asSubMenu)
    } // TODO: This stuff will be needed for macOS10 and classic menu view, but should not be located here!
    if prefs.integer(forKey: PrefKey.menuIcon.rawValue) == MenuIcon.sliderOnly.rawValue {
      app.statusItem.isVisible = addedSliderHandlers.count>0
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
