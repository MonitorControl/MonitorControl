import Cocoa
import os.log

class HideOsdCellView: NSTableCellView {
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
        display.hideOsd = true
      case .off:
        display.hideOsd = false
      default:
        break
      }
    }
  }
}
