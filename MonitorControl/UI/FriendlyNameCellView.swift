import Cocoa
import os.log

class FriendlyNameCellView: NSTableCellView {
  var display: Display?
  let prefs = UserDefaults.standard

  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)
  }

  @IBAction func valueChanged(_ sender: NSTextFieldCell) {
    if let display = display {
      let newValue = sender.stringValue
      let originalValue = display.getFriendlyName()

      if newValue originalValue {
        print("------ Changed Value ------")
        display.setFriendlyName(newValue)
      

        #if DEBUG
          os_log("Value changed for friendly name: %{public}@", type: .info, "from `\(originalValue)` to `\(newValue)`")
        #endif
      }
    }
  }
}
