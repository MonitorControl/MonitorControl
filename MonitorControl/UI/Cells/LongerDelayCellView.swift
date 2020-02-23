import Cocoa
import os.log

class LongerDelayCellView: NSTableCellView {
  @IBOutlet var button: NSButton!
  var display: ExternalDisplay?
  let prefs = UserDefaults.standard

  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)
  }

  @IBAction func buttonToggled(_ sender: NSButton) {
    if let display = self.display {
      switch sender.state {
      case .on:
        let alert: NSAlert = NSAlert()
        alert.messageText = NSLocalizedString("Enable Longer Delay?", comment: "Shown in the alert dialog")
        alert.informativeText = NSLocalizedString("Are you sure you want to enable a longer delay? Doing so may freeze your system and require a restart. Start at login will be disabled as a safety measure.", comment: "Shown in the alert dialog")
        alert.addButton(withTitle: NSLocalizedString("Yes", comment: "Shown in the alert dialog"))
        alert.addButton(withTitle: NSLocalizedString("No", comment: "Shown in the alert dialog"))
        alert.alertStyle = NSAlert.Style.critical

        if let window = self.window {
          alert.beginSheetModal(for: window, completionHandler: { modalResponse in
            if modalResponse == NSApplication.ModalResponse.alertFirstButtonReturn {
              Utils.setStartAtLogin(enabled: false)
              display.needsLongerDelay = true
            } else {
              sender.state = .off
            }
          })
        }
      case .off:
        display.needsLongerDelay = false
      default:
        break
      }
    }
  }
}
