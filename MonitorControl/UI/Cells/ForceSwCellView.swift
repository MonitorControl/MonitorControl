import Cocoa
import os.log

class ForceSwCellView: NSTableCellView {
  @IBOutlet var button: NSButton!
  var display: Display?
  let prefs = UserDefaults.standard

  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)
  }

  @IBAction func buttonToggled(_ sender: NSButton) {
    if let display = display {
      switch sender.state {
      case .off:
        display.forceSw = true
      case .on:
        display.forceSw = false
      default:
        break
      }
      _ = display.resetSwBrightness()
      app.updateMenus()
    }
  }
}
