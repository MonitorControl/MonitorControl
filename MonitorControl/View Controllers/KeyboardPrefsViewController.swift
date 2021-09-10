import Cocoa
import Preferences
import ServiceManagement

class KeyboardPrefsViewController: NSViewController, PreferencePane {
  let preferencePaneIdentifier = Preferences.PaneIdentifier.keyboard
  let preferencePaneTitle: String = NSLocalizedString("Keyboard", comment: "Shown in the main prefs window")

  var toolbarItemIcon: NSImage {
    if #available(macOS 11.0, *) {
      return NSImage(systemSymbolName: "keyboard", accessibilityDescription: "Keyboard")!
    } else {
      return NSImage(named: NSImage.infoName)!
    }
  }

  let prefs = UserDefaults.standard

  @IBOutlet var listenFor: NSPopUpButton!
  @IBOutlet var allScreens: NSButton!
  @IBOutlet var useFocusInsteadOfMouse: NSButton!
  @IBOutlet var allScreensVolume: NSButton!
  @IBOutlet var useAudioDeviceNameMatching: NSButton!
  @IBOutlet var useFineScale: NSButton!
  @IBOutlet var useFineScaleVolume: NSButton!

  override func viewDidLoad() {
    super.viewDidLoad()
  }

  override func viewWillAppear() {
    super.viewWillAppear()
    self.populateSettings()
  }

  func populateSettings() {
    self.listenFor.selectItem(at: self.prefs.integer(forKey: Utils.PrefKeys.listenFor.rawValue))
    self.allScreens.state = self.prefs.bool(forKey: Utils.PrefKeys.allScreensBrightness.rawValue) ? .on : .off
    self.useFocusInsteadOfMouse.state = self.prefs.bool(forKey: Utils.PrefKeys.useFocusInsteadOfMouse.rawValue) ? .on : .off
    self.allScreensVolume.state = self.prefs.bool(forKey: Utils.PrefKeys.allScreensVolume.rawValue) ? .on : .off
    self.useAudioDeviceNameMatching.state = self.prefs.bool(forKey: Utils.PrefKeys.useAudioDeviceNameMatching.rawValue) ? .on : .off
    self.useFineScale.state = self.prefs.bool(forKey: Utils.PrefKeys.useFineScaleBrightness.rawValue) ? .on : .off
    self.useFineScaleVolume.state = self.prefs.bool(forKey: Utils.PrefKeys.useFineScaleVolume.rawValue) ? .on : .off
    self.allScreensClicked(self.allScreens)
    self.allScreensVolumeClicked(self.allScreensVolume)
  }

  @IBAction func allScreensClicked(_ sender: NSButton) {
    switch sender.state {
    case .on:
      self.prefs.set(true, forKey: Utils.PrefKeys.allScreensBrightness.rawValue)
      self.useFocusInsteadOfMouse.state = .off
      self.useFocusInsteadOfMouse.isEnabled = false
    case .off:
      self.prefs.set(false, forKey: Utils.PrefKeys.allScreensBrightness.rawValue)
      self.useFocusInsteadOfMouse.isEnabled = true
      self.useFocusInsteadOfMouse.state = self.prefs.bool(forKey: Utils.PrefKeys.useFocusInsteadOfMouse.rawValue) ? .on : .off
    default: break
    }
  }

  @IBAction func useFocusInsteadOfMouseClicked(_ sender: NSButton) {
    switch sender.state {
    case .on:
      self.prefs.set(true, forKey: Utils.PrefKeys.useFocusInsteadOfMouse.rawValue)
    case .off:
      self.prefs.set(false, forKey: Utils.PrefKeys.useFocusInsteadOfMouse.rawValue)
    default: break
    }
  }

  @IBAction func allScreensVolumeClicked(_ sender: NSButton) {
    switch sender.state {
    case .on:
      self.prefs.set(true, forKey: Utils.PrefKeys.allScreensVolume.rawValue)
      self.useAudioDeviceNameMatching.state = .off
      self.useAudioDeviceNameMatching.isEnabled = false
    case .off:
      self.prefs.set(false, forKey: Utils.PrefKeys.allScreensVolume.rawValue)
      self.useAudioDeviceNameMatching.isEnabled = true
      self.useAudioDeviceNameMatching.state = self.prefs.bool(forKey: Utils.PrefKeys.useAudioDeviceNameMatching.rawValue) ? .on : .off
    default: break
    }
    app.updateMediaKeyTap()
  }

  @IBAction func useAudioDeviceNameMatchingClicked(_ sender: NSButton) {
    switch sender.state {
    case .on:
      self.prefs.set(true, forKey: Utils.PrefKeys.useAudioDeviceNameMatching.rawValue)
    case .off:
      self.prefs.set(false, forKey: Utils.PrefKeys.useAudioDeviceNameMatching.rawValue)
    default: break
    }
    app.updateMediaKeyTap()
  }

  @IBAction func useFineScaleClicked(_ sender: NSButton) {
    switch sender.state {
    case .on:
      self.prefs.set(true, forKey: Utils.PrefKeys.useFineScaleBrightness.rawValue)
    case .off:
      self.prefs.set(false, forKey: Utils.PrefKeys.useFineScaleBrightness.rawValue)
    default: break
    }
  }

  @IBAction func useFineScaleVolumeClicked(_ sender: NSButton) {
    switch sender.state {
    case .on:
      self.prefs.set(true, forKey: Utils.PrefKeys.useFineScaleVolume.rawValue)
    case .off:
      self.prefs.set(false, forKey: Utils.PrefKeys.useFineScaleVolume.rawValue)
    default: break
    }
  }

  @IBAction func listenForChanged(_ sender: NSPopUpButton) {
    self.prefs.set(sender.selectedTag(), forKey: Utils.PrefKeys.listenFor.rawValue)
    NotificationCenter.default.post(name: Notification.Name(Utils.PrefKeys.listenFor.rawValue), object: nil)
  }
}
