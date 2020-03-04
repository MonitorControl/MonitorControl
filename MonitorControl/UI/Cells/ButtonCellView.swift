import Cocoa
import os.log

class ButtonCellView: NSTableCellView {
  @IBOutlet var button: NSButton!
  var display: Display?

  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)
  }

  @IBAction func buttonToggled(_ sender: NSButton) {
    if let display = display {
      let isEnabled = sender.state == .on
      display.isEnabled = isEnabled
      #if DEBUG
        os_log("Toggle enabled display state: %{public}@", type: .info, isEnabled ? "on" : "off")
      #endif
      NotificationCenter.default.post(name: Notification.Name(Utils.PrefKeys.listenFor.rawValue), object: nil)
    }
  }
}
