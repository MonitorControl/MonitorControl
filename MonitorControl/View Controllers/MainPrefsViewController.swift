import Cocoa
import os.log
import Preferences
import ServiceManagement

class MainPrefsViewController: NSViewController, PreferencePane {
  let preferencePaneIdentifier = Preferences.PaneIdentifier.main
  let preferencePaneTitle: String = NSLocalizedString("General", comment: "Shown in the main prefs window")

  var toolbarItemIcon: NSImage {
    if #available(macOS 11.0, *) {
      return NSImage(systemSymbolName: "switch.2", accessibilityDescription: "Display")!
    } else {
      // Fallback on earlier versions
      return NSImage(named: NSImage.preferencesGeneralName)!
    }
  }

  let prefs = UserDefaults.standard

  @IBOutlet var versionLabel: NSTextField!
  @IBOutlet var startAtLogin: NSButton!
  @IBOutlet var hideMenuIcon: NSButton!
  @IBOutlet var showContrastSlider: NSButton!
  @IBOutlet var showVolumeSlider: NSButton!
  @IBOutlet var lowerSwAfterBrightness: NSButton!
  @IBOutlet var fallbackSw: NSButton!
  @IBOutlet var listenFor: NSPopUpButton!

  override func viewDidLoad() {
    super.viewDidLoad()
    self.setAppInfo()
  }

  @available(macOS, deprecated: 10.10)
  override func viewWillAppear() {
    super.viewWillAppear()
    let startAtLogin = (SMCopyAllJobDictionaries(kSMDomainUserLaunchd).takeRetainedValue() as? [[String: AnyObject]])?.first { $0["Label"] as? String == "\(Bundle.main.bundleIdentifier!)Helper" }?["OnDemand"] as? Bool ?? false
    self.startAtLogin.state = startAtLogin ? .on : .off
    self.hideMenuIcon.state = self.prefs.bool(forKey: Utils.PrefKeys.hideMenuIcon.rawValue) ? .on : .off
    self.showContrastSlider.state = self.prefs.bool(forKey: Utils.PrefKeys.showContrast.rawValue) ? .on : .off
    self.showVolumeSlider.state = self.prefs.bool(forKey: Utils.PrefKeys.showVolume.rawValue) ? .on : .off
    self.lowerSwAfterBrightness.state = self.prefs.bool(forKey: Utils.PrefKeys.lowerSwAfterBrightness.rawValue) ? .on : .off
    self.fallbackSw.state = self.prefs.bool(forKey: Utils.PrefKeys.fallbackSw.rawValue) ? .on : .off
    self.listenFor.selectItem(at: self.prefs.integer(forKey: Utils.PrefKeys.listenFor.rawValue))
  }

  @IBAction func startAtLoginClicked(_ sender: NSButton) {
    switch sender.state {
    case .on:
      Utils.setStartAtLogin(enabled: true)
    case .off:
      Utils.setStartAtLogin(enabled: false)
    default: break
    }
  }

  @IBAction func hideMenuIconClicked(_ sender: NSButton) {
    switch sender.state {
    case .on:
      self.prefs.set(true, forKey: Utils.PrefKeys.hideMenuIcon.rawValue)
      app.statusItem.isVisible = false
    case .off:
      self.prefs.set(false, forKey: Utils.PrefKeys.hideMenuIcon.rawValue)
      app.statusItem.isVisible = true
    default: break
    }
  }

  @IBAction func showContrastSliderClicked(_ sender: NSButton) {
    switch sender.state {
    case .on:
      self.prefs.set(true, forKey: Utils.PrefKeys.showContrast.rawValue)
    case .off:
      self.prefs.set(false, forKey: Utils.PrefKeys.showContrast.rawValue)
    default: break
    }

    #if DEBUG
      os_log("Toggle show contrast slider state: %{public}@", type: .info, sender.state == .on ? "on" : "off")
    #endif

    NotificationCenter.default.post(name: Notification.Name(Utils.PrefKeys.showContrast.rawValue), object: nil)
  }

  @IBAction func showVolumeSliderClicked(_ sender: NSButton) {
    switch sender.state {
    case .on:
      self.prefs.set(true, forKey: Utils.PrefKeys.showVolume.rawValue)
    case .off:
      self.prefs.set(false, forKey: Utils.PrefKeys.showVolume.rawValue)
    default: break
    }

    #if DEBUG
      os_log("Toggle show volume slider state: %{public}@", type: .info, sender.state == .on ? "on" : "off")
    #endif

    NotificationCenter.default.post(name: Notification.Name(Utils.PrefKeys.showVolume.rawValue), object: nil)
  }

  @IBAction func lowerSwAfterBrightnessClicked(_ sender: NSButton) {
    switch sender.state {
    case .on:
      self.prefs.set(true, forKey: Utils.PrefKeys.lowerSwAfterBrightness.rawValue)
    case .off:
      self.prefs.set(false, forKey: Utils.PrefKeys.lowerSwAfterBrightness.rawValue)
      DisplayManager.shared.resetSwBrightness()
    default: break
    }
    #if DEBUG
      os_log("Toggle software control after brightness state: %{public}@", type: .info, sender.state == .on ? "on" : "off")
    #endif
  }

  @IBAction func fallbackSwClicked(_ sender: NSButton) {
    switch sender.state {
    case .on:
      self.prefs.set(true, forKey: Utils.PrefKeys.fallbackSw.rawValue)
    case .off:
      self.prefs.set(false, forKey: Utils.PrefKeys.fallbackSw.rawValue)
    default: break
    }
    #if DEBUG
      os_log("Toggle fallback to software if no DDC: %{public}@", type: .info, sender.state == .on ? "on" : "off")
    #endif

    NotificationCenter.default.post(name: Notification.Name(Utils.PrefKeys.fallbackSw.rawValue), object: nil)
  }

  @IBAction func listenForChanged(_ sender: NSPopUpButton) {
    self.prefs.set(sender.selectedTag(), forKey: Utils.PrefKeys.listenFor.rawValue)
    #if DEBUG
      os_log("Toggle keys listened for state state: %{public}@", type: .info, sender.selectedItem?.title ?? "")
    #endif
    NotificationCenter.default.post(name: Notification.Name(Utils.PrefKeys.listenFor.rawValue), object: nil)
  }

  fileprivate func setAppInfo() {
    let versionName = NSLocalizedString("v", comment: "v")
    let buildName = NSLocalizedString("b", comment: "b")
    let versionNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") ?? "error"
    let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") ?? "error"

    #if arch(arm64)

      let arch: String = NSLocalizedString("arm64", comment: "Apple Silicon designation (shown after the version number in Preferences)")

    #else

      let arch: String = NSLocalizedString("x64", comment: "Intel designation (shown after the version number in Preferences)")

    #endif

    self.versionLabel.stringValue = "\(versionName)\(versionNumber) \(buildName)\(buildNumber) \(arch)"
  }
}
