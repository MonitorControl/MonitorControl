//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Cocoa

class OnboardingViewController: NSViewController {
  @IBOutlet private var permissionsButton: NSButton!

  override func viewDidLoad() {
    super.viewDidLoad()
    self.setPermissionsButtonState()
  }

  // MARK: - Actions

  @IBAction func toggleStartAtLoginTouched(_ sender: NSButton) {
    app.setStartAtLogin(enabled: sender.state == .on)
  }

  @IBAction func askForPermissionsButtonTouched(_: NSButton) {
    app.checkPermissions(firstAsk: true)
  }

  @IBAction func closeButtonTouched(_: NSButton) {
    self.view.window?.close()
    DispatchQueue.main.async {
      app.statusItem.button?.performClick(self)
    }
  }

  // MARK: - Style

  private func setPermissionsButtonState() {
    let volumePermissions: Bool = [KeyboardVolume.media.rawValue, KeyboardVolume.both.rawValue].contains(prefs.integer(forKey: PrefKey.keyboardVolume.rawValue))
    let brigthnessPermissions: Bool = [KeyboardBrightness.media.rawValue, KeyboardBrightness.both.rawValue].contains(prefs.integer(forKey: PrefKey.keyboardBrightness.rawValue))
    let permissionsRequired: Bool = volumePermissions || brigthnessPermissions
    let enabled: Bool = !MediaKeyTapManager.readPrivileges(prompt: false) && permissionsRequired
    self.permissionsButton.image = enabled ? nil : NSImage(named: "onboarding_icon_checkmark")
  }
}
