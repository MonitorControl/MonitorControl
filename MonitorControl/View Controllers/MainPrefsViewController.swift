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
  @IBOutlet var lowerContrast: NSButton!
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
    self.lowerContrast.state = self.prefs.bool(forKey: Utils.PrefKeys.lowerContrast.rawValue) ? .on : .off
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

  @IBAction func lowerContrastClicked(_ sender: NSButton) {
    switch sender.state {
    case .on:
      self.prefs.set(true, forKey: Utils.PrefKeys.lowerContrast.rawValue)
      let alert = NSAlert()
      alert.addButton(withTitle: NSLocalizedString("Ok", comment: "Shown in the alert dialog"))
      alert.messageText = NSLocalizedString("Setting up Lower contrast after brightness", comment: "Shown in the alert dialog")
      alert.informativeText = NSLocalizedString("Enabling this option will let you dim the screen even more via the brightness keys by lowering contrast after brightness has reached zero.\n\nTo make this work, please make sure that current contrast levels are properly set via the contrast slider! The contrast slider was enabled you to do that (you can disable it afterward)!", comment: "Shown in the alert dialog")
      alert.alertStyle = .warning
      alert.runModal()
      // We enable contrast slider
      self.prefs.set(true, forKey: Utils.PrefKeys.showContrast.rawValue)
      self.showContrastSlider.state = self.prefs.bool(forKey: Utils.PrefKeys.showContrast.rawValue) ? .on : .off
      NotificationCenter.default.post(name: Notification.Name(Utils.PrefKeys.showContrast.rawValue), object: nil)
    case .off:
      self.prefs.set(false, forKey: Utils.PrefKeys.lowerContrast.rawValue)
      app.resetContrastAfterBrightness()
    default: break
    }
    #if DEBUG
      os_log("Toggle lower contrast after brightness state: %{public}@", type: .info, sender.state == .on ? "on" : "off")
    #endif
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
