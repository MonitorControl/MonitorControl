import Cocoa
import os.log

class ButtonCellView: NSTableCellView {
  @IBOutlet var button: NSButton!
  var display: Display?
  let prefs = UserDefaults.standard

  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)
  }

  @IBAction func buttonToggled(_ sender: NSButton) {
    if let display = display {
      switch sender.state {
      case .on:
        self.prefs.set(true, forKey: "\(display.identifier)-state")
      case .off:
        self.prefs.set(false, forKey: "\(display.identifier)-state")
      default:
        break
      }

      #if DEBUG
        os_log("Toggle enabled display state: %@", type: .info, sender.state == .on ? "on" : "off")
      #endif
    }
  }
}
