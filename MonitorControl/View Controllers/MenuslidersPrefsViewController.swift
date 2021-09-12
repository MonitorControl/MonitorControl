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

  let prefs = UserDefaults.standard

  @IBOutlet var hideMenuIcon: NSButton!
  @IBOutlet var showBrightnessSlider: NSButton!
  @IBOutlet var showAppleFromMenu: NSButton!
  @IBOutlet var showVolumeSlider: NSButton!
  @IBOutlet var showContrastSlider: NSButton!
  @IBOutlet var enableSliderSnap: NSButton!
  @IBOutlet var showTickMarks: NSButton!

  override func viewDidLoad() {
    super.viewDidLoad()
  }

  override func viewWillAppear() {
    super.viewWillAppear()
    self.populateSettings()
  }

  func populateSettings() {
    self.hideMenuIcon.state = self.prefs.bool(forKey: PrefKey.hideMenuIcon.rawValue) ? .on : .off
    self.showBrightnessSlider.state = !self.prefs.bool(forKey: PrefKey.hideBrightness.rawValue) ? .on : .off
    if !self.prefs.bool(forKey: PrefKey.hideBrightness.rawValue) {
      self.showAppleFromMenu.isEnabled = true
      self.showAppleFromMenu.state = !self.prefs.bool(forKey: PrefKey.hideAppleFromMenu.rawValue) ? .on : .off
    } else {
      self.showAppleFromMenu.state = .off
      self.showAppleFromMenu.isEnabled = false
    }
    self.showContrastSlider.state = self.prefs.bool(forKey: PrefKey.showContrast.rawValue) ? .on : .off
    self.showVolumeSlider.state = self.prefs.bool(forKey: PrefKey.showVolume.rawValue) ? .on : .off
    self.enableSliderSnap.state = self.prefs.bool(forKey: PrefKey.enableSliderSnap.rawValue) ? .on : .off
    self.showTickMarks.state = self.prefs.bool(forKey: PrefKey.showTickMarks.rawValue) ? .on : .off
  }

  @IBAction func hideMenuIconClicked(_ sender: NSButton) {
    switch sender.state {
    case .on:
      self.prefs.set(true, forKey: PrefKey.hideMenuIcon.rawValue)
      app.statusItem.isVisible = false
    case .off:
      self.prefs.set(false, forKey: PrefKey.hideMenuIcon.rawValue)
      app.statusItem.isVisible = true
    default: break
    }
  }

  @IBAction func showBrightnessSliderClicked(_ sender: NSButton) {
    switch sender.state {
    case .off:
      self.prefs.set(true, forKey: PrefKey.hideBrightness.rawValue)
      self.showAppleFromMenu.state = .off
      self.showAppleFromMenu.isEnabled = false
    case .on:
      self.prefs.set(false, forKey: PrefKey.hideBrightness.rawValue)
      self.showAppleFromMenu.isEnabled = true
      self.showAppleFromMenu.state = !self.prefs.bool(forKey: PrefKey.hideAppleFromMenu.rawValue) ? .on : .off
    default: break
    }
    app.updateDisplaysAndMenus()
  }

  @IBAction func showAppleFromMenuClicked(_ sender: NSButton) {
    switch sender.state {
    case .off:
      self.prefs.set(true, forKey: PrefKey.hideAppleFromMenu.rawValue)
    case .on:
      self.prefs.set(false, forKey: PrefKey.hideAppleFromMenu.rawValue)
    default: break
    }
    app.updateDisplaysAndMenus()
  }

  @IBAction func showVolumeSliderClicked(_ sender: NSButton) {
    switch sender.state {
    case .on:
      self.prefs.set(true, forKey: PrefKey.showVolume.rawValue)
    case .off:
      self.prefs.set(false, forKey: PrefKey.showVolume.rawValue)
    default: break
    }
    app.updateDisplaysAndMenus()
  }

  @IBAction func showContrastSliderClicked(_ sender: NSButton) {
    switch sender.state {
    case .on:
      self.prefs.set(true, forKey: PrefKey.showContrast.rawValue)
    case .off:
      self.prefs.set(false, forKey: PrefKey.showContrast.rawValue)
    default: break
    }
    app.updateDisplaysAndMenus()
  }

  @IBAction func enableSliderSnapClicked(_ sender: NSButton) {
    switch sender.state {
    case .on:
      self.prefs.set(true, forKey: PrefKey.enableSliderSnap.rawValue)
    case .off:
      self.prefs.set(false, forKey: PrefKey.enableSliderSnap.rawValue)
    default: break
    }
    app.updateDisplaysAndMenus()
  }

  @IBAction func showTickMarks(_ sender: NSButton) {
    switch sender.state {
    case .on:
      self.prefs.set(true, forKey: PrefKey.showTickMarks.rawValue)
    case .off:
      self.prefs.set(false, forKey: PrefKey.showTickMarks.rawValue)
    default: break
    }
    app.updateDisplaysAndMenus()
  }
}
