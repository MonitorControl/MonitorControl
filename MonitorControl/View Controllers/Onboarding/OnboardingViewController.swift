//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Cocoa

class OnboardingViewController: NSViewController {
  override func viewDidLoad() {
    super.viewDidLoad()
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
}
