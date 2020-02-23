import Cocoa
import os.log

/*
 menu tags:
 0: none
 1: minimal
 2: normal
 3: heavy
 4: custom
 We use these tags as a way to mark selection
 */
class PollingModeCellView: NSTableCellView {
  var display: ExternalDisplay?
  @IBOutlet var pollingModeMenu: NSPopUpButtonCell!

  var didChangePollingMode: ((_ pollingModeInt: Int) -> Void)?

  @IBAction func valueChanged(_ sender: NSPopUpButton) {
    if let display = display {
      let newValue = sender.selectedTag()
      let originalValue = display.getPollingMode()

      if newValue != originalValue {
        display.setPollingMode(newValue)
        self.didChangePollingMode?(newValue)
        os_log("Value changed for polling count: %{public}@", type: .info, "from `\(originalValue)` to `\(newValue)`")
      }
    }
  }
}
