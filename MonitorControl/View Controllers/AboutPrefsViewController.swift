import Cocoa
import Preferences
import ServiceManagement

class AboutPrefsViewController: NSViewController, PreferencePane {
  let preferencePaneIdentifier = Preferences.PaneIdentifier.about
  let preferencePaneTitle: String = NSLocalizedString("About", comment: "Shown in the main prefs window")

  var toolbarItemIcon: NSImage {
    if #available(macOS 11.0, *) {
      return NSImage(systemSymbolName: "info.circle", accessibilityDescription: "About")!
    } else {
      // Fallback on earlier versions
      return NSImage(named: NSImage.infoName)!
    }
  }

  @IBOutlet var versionLabel: NSTextField!
  @IBOutlet var copyrightLabel: NSTextField!

  override func viewDidLoad() {
    super.viewDidLoad()
    self.setAppInfo()
    self.setCopyrightInfo()
  }

  @available(macOS, deprecated: 10.10)
  override func viewWillAppear() {
    super.viewWillAppear()
  }

  @IBAction func openGitHubPage(_: NSButton) {
    if let url = URL(string: "https://github.com/MonitorControl/MonitorControl/tree/experimental/apple-silicon") {
      NSWorkspace.shared.open(url)
    }
  }

  @IBAction func openIssuesPage(_: NSButton) {
    if let url = URL(string: "https://github.com/MonitorControl/MonitorControl/issues") {
      NSWorkspace.shared.open(url)
    }
  }

  func setAppInfo() {
    let versionName = NSLocalizedString("Version", comment: "Version")
    let buildName = NSLocalizedString("Build", comment: "Build")
    let versionNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") ?? "error"
    let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") ?? "error"

    #if arch(arm64)
      let arch: String = NSLocalizedString("Apple Silicon", comment: "Apple Silicon designation (shown after the version number in Preferences)")
    #else
      let arch: String = NSLocalizedString("Intel", comment: "Intel designation (shown after the version number in Preferences)")
    #endif

    self.versionLabel.stringValue = "\(versionName) \(versionNumber) \(buildName) \(buildNumber) - \(arch)"
  }

  func setCopyrightInfo() {
    let copyright = NSLocalizedString("Copyright Ⓒ MonitorControl, ", comment: "Version")
    let year = Calendar.current.component(.year, from: Date())
    self.copyrightLabel.stringValue = "\(copyright) \(year)"
  }
}
