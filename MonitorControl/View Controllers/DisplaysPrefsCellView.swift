import Cocoa
import os.log

class DisplaysPrefsCellView: NSTableCellView {
  var display: Display?

  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)
  }

  @IBOutlet var displayImage: NSImageCell!
  @IBOutlet var friendlyName: NSTextFieldCell!
  @IBOutlet var displayId: NSTextFieldCell!
  @IBOutlet var enabledButton: NSButton!
  @IBOutlet var ddcButton: NSButton!
  @IBOutlet var controlMethod: NSTextFieldCell!
  @IBOutlet var displayType: NSTextFieldCell!
  @IBOutlet var disableVolumeOSDButton: NSButton!

  @IBAction func enabledButtonToggled(_ sender: NSButton) {
    if let disp = display {
      let isEnabled = sender.state == .on
      disp.isEnabled = isEnabled
      #if DEBUG
        os_log("Toggle enabled display state: %{public}@", type: .info, isEnabled ? "on" : "off")
      #endif
    }
  }

  @IBAction func ddcButtonToggled(_ sender: NSButton) {
    if let disp = display {
      switch sender.state {
      case .off:
        disp.forceSw = true
      case .on:
        disp.forceSw = false
      default:
        break
      }
      _ = disp.resetSwBrightness()
      app.updateMenus()
    }
  }

  @IBAction func friendlyNameValueChanged(_ sender: NSTextFieldCell) {
    if let disp = display {
      let newValue = sender.stringValue
      let originalValue = disp.getFriendlyName()

      if newValue.isEmpty {
        self.friendlyName.stringValue = originalValue
        return
      }

      if newValue != originalValue, !newValue.isEmpty {
        disp.setFriendlyName(newValue)
        NotificationCenter.default.post(name: Notification.Name(Utils.PrefKeys.friendlyName.rawValue), object: nil)
        #if DEBUG
          os_log("Value changed for friendly name: %{public}@", type: .info, "from `\(originalValue)` to `\(newValue)`")
        #endif
      }
    }
  }

  @IBAction func disableVolumeOSDButton(_: NSButton) {
    if let display = display {
      // TODO: Unfinished
    }
  }

  @IBAction func resetSettings(_: NSButton) {
    if let disp = display {
      self.ddcButton.state = .on
      self.ddcButtonToggled(self.ddcButton)
      self.enabledButton.state = .on
      self.enabledButtonToggled(self.enabledButton)
      self.disableVolumeOSDButton.state = .off
      self.disableVolumeOSDButton(self.disableVolumeOSDButton)
      self.friendlyName.stringValue = disp.name
      self.friendlyNameValueChanged(self.friendlyName)
    }
  }
}
