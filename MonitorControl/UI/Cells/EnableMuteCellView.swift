import Cocoa
import os.log

class EnableMuteCellView: NSTableCellView {
  @IBOutlet var button: NSButton!
  var display: ExternalDisplay?
  let prefs = UserDefaults.standard

  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)
  }

  @IBAction func buttonToggled(_ sender: NSButton) {
    if let display = display {
      switch sender.state {
      case .on:
        display.enableMuteUnmute = true
      case .off:
        // If the display is currently muted, toggle back to unmute
        // to prevent the display becoming stuck in the muted state
        if display.isMuted() {
          display.toggleMute()
        }

        display.enableMuteUnmute = false
      default:
        break
      }
    }
  }
}
