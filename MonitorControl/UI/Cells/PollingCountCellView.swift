import Cocoa
import os.log

class PollingCountCellView: NSTableCellView {
  var display: ExternalDisplay?

  @IBAction func valueChanged(_ sender: NSTextField) {
    if let display = display {
      let newValue = sender.stringValue
      let originalValue = "\(display.getPollingCount())"

      if newValue.isEmpty {
        self.textField?.stringValue = originalValue
      }

      if newValue != originalValue,
        !newValue.isEmpty,
        let newValue = Int(newValue) {
        display.setPollingCount(newValue)
        os_log("Value changed for polling count: %{public}@", type: .info, "from `\(originalValue)` to `\(newValue)`")
      }
    }
  }
}
