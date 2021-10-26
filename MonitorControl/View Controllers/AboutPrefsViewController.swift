//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Cocoa
import Preferences
import ServiceManagement

class AboutPrefsViewController: NSViewController, PreferencePane {
  let preferencePaneIdentifier = Preferences.PaneIdentifier.about
  let preferencePaneTitle: String = NSLocalizedString("About", comment: "Shown in the main prefs window")

  var toolbarItemIcon: NSImage {
    if !DEBUG_MACOS10, #available(macOS 11.0, *) {
      return NSImage(systemSymbolName: "info.circle", accessibilityDescription: "About")!
    } else {
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

  override func viewWillAppear() {
    super.viewWillAppear()
  }

  @IBAction func checkForUpdates(sender: NSButton) {
    app.updaterController.checkForUpdates(sender)
  }

  @IBAction func openDonate(_: NSButton) {
    if let url = URL(string: "https://opencollective.com/monitorcontrol/donate") {
      NSWorkspace.shared.open(url)
    }
  }

  @IBAction func openWebPage(_: NSButton) {
    if let url = URL(string: "https://monitorcontrol.app") {
      NSWorkspace.shared.open(url)
    }
  }

  @IBAction func openContributorsPage(_: NSButton) {
    if let url = URL(string: "https://github.com/MonitorControl/MonitorControl/graphs/contributors") {
      NSWorkspace.shared.open(url)
    }
  }

  func setAppInfo() {
    let versionName = NSLocalizedString("Version", comment: "Version")
    let buildName = NSLocalizedString("Build", comment: "Build")
    let versionNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") ?? "error"
    let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") ?? "error"

    self.versionLabel.stringValue = "\(versionName) \(versionNumber) \(buildName) \(buildNumber)"
  }

  func setCopyrightInfo() {
    let copyright = NSLocalizedString("Copyright Ⓒ MonitorControl, ", comment: "Version")
    let year = Calendar.current.component(.year, from: Date())
    self.copyrightLabel.stringValue = "\(copyright) \(year)"
  }
}
