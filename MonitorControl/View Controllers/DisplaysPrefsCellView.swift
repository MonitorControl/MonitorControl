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

  @IBOutlet var advancedSettings: NSBox!

  @IBOutlet var pollingModeMenu: NSPopUpButton!
  @IBOutlet var longerDelayButton: NSButton!
  @IBOutlet var pollingCount: NSTextFieldCell!
  @IBOutlet var enableMuteButton: NSButton!

  @IBAction func openAdvancedHelp(_: NSButton) {
    if let url = URL(string: "https://github.com/the0neyouseek/MonitorControl/wiki/Advanced-Preferences") {
      NSWorkspace.shared.open(url)
    }
  }

  @IBAction func pollingModeValueChanged(_ sender: NSPopUpButton) {
    if let display = display as? ExternalDisplay {
      let newValue = sender.selectedTag()
      let originalValue = display.getPollingMode()

      if newValue != originalValue {
        display.setPollingMode(newValue)
        if display.getPollingMode() == 4 {
          self.pollingCount.isEnabled = true
        } else {
          self.pollingCount.isEnabled = false
        }
        self.pollingCount.stringValue = String(display.getPollingCount())
        os_log("Value changed for polling count: %{public}@", type: .info, "from `\(originalValue)` to `\(newValue)`")
      }
    }
  }

  @IBAction func pollingCountValueChanged(_ sender: NSTextFieldCell) {
    if let display = display as? ExternalDisplay {
      let newValue = sender.stringValue
      let originalValue = "\(display.getPollingCount())"

      if newValue.isEmpty {
        self.pollingCount.stringValue = originalValue
      } else if let intValue = Int(newValue) {
        self.pollingCount.stringValue = String(intValue)
      } else {
        self.pollingCount.stringValue = ""
      }

      if newValue != originalValue, !newValue.isEmpty, let newValue = Int(newValue) {
        display.setPollingCount(newValue)
        os_log("Value changed for polling count: %{public}@", type: .info, "from `\(originalValue)` to `\(newValue)`")
      }
    }
  }

  @IBAction func enableMuteButtonToggled(_ sender: NSButton) {
    if let display = display as? ExternalDisplay {
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

  @IBAction func longerDelayButtonToggled(_ sender: NSButton) {
    if let display = self.display as? ExternalDisplay {
      switch sender.state {
      case .on:
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Enable Longer Delay?", comment: "Shown in the alert dialog")
        alert.informativeText = NSLocalizedString("Are you sure you want to enable a longer delay? Doing so may freeze your system and require a restart. Start at login will be disabled as a safety measure.", comment: "Shown in the alert dialog")
        alert.addButton(withTitle: NSLocalizedString("Yes", comment: "Shown in the alert dialog"))
        alert.addButton(withTitle: NSLocalizedString("No", comment: "Shown in the alert dialog"))
        alert.alertStyle = NSAlert.Style.critical

        if let window = self.window {
          alert.beginSheetModal(for: window, completionHandler: { modalResponse in
            if modalResponse == NSApplication.ModalResponse.alertFirstButtonReturn {
              Utils.setStartAtLogin(enabled: false)
              display.needsLongerDelay = true
            } else {
              sender.state = .off
            }
          })
        }
      case .off:
        display.needsLongerDelay = false
      default:
        break
      }
    }
  }

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
      let displayInfo = DisplaysPrefsViewController.getDisplayInfo(display: disp)
      self.controlMethod.stringValue = displayInfo.controlMethod
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

  @IBAction func disableVolumeOSDButton(_ sender: NSButton) {
    if let disp = display as? ExternalDisplay {
      switch sender.state {
      case .on:
        disp.hideOsd = true
      case .off:
        disp.hideOsd = false
      default:
        break
      }
    }
  }

  @IBAction func resetSettings(_: NSButton) {
    if let disp = display {
      if self.ddcButton.isEnabled {
        self.ddcButton.state = .on
        self.ddcButtonToggled(self.ddcButton)
      }
      if self.enabledButton.isEnabled {
        self.enabledButton.state = .on
        self.enabledButtonToggled(self.enabledButton)
      }
      if self.disableVolumeOSDButton.isEnabled {
        self.disableVolumeOSDButton.state = .off
        self.disableVolumeOSDButton(self.disableVolumeOSDButton)
      }
      if self.pollingModeMenu.isEnabled {
        self.pollingModeMenu.selectItem(withTag: 2)
        self.pollingModeValueChanged(self.pollingModeMenu)
      }
      if self.longerDelayButton.isEnabled {
        self.longerDelayButton.state = .off
        self.longerDelayButtonToggled(self.longerDelayButton)
      }
      if self.enableMuteButton.isEnabled {
        self.enableMuteButton.state = .off
        self.enableMuteButtonToggled(self.enableMuteButton)
      }
      self.friendlyName.stringValue = disp.name
      self.friendlyNameValueChanged(self.friendlyName)
    }
  }
}
