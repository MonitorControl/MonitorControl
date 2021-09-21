//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Cocoa
import Preferences
import ServiceManagement

class MenuslidersPrefsViewController: NSViewController, PreferencePane {
  let preferencePaneIdentifier = Preferences.PaneIdentifier.menusliders
  let preferencePaneTitle: String = NSLocalizedString("App menu", comment: "Shown in the main prefs window")

  var toolbarItemIcon: NSImage {
    if #available(macOS 11.0, *) {
      return NSImage(systemSymbolName: "filemenu.and.cursorarrow", accessibilityDescription: "App menu")!
    } else {
      return NSImage(named: NSImage.infoName)!
    }
  }

  @IBOutlet var iconShow: NSButton!
  @IBOutlet var iconSliderOnly: NSButton!
  @IBOutlet var iconHide: NSButton!
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
  @IBOutlet var rowIconSliderOnly: NSGridRow!
  @IBOutlet var rowIconHide: NSGridRow!
  @IBOutlet var rowHideIconText: NSGridRow!
  @IBOutlet var rowQuitButton: NSGridRow!
  @IBOutlet var rowQuitText: NSGridRow!
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

  func showAdvanced() -> Bool {
    let hide = !prefs.bool(forKey: PrefKey.showAdvancedSettings.rawValue)
    if self.iconShow.state == .off {
      self.rowIconShow.isHidden = false
      self.rowHideIconText.isHidden = false
      self.rowHideIconSpearator.isHidden = false
      self.rowQuitButton.isHidden = false
      self.rowQuitText.isHidden = false
    } else {
      self.rowIconShow.isHidden = hide
      self.rowHideIconText.isHidden = hide
      self.rowHideIconSpearator.isHidden = hide
      self.rowQuitButton.isHidden = true
      self.rowQuitText.isHidden = true
    }
    if self.iconSliderOnly.state == .on {
      self.rowIconSliderOnly.isHidden = false
    } else {
      self.rowIconSliderOnly.isHidden = hide
    }
    if self.iconHide.state == .on {
      self.rowIconHide.isHidden = false
    } else {
      self.rowIconHide.isHidden = hide
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

    if self.showTickMarks.state == .on {
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

  override func viewDidLoad() {
    super.viewDidLoad()
    self.populateSettings()
  }

  func populateSettings() {
    self.iconShow.state = .off
    self.iconSliderOnly.state = .off
    self.iconHide.state = .off
    switch prefs.string(forKey: PrefKey.menuIcon.rawValue) ?? "" {
    case "sliderOnly": self.iconSliderOnly.state = .on
    case "hide": self.iconHide.state = .on
    default: self.iconShow.state = .on
    }
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

  @IBAction func icon(_ sender: NSButton) {
    switch sender.tag {
    case 0:
      prefs.set("", forKey: PrefKey.menuIcon.rawValue)
      app.statusItem.isVisible = true
    case 1:
      prefs.set("sliderOnly", forKey: PrefKey.menuIcon.rawValue)
      app.updateDisplaysAndMenus()
    case 2:
      prefs.set("hide", forKey: PrefKey.menuIcon.rawValue)
      app.statusItem.isVisible = false
    default: break
    }
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
    app.updateDisplaysAndMenus()
  }

  @IBAction func showAppleFromMenuClicked(_ sender: NSButton) {
    switch sender.state {
    case .off:
      prefs.set(true, forKey: PrefKey.hideAppleFromMenu.rawValue)
    case .on:
      prefs.set(false, forKey: PrefKey.hideAppleFromMenu.rawValue)
    default: break
    }
    app.updateDisplaysAndMenus()
  }

  @IBAction func showVolumeSliderClicked(_ sender: NSButton) {
    switch sender.state {
    case .on:
      prefs.set(false, forKey: PrefKey.hideVolume.rawValue)
    case .off:
      prefs.set(true, forKey: PrefKey.hideVolume.rawValue)
    default: break
    }
    app.updateDisplaysAndMenus()
  }

  @IBAction func showContrastSliderClicked(_ sender: NSButton) {
    switch sender.state {
    case .on:
      prefs.set(true, forKey: PrefKey.showContrast.rawValue)
    case .off:
      prefs.set(false, forKey: PrefKey.showContrast.rawValue)
    default: break
    }
    app.updateDisplaysAndMenus()
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
    app.updateDisplaysAndMenus()
    _ = self.showAdvanced()
  }

  @IBAction func slidersSeparate(_: NSButton) {
    prefs.set(false, forKey: PrefKey.slidersCombine.rawValue)
    prefs.set(false, forKey: PrefKey.slidersRelevant.rawValue)
    self.slidersSeparate.state = .on
    self.slidersCombine.state = .off
    self.slidersRelevant.state = .off
    app.updateDisplaysAndMenus()
    _ = self.showAdvanced()
  }

  @IBAction func slidersRelevant(_: NSButton) {
    prefs.set(false, forKey: PrefKey.slidersCombine.rawValue)
    prefs.set(true, forKey: PrefKey.slidersRelevant.rawValue)
    self.slidersSeparate.state = .off
    self.slidersCombine.state = .off
    self.slidersRelevant.state = .on
    app.updateDisplaysAndMenus()
    _ = self.showAdvanced()
  }

  @IBAction func slidersCombine(_: NSButton) {
    prefs.set(true, forKey: PrefKey.slidersCombine.rawValue)
    prefs.set(false, forKey: PrefKey.slidersRelevant.rawValue)
    self.slidersSeparate.state = .off
    self.slidersCombine.state = .on
    self.slidersRelevant.state = .off
    app.updateDisplaysAndMenus()
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
    app.updateDisplaysAndMenus()
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
    app.updateDisplaysAndMenus()
    _ = self.showAdvanced()
  }
}
