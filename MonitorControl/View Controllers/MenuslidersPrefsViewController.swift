//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Cocoa
import Preferences
import ServiceManagement
import os.log

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

  @IBOutlet var slidersSeparate: NSButton!
  @IBOutlet var slidersRelevant: NSButton!
  @IBOutlet var slidersCombine: NSButton!

  @IBOutlet var enableSliderSnap: NSButton!
  @IBOutlet var showTickMarks: NSButton!
  @IBOutlet var enableSliderPercent: NSButton!

  @IBOutlet var rowIconShow: NSGridRow!
  @IBOutlet var rowMenuItemStyle: NSGridRow!
  @IBOutlet var rowQuitButton: NSGridRow!
  @IBOutlet var rowQuitButtonText: NSGridRow!
  @IBOutlet var rowHideIconSpearator: NSGridRow!

  @IBOutlet var rowShowContrastCheck: NSGridRow!
  @IBOutlet var rowShowContrastText: NSGridRow!

  @IBOutlet var rowSlidersSeparator: NSButton!
  @IBOutlet var rowSlidersSeparate: NSButton!
  @IBOutlet var rowSlidersRelevant: NSButton!
  @IBOutlet var rowSlidersCombine: NSButton!
  @IBOutlet var rowSlidersCombineText: NSButton!

  @IBOutlet var rowTickCheck: NSGridRow!
  @IBOutlet var rowTickText: NSGridRow!
  @IBOutlet var rowPercentCheck: NSGridRow!
  @IBOutlet var rowPercentText: NSGridRow!

  // swiftlint:disable cyclomatic_complexity
  func showAdvanced() -> Bool {
    let hide = !prefs.bool(forKey: PrefKey.showAdvancedSettings.rawValue)

    var doNotHideRowIconSeparator = false

    if self.iconShow.selectedTag() != MenuIcon.show.rawValue {
      self.rowIconShow.isHidden = false
      doNotHideRowIconSeparator = true
    } else {
      self.rowIconShow.isHidden = hide
    }

    if app.macOS10() {
      self.rowMenuItemStyle.isHidden = true
    } else if self.menuItemStyle.selectedTag() != MenuItemStyle.text.rawValue {
      self.rowMenuItemStyle.isHidden = false
      doNotHideRowIconSeparator = true
    } else {
      self.rowMenuItemStyle.isHidden = hide
    }

    if self.iconShow.selectedTag() != MenuIcon.show.rawValue || self.menuItemStyle.selectedTag() == MenuItemStyle.hide.rawValue {
      self.rowQuitButton.isHidden = false
      self.rowQuitButtonText.isHidden = false
      doNotHideRowIconSeparator = true
    } else {
      self.rowQuitButton.isHidden = true
      self.rowQuitButtonText.isHidden = true
    }

    if doNotHideRowIconSeparator {
      self.rowHideIconSpearator.isHidden = false
      self.rowHideIconSpearator.isHidden = false
    } else {
      self.rowHideIconSpearator.isHidden = hide
      self.rowHideIconSpearator.isHidden = hide
    }

    if self.showContrastSlider.state == .on {
      self.rowShowContrastCheck.isHidden = false
      self.rowShowContrastText.isHidden = false
    } else {
      self.rowShowContrastCheck.isHidden = hide
      self.rowShowContrastText.isHidden = hide
    }

    if self.slidersSeparate.state == .on {
      self.rowSlidersSeparator.isHidden = hide
      self.rowSlidersSeparate.isHidden = hide
      self.rowSlidersRelevant.isHidden = hide
      self.rowSlidersCombine.isHidden = hide
      self.rowSlidersCombineText.isHidden = hide
    } else {
      self.rowSlidersSeparator.isHidden = false
      self.rowSlidersSeparate.isHidden = false
      if self.slidersRelevant.state == .on {
        self.rowSlidersRelevant.isHidden = false
      } else {
        self.rowSlidersRelevant.isHidden = hide
      }
      if self.slidersCombine.state == .on {
        self.rowSlidersCombine.isHidden = false
        self.rowSlidersCombineText.isHidden = false
      } else {
        self.rowSlidersCombine.isHidden = hide
        self.rowSlidersCombineText.isHidden = hide
      }
    }

    if app.macOS10() {
      self.rowTickCheck.isHidden = true
      self.rowTickText.isHidden = true
    } else if self.showTickMarks.state == .on {
      self.rowTickCheck.isHidden = false
      self.rowTickText.isHidden = false
    } else {
      self.rowTickCheck.isHidden = hide
      self.rowTickText.isHidden = hide
    }

    if self.enableSliderPercent.state == .on {
      self.rowPercentCheck.isHidden = false
      self.rowPercentText.isHidden = false
    } else {
      self.rowPercentCheck.isHidden = hide
      self.rowPercentText.isHidden = hide
    }
    return !hide
  }
  // swiftlint:enable cyclomatic_complexity

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

    self.slidersSeparate.state = prefs.bool(forKey: PrefKey.slidersRelevant.rawValue) || prefs.bool(forKey: PrefKey.slidersCombine.rawValue) ? .off : .on
    self.slidersRelevant.state = prefs.bool(forKey: PrefKey.slidersRelevant.rawValue) ? .on : .off
    self.slidersCombine.state = prefs.bool(forKey: PrefKey.slidersCombine.rawValue) ? .on : .off

    self.showVolumeSlider.state = prefs.bool(forKey: PrefKey.hideVolume.rawValue) ? .off : .on
    self.enableSliderSnap.state = prefs.bool(forKey: PrefKey.enableSliderSnap.rawValue) ? .on : .off
    self.showTickMarks.state = prefs.bool(forKey: PrefKey.showTickMarks.rawValue) ? .on : .off
    self.enableSliderPercent.state = prefs.bool(forKey: PrefKey.enableSliderPercent.rawValue) ? .on : .off
    _ = self.showAdvanced()
  }

  @IBAction func icon(_ sender: NSPopUpButton) {
    prefs.set(sender.selectedTag(), forKey: PrefKey.menuIcon.rawValue)
    app.updateMenusAndKeys()
    _ = self.showAdvanced()
  }

  @IBAction func menuItemStyle(_ sender: NSPopUpButton) {
    prefs.set(sender.selectedTag(), forKey: PrefKey.menuItemStyle.rawValue)
    app.updateMenusAndKeys()
    _ = self.showAdvanced()
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
    _ = self.showAdvanced()
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
    _ = self.showAdvanced()
  }

  @IBAction func slidersSeparate(_: NSButton) {
    prefs.set(false, forKey: PrefKey.slidersCombine.rawValue)
    prefs.set(false, forKey: PrefKey.slidersRelevant.rawValue)
    self.slidersSeparate.state = .on
    self.slidersCombine.state = .off
    self.slidersRelevant.state = .off
    app.updateMenusAndKeys()
    _ = self.showAdvanced()
  }

  @IBAction func slidersRelevant(_: NSButton) {
    prefs.set(false, forKey: PrefKey.slidersCombine.rawValue)
    prefs.set(true, forKey: PrefKey.slidersRelevant.rawValue)
    self.slidersSeparate.state = .off
    self.slidersCombine.state = .off
    self.slidersRelevant.state = .on
    app.updateMenusAndKeys()
    _ = self.showAdvanced()
  }

  @IBAction func slidersCombine(_: NSButton) {
    prefs.set(true, forKey: PrefKey.slidersCombine.rawValue)
    prefs.set(false, forKey: PrefKey.slidersRelevant.rawValue)
    self.slidersSeparate.state = .off
    self.slidersCombine.state = .on
    self.slidersRelevant.state = .off
    app.updateMenusAndKeys()
    _ = self.showAdvanced()
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
    _ = self.showAdvanced()
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
    _ = self.showAdvanced()
  }
}
