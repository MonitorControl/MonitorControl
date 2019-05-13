import Cocoa
import os.log

class FriendlyNameCellView: NSTableCellView {
  var display: Display?
  let prefs = UserDefaults.standard

  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)
  }

  @IBAction func valueChanged(_ sender: NSTextFieldCell) {
    let newValue = sender.stringValue
    let originalValue = self.display?.getFriendlyName()

    if newValue != originalValue {
      print("------ Changed Value ------")
      self.display?.setFriendlyName(newValue)
    }

    #if DEBUG
      os_log("Value changed for friendly name: %{public}@", type: .info, sender.stringValue)
    #endif
  }
}
