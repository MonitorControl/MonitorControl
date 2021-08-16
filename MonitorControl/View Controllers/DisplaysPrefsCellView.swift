import Cocoa
import os.log

class DisplaysPrefsCellView: NSTableCellView {
  var display: Display?

  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)
  }

  @IBOutlet var displayName: NSTextFieldCell!
  @IBOutlet var friendlyName: NSTextFieldCell!
  @IBOutlet var enabledButton: NSButton!
  @IBOutlet var ddcButton: NSButton!

  @IBAction func enabledButtonToggled(_ sender: NSButton) {
    if let display = display {
      let isEnabled = sender.state == .on
      display.isEnabled = isEnabled
      #if DEBUG
        os_log("Toggle enabled display state: %{public}@", type: .info, isEnabled ? "on" : "off")
      #endif
    }
  }

  @IBAction func ddcButtonToggled(_ sender: NSButton) {
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

  @IBAction func friendlyNameValueChanged(_ sender: NSTextFieldCell) {
    if let display = display {
      let newValue = sender.stringValue
      let originalValue = display.getFriendlyName()

      if newValue.isEmpty {
        self.textField?.stringValue = originalValue
        return
      }

      if newValue != originalValue, !newValue.isEmpty {
        display.setFriendlyName(newValue)
        NotificationCenter.default.post(name: Notification.Name(Utils.PrefKeys.friendlyName.rawValue), object: nil)
        #if DEBUG
          os_log("Value changed for friendly name: %{public}@", type: .info, "from `\(originalValue)` to `\(newValue)`")
        #endif
      }
    }
  }
}
