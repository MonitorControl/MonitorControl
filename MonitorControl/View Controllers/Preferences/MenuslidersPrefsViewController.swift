//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Cocoa
import os.log
import Preferences
import ServiceManagement

class MenuslidersPrefsViewController: NSViewController, PreferencePane {
  let preferencePaneIdentifier = Preferences.PaneIdentifier.menusliders
  let preferencePaneTitle: String = NSLocalizedString("App menu", comment: "Shown in the main prefs window")

  var toolbarItemIcon: NSImage {
    if !DEBUG_MACOS10, #available(macOS 11.0, *) {
      return NSImage(systemSymbolName: "filemenu.and.cursorarrow", accessibilityDescription: "App menu")!
    } else {
      return NSImage(named: NSImage.infoName)!
    }
  }

  @IBOutlet var iconShow: NSPopUpButton!
  @IBOutlet var menuItemStyle: NSPopUpButton!
  @IBOutlet var quitApplication: NSButton!

  @IBOutlet var showBrightnessSlider: NSButton!
  @IBOutlet var showAppleFromMenu: NSButton!
  @IBOutlet var showVolumeSlider: NSButton!
  @IBOutlet var showContrastSlider: NSButton!

  @IBOutlet var multiSliders: NSPopUpButton!

  @IBOutlet var enableSliderSnap: NSButton!
  @IBOutlet var showTickMarks: NSButton!
  @IBOutlet var enableSliderPercent: NSButton!

  @IBOutlet var rowMenuItemStyle: NSGridRow!
  @IBOutlet var rowQuitButton: NSGridRow!
  @IBOutlet var rowQuitButtonText: NSGridRow!

  @IBOutlet var rowMultiSliders: NSGridRow!
  @IBOutlet var rowSlidersCombineText: NSGridRow!

  @IBOutlet var rowTickCheck: NSGridRow!
  @IBOutlet var rowTickText: NSGridRow!

  func updateGridLayout() {
    if app.macOS10() {
      self.rowMenuItemStyle.isHidden = true
    } else {
      self.rowMenuItemStyle.isHidden = false
    }

    if self.iconShow.selectedTag() != MenuIcon.show.rawValue || self.menuItemStyle.selectedTag() == MenuItemStyle.hide.rawValue {
      self.rowQuitButton.isHidden = false
      self.rowQuitButtonText.isHidden = false
    } else {
      self.rowQuitButton.isHidden = true
      self.rowQuitButtonText.isHidden = true
    }

    if self.multiSliders.selectedTag() == MultiSliders.separate.rawValue {
      self.rowMultiSliders.bottomPadding = -6
      self.rowSlidersCombineText.isHidden = true
    } else if self.multiSliders.selectedTag() == MultiSliders.relevant.rawValue {
      self.rowMultiSliders.bottomPadding = -6
      self.rowSlidersCombineText.isHidden = true
    } else if self.multiSliders.selectedTag() == MultiSliders.combine.rawValue {
      self.rowMultiSliders.bottomPadding = -10
      self.rowSlidersCombineText.isHidden = false
    }

    if app.macOS10() {
      self.rowTickCheck.isHidden = true
      self.rowTickText.isHidden = true
    } else {
      self.rowTickCheck.isHidden = false
      self.rowTickText.isHidden = false
    }
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    self.populateSettings()
  }

  func populateSettings() {
    self.iconShow.selectItem(withTag: prefs.integer(forKey: PrefKey.menuIcon.rawValue))
    self.menuItemStyle.selectItem(withTag: prefs.integer(forKey: PrefKey.menuItemStyle.rawValue))
    self.showBrightnessSlider.state = !prefs.bool(forKey: PrefKey.hideBrightness.rawValue) ? .on : .off
    if !prefs.bool(forKey: PrefKey.hideBrightness.rawValue) {
      self.showAppleFromMenu.isEnabled = true
      self.showAppleFromMenu.state = !prefs.bool(forKey: PrefKey.hideAppleFromMenu.rawValue) ? .on : .off
    } else {
      self.showAppleFromMenu.state = .off
      self.showAppleFromMenu.isEnabled = false
    }
    self.showContrastSlider.state = prefs.bool(forKey: PrefKey.showContrast.rawValue) ? .on : .off

    self.multiSliders.selectItem(withTag: prefs.integer(forKey: PrefKey.multiSliders.rawValue))

    self.showVolumeSlider.state = prefs.bool(forKey: PrefKey.hideVolume.rawValue) ? .off : .on
    self.enableSliderSnap.state = prefs.bool(forKey: PrefKey.enableSliderSnap.rawValue) ? .on : .off
    self.showTickMarks.state = prefs.bool(forKey: PrefKey.showTickMarks.rawValue) ? .on : .off
    self.enableSliderPercent.state = prefs.bool(forKey: PrefKey.enableSliderPercent.rawValue) ? .on : .off
    self.updateGridLayout()
  }

  @IBAction func icon(_ sender: NSPopUpButton) {
    prefs.set(sender.selectedTag(), forKey: PrefKey.menuIcon.rawValue)
    app.updateMenusAndKeys()
    self.updateGridLayout()
  }

  @IBAction func menuItemStyle(_ sender: NSPopUpButton) {
    prefs.set(sender.selectedTag(), forKey: PrefKey.menuItemStyle.rawValue)
    app.updateMenusAndKeys()
    self.updateGridLayout()
  }

  @IBAction func quitApplicationClicked(_: NSButton) {
    NSApplication.shared.terminate(self)
  }

  @IBAction func showBrightnessSliderClicked(_ sender: NSButton) {
    switch sender.state {
    case .off:
      prefs.set(true, forKey: PrefKey.hideBrightness.rawValue)
      self.showAppleFromMenu.state = .off
      self.showAppleFromMenu.isEnabled = false
    case .on:
      prefs.set(false, forKey: PrefKey.hideBrightness.rawValue)
      self.showAppleFromMenu.isEnabled = true
      self.showAppleFromMenu.state = !prefs.bool(forKey: PrefKey.hideAppleFromMenu.rawValue) ? .on : .off
    default: break
    }
    app.updateMenusAndKeys()
  }

  @IBAction func showAppleFromMenuClicked(_ sender: NSButton) {
    switch sender.state {
    case .off:
      prefs.set(true, forKey: PrefKey.hideAppleFromMenu.rawValue)
    case .on:
      prefs.set(false, forKey: PrefKey.hideAppleFromMenu.rawValue)
    default: break
    }
    app.updateMenusAndKeys()
  }

  @IBAction func showVolumeSliderClicked(_ sender: NSButton) {
    switch sender.state {
    case .on:
      prefs.set(false, forKey: PrefKey.hideVolume.rawValue)
    case .off:
      prefs.set(true, forKey: PrefKey.hideVolume.rawValue)
    default: break
    }
    app.updateMenusAndKeys()
  }

  @IBAction func showContrastSliderClicked(_ sender: NSButton) {
    switch sender.state {
    case .on:
      prefs.set(true, forKey: PrefKey.showContrast.rawValue)
    case .off:
      prefs.set(false, forKey: PrefKey.showContrast.rawValue)
    default: break
    }
    app.updateMenusAndKeys()
    self.updateGridLayout()
  }

  @IBAction func enableSliderSnapClicked(_ sender: NSButton) {
    switch sender.state {
    case .on:
      prefs.set(true, forKey: PrefKey.enableSliderSnap.rawValue)
    case .off:
      prefs.set(false, forKey: PrefKey.enableSliderSnap.rawValue)
    default: break
    }
    app.updateMenusAndKeys()
    self.updateGridLayout()
  }

  @IBAction func multiSliders(_ sender: NSPopUpButton) {
    prefs.set(sender.selectedTag(), forKey: PrefKey.multiSliders.rawValue)
    app.updateMenusAndKeys()
    self.updateGridLayout()
  }

  @IBAction func showTickMarks(_ sender: NSButton) {
    switch sender.state {
    case .on:
      prefs.set(true, forKey: PrefKey.showTickMarks.rawValue)
    case .off:
      prefs.set(false, forKey: PrefKey.showTickMarks.rawValue)
    default: break
    }
    app.updateMenusAndKeys()
    self.updateGridLayout()
  }

  @IBAction func enableSliderPercent(_ sender: NSButton) {
    switch sender.state {
    case .on:
      prefs.set(true, forKey: PrefKey.enableSliderPercent.rawValue)
    case .off:
      prefs.set(false, forKey: PrefKey.enableSliderPercent.rawValue)
    default: break
    }
    app.updateMenusAndKeys()
    self.updateGridLayout()
  }
}
