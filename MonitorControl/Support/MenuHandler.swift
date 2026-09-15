//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import AppKit
import os.log
import SwiftUI

class MenuHandler: NSMenu, NSMenuDelegate {
  var combinedSliderHandler: [Command: SliderHandler] = [:]

  private var systemControlsTimer: Timer?

  var lastMenuRelevantDisplayId: CGDirectDisplayID = 0

  func clearMenu() {
    var items: [NSMenuItem] = []
    for i in 0 ..< self.items.count {
      items.append(self.items[i])
    }
    for item in items {
      self.removeItem(item)
    }
    self.combinedSliderHandler.removeAll()
  }

  func menuWillOpen(_: NSMenu) {
    self.updateMenuRelevantDisplay()
    app.keyboardShortcuts.disengage()
    if self.showsSystemControls {
      CoreBrightnessService.shared.refresh()
      self.systemControlsTimer?.invalidate()
      let timer = Timer(timeInterval: 2, repeats: true) { _ in
        Task { @MainActor in CoreBrightnessService.shared.refresh() }
      }
      RunLoop.main.add(timer, forMode: .eventTracking)
      self.systemControlsTimer = timer
    }
  }

  func menuDidClose(_: NSMenu) {
    self.systemControlsTimer?.invalidate()
    self.systemControlsTimer = nil
    if self.showsSystemControls {
      CoreBrightnessService.shared.nightShiftTemperature?.setEditing(false)
    }
  }

  func closeMenu() {
    self.cancelTrackingWithoutAnimation()
  }

  func updateMenus(dontClose: Bool = false) {
    os_log("Menu update initiated", type: .info)
    if !dontClose {
      self.cancelTrackingWithoutAnimation()
    }
    let menuIconPref = prefs.integer(forKey: PrefKey.menuIcon.rawValue)
    var showIcon = false
    if menuIconPref == MenuIcon.show.rawValue {
      showIcon = true
    } else if menuIconPref == MenuIcon.externalOnly.rawValue {
      let externalDisplays = DisplayManager.shared.displays.filter {
        CGDisplayIsBuiltin($0.identifier) == 0
      }
      if externalDisplays.count > 0 {
        showIcon = true
      }
    }
    app.updateStatusItemVisibility(showIcon)
    self.clearMenu()
    let currentDisplay = DisplayManager.shared.getCurrentDisplay()
    var displays: [Display] = []
    if !prefs.bool(forKey: PrefKey.hideAppleFromMenu.rawValue) {
      displays.append(contentsOf: DisplayManager.shared.getAppleDisplays())
    }
    displays.append(contentsOf: DisplayManager.shared.getOtherDisplays())
    displays = DisplayManager.shared.sortDisplaysByFriendlyName()
    let relevant = prefs.integer(forKey: PrefKey.multiSliders.rawValue) == MultiSliders.relevant.rawValue
    let combine = prefs.integer(forKey: PrefKey.multiSliders.rawValue) == MultiSliders.combine.rawValue
    let numOfDisplays = displays.filter { !$0.isDummy }.count
    if numOfDisplays != 0 {
      let asSubMenu: Bool = (displays.count > 3 && !relevant && !combine && app.macOS10()) ? true : false
      var iterator = 0
      for display in displays where (!relevant || DisplayManager.resolveEffectiveDisplayID(display.identifier) == DisplayManager.resolveEffectiveDisplayID(currentDisplay!.identifier)) && !display.isDummy {
        iterator += 1
        if !relevant, !combine, iterator != 1, app.macOS10() {
          self.insertItem(NSMenuItem.separator(), at: 0)
        }
        self.updateDisplayMenu(display: display, asSubMenu: asSubMenu, numOfDisplays: numOfDisplays)
      }
      if combine {
        self.addCombinedDisplayMenuBlock()
      }
    }
    self.addSystemControls()
    self.addDefaultMenuOptions()
  }

  func addSliderItem(monitorSubMenu: NSMenu, sliderHandler: SliderHandler) {
    let item = NSMenuItem()
    item.view = sliderHandler.view
    monitorSubMenu.insertItem(item, at: 0)
  }

  func setupMenuSliderHandler(command: Command, display: Display, title: String) -> SliderHandler {
    if prefs.integer(forKey: PrefKey.multiSliders.rawValue) == MultiSliders.combine.rawValue, let combinedHandler = self.combinedSliderHandler[command] {
      combinedHandler.addDisplay(display)
      display.sliderHandler[command] = combinedHandler
      return combinedHandler
    } else {
      let sliderHandler = SliderHandler(display: display, command: command, title: title)
      if prefs.integer(forKey: PrefKey.multiSliders.rawValue) == MultiSliders.combine.rawValue {
        self.combinedSliderHandler[command] = sliderHandler
      }
      display.sliderHandler[command] = sliderHandler
      return sliderHandler
    }
  }

  func addDisplayMenuBlock(addedSliderHandlers: [SliderHandler], blockName: String, monitorSubMenu: NSMenu, numOfDisplays _: Int, asSubMenu: Bool, resolution: String? = nil) {
    self.addSystemDisplayBlock(addedSliderHandlers: addedSliderHandlers, name: blockName, resolution: resolution, menu: monitorSubMenu)
    if asSubMenu {
      let item = NSMenuItem()
      item.title = blockName
      item.submenu = monitorSubMenu
      self.insertItem(item, at: 0)
    }
  }

  private func displayResolution(_ displayID: CGDirectDisplayID) -> String? {
    guard prefs.bool(forKey: PrefKey.showDisplayResolution.rawValue),
          let mode = CGDisplayCopyDisplayMode(displayID) else { return nil }
    // Logical dimensions match the scaled resolution shown in macOS settings.
    return "\(mode.width)×\(mode.height)"
  }

  private func addSystemDisplayBlock(addedSliderHandlers: [SliderHandler], name: String, resolution: String?, menu: NSMenu) {
    guard !addedSliderHandlers.isEmpty else { return }
    let width = addedSliderHandlers.compactMap { $0.view?.frame.width }.max() ?? 300
    let headerHeight: CGFloat = resolution == nil ? 28 : 42
    let height = addedSliderHandlers.compactMap { $0.view?.frame.height }.reduce(0, +) + headerHeight + 4
    let block = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))
    var y: CGFloat = 2
    for handler in addedSliderHandlers {
      guard let view = handler.view else { continue }
      view.setFrameOrigin(NSPoint(x: 0, y: y))
      block.addSubview(view)
      y += view.frame.height
    }
    let title = NSTextField(labelWithString: name)
    title.font = .boldSystemFont(ofSize: 13)
    title.lineBreakMode = .byTruncatingTail
    title.frame = NSRect(x: 12, y: height - 26, width: width - 24, height: 18)
    block.addSubview(title)
    if let resolution = resolution {
      let subtitle = NSTextField(labelWithString: resolution)
      subtitle.font = .systemFont(ofSize: 11)
      subtitle.textColor = .secondaryLabelColor
      subtitle.frame = NSRect(x: 12, y: height - 42, width: width - 24, height: 16)
      block.addSubview(subtitle)
    }
    let item = NSMenuItem()
    item.view = block
    menu.insertItem(item, at: 0)
  }

  private var showsSystemControls: Bool {
    [PrefKey.showSystemControls, .showNightShiftTemperature].contains {
      prefs.bool(forKey: $0.rawValue)
    }
  }

  private func addSystemControls() {
    guard self.showsSystemControls else { return }
    // NSMenu views are constructed synchronously on AppKit's main thread.
    MainActor.assumeIsolated {
      let effects = CoreBrightnessService.shared
      let showEffects = prefs.bool(forKey: PrefKey.showSystemControls.rawValue)
      let temperature = prefs.bool(forKey: PrefKey.showNightShiftTemperature.rawValue) && effects.nightShiftTemperature != nil
      let view = NSHostingView(rootView: SystemControlsView(showEffects: showEffects, showTemperature: temperature))
      view.frame.size = view.fittingSize
      let item = NSMenuItem()
      item.view = view
      self.addItem(item)
    }
  }

  func addCombinedDisplayMenuBlock() {
    if let sliderHandler = self.combinedSliderHandler[.audioSpeakerVolume] {
      self.addSliderItem(monitorSubMenu: self, sliderHandler: sliderHandler)
    }
    if let sliderHandler = self.combinedSliderHandler[.contrast] {
      self.addSliderItem(monitorSubMenu: self, sliderHandler: sliderHandler)
    }
    if let sliderHandler = self.combinedSliderHandler[.brightness] {
      self.addSliderItem(monitorSubMenu: self, sliderHandler: sliderHandler)
    }
  }

  func updateDisplayMenu(display: Display, asSubMenu: Bool, numOfDisplays: Int) {
    os_log("Addig menu items for display %{public}@", type: .info, "\(display.identifier)")
    let monitorSubMenu: NSMenu = asSubMenu ? NSMenu() : self
    var addedSliderHandlers: [SliderHandler] = []
    display.sliderHandler[.audioSpeakerVolume] = nil
    if let otherDisplay = display as? OtherDisplay, !otherDisplay.isSw(), !display.readPrefAsBool(key: .unavailableDDC, for: .audioSpeakerVolume), !prefs.bool(forKey: PrefKey.hideVolume.rawValue) {
      let title = NSLocalizedString("Volume", comment: "Shown in menu")
      addedSliderHandlers.append(self.setupMenuSliderHandler(command: .audioSpeakerVolume, display: display, title: title))
    }
    display.sliderHandler[.contrast] = nil
    if let otherDisplay = display as? OtherDisplay, !otherDisplay.isSw(), !display.readPrefAsBool(key: .unavailableDDC, for: .contrast), prefs.bool(forKey: PrefKey.showContrast.rawValue) {
      let title = NSLocalizedString("Contrast", comment: "Shown in menu")
      addedSliderHandlers.append(self.setupMenuSliderHandler(command: .contrast, display: display, title: title))
    }
    display.sliderHandler[.brightness] = nil
    if !display.readPrefAsBool(key: .unavailableDDC, for: .brightness), !prefs.bool(forKey: PrefKey.hideBrightness.rawValue) {
      let title = NSLocalizedString("Brightness", comment: "Shown in menu")
      addedSliderHandlers.append(self.setupMenuSliderHandler(command: .brightness, display: display, title: title))
    }
    if prefs.integer(forKey: PrefKey.multiSliders.rawValue) != MultiSliders.combine.rawValue {
      self.addDisplayMenuBlock(addedSliderHandlers: addedSliderHandlers, blockName: display.readPrefAsString(key: .friendlyName) != "" ? display.readPrefAsString(key: .friendlyName) : display.name, monitorSubMenu: monitorSubMenu, numOfDisplays: numOfDisplays, asSubMenu: asSubMenu, resolution: self.displayResolution(display.identifier))
    }
    if addedSliderHandlers.count > 0, prefs.integer(forKey: PrefKey.menuIcon.rawValue) == MenuIcon.sliderOnly.rawValue {
      app.updateStatusItemVisibility(true)
    }
  }

  func updateMenuRelevantDisplay() {
    if prefs.integer(forKey: PrefKey.multiSliders.rawValue) == MultiSliders.relevant.rawValue {
      if let display = DisplayManager.shared.getCurrentDisplay(), display.identifier != self.lastMenuRelevantDisplayId {
        os_log("Menu must be refreshed as relevant display changed since last time.")
        self.lastMenuRelevantDisplayId = display.identifier
        self.updateMenus(dontClose: true)
      }
    }
  }

  func addDefaultMenuOptions() {
    let style = prefs.integer(forKey: PrefKey.menuItemStyle.rawValue)
    guard style != MenuItemStyle.hide.rawValue else { return }
    let showIcons = style == MenuItemStyle.icon.rawValue
    self.addItem(NSMenuItem.separator())
    self.addSystemMenuAction(title: NSLocalizedString("Settings…", comment: "Shown in menu"),
                             symbol: showIcons ? "gearshape" : nil,
                             action: #selector(app.prefsClicked), target: app, key: ",")
    self.addSystemMenuAction(title: NSLocalizedString("Check for updates…", comment: "Shown in menu"),
                             symbol: showIcons ? "arrow.triangle.2.circlepath" : nil,
                             action: #selector(app.updaterController.checkForUpdates(_:)), target: app.updaterController)
    self.addItem(NSMenuItem.separator())
    self.addSystemMenuAction(title: NSLocalizedString("Quit", comment: "Shown in menu"),
                             symbol: nil, action: #selector(app.quitClicked), target: app, key: "q")
  }

  private func addSystemMenuAction(title: String, symbol: String?, action: Selector, target: AnyObject, key: String = "") {
    let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
    item.target = target
    MainActor.assumeIsolated {
      let view = NSHostingView(rootView: MenuActionRow(title: title, symbol: symbol) { [weak self, weak item] in
        self?.cancelTrackingWithoutAnimation()
        NSApp.sendAction(action, to: target, from: item)
      })
      view.frame.size = view.fittingSize
      item.view = view
    }
    self.addItem(item)
  }
}
