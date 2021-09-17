//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

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

  @IBOutlet var audioDeviceNameOverride: NSTextField!
  @IBOutlet var updateWithCurrentAudioName: NSButton!

  @IBOutlet var unavailableDDCBrightness: NSButton!
  @IBOutlet var unavailableDDCVolume: NSButton!
  @IBOutlet var unavailableDDCContrast: NSButton!

  @IBOutlet var minDDCOverrideBrightness: NSTextField!
  @IBOutlet var minDDCOverrideVolume: NSTextField!
  @IBOutlet var minDDCOverrideContrast: NSTextField!

  @IBOutlet var maxDDCOverrideBrightness: NSTextField!
  @IBOutlet var maxDDCOverrideVolume: NSTextField!
  @IBOutlet var maxDDCOverrideContrast: NSTextField!

  @IBOutlet var curveDDCBrightness: NSSlider!
  @IBOutlet var curveDDCVolume: NSSlider!
  @IBOutlet var curveDDCContrast: NSSlider!

  @IBOutlet var invertDDCBrightness: NSButton!
  @IBOutlet var invertDDCVolume: NSButton!
  @IBOutlet var invertDDCContrast: NSButton!

  @IBOutlet var remapDDCBrightness: NSTextField!
  @IBOutlet var remapDDCVolume: NSTextField!
  @IBOutlet var remapDDCContrast: NSTextField!

  @IBAction func openAdvancedHelp(_: NSButton) {
    if let url = URL(string: "https://github.com/the0neyouseek/MonitorControl/wiki/Advanced-Preferences") {
      NSWorkspace.shared.open(url)
    }
  }

  @IBAction func pollingModeValueChanged(_ sender: NSPopUpButton) {
    if let display = display as? OtherDisplay {
      let newValue = sender.selectedTag()
      let originalValue = display.pollingMode

      if newValue != originalValue {
        display.pollingMode = newValue
        if display.pollingMode == 4 {
          self.pollingCount.isEnabled = true
        } else {
          self.pollingCount.isEnabled = false
        }
        self.pollingCount.stringValue = String(display.pollingCount)
      }
    }
  }

  @IBAction func pollingCountValueChanged(_ sender: NSTextFieldCell) {
    if let display = display as? OtherDisplay {
      let newValue = sender.stringValue
      let originalValue = "\(display.pollingCount)"
      if newValue.isEmpty {
        self.pollingCount.stringValue = originalValue
      } else if let intValue = Int(newValue) {
        self.pollingCount.stringValue = String(intValue)
      } else {
        self.pollingCount.stringValue = ""
      }
      if newValue != originalValue, !newValue.isEmpty, let newValue = Int(newValue) {
        display.pollingCount = newValue
      }
    }
  }

  @IBAction func enableMuteButtonToggled(_ sender: NSButton) {
    if let display = display as? OtherDisplay {
      switch sender.state {
      case .on:
        display.enableMuteUnmute = true
      case .off:
        // If the display is currently muted, toggle back to unmute
        // to prevent the display becoming stuck in the muted state
        if display.readPrefValueInt(for: .audioMuteScreenBlank) == 1 {
          display.toggleMute()
        }
        display.enableMuteUnmute = false
      default:
        break
      }
    }
  }

  @IBAction func longerDelayButtonToggled(_ sender: NSButton) {
    if let display = self.display as? OtherDisplay {
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
              app.setStartAtLogin(enabled: false)
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
    }
  }

  @IBAction func ddcButtonToggled(_ sender: NSButton) {
    if let disp = display {
      switch sender.state {
      case .off:
        disp.forceSw = true
        _ = disp.setDirectBrightness(disp.getSwBrightness())
      case .on:
        disp.forceSw = false
        _ = disp.setSwBrightness(value: 1, smooth: prefs.bool(forKey: PrefKey.useSmoothBrightness.rawValue))
        _ = disp.setBrightness(1)
      default:
        break
      }
      app.updateDisplaysAndMenus()
      let displayInfo = DisplaysPrefsViewController.getDisplayInfo(display: disp)
      self.controlMethod.stringValue = displayInfo.controlMethod
      self.controlMethod.controlView?.toolTip = displayInfo.controlStatus
    }
  }

  @IBAction func friendlyNameValueChanged(_ sender: NSTextFieldCell) {
    if let disp = display {
      let newValue = sender.stringValue
      let originalValue = disp.friendlyName

      if newValue.isEmpty {
        self.friendlyName.stringValue = originalValue
        return
      }

      if newValue != originalValue, !newValue.isEmpty {
        disp.friendlyName = newValue
        NotificationCenter.default.post(name: Notification.Name(PrefKey.friendlyName.rawValue), object: nil)
      }
    }
  }

  @IBAction func disableVolumeOSDButton(_ sender: NSButton) {
    if let disp = display as? OtherDisplay {
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

  func tagCommand(_ tag: Int) -> Command {
    var command: Command
    switch tag {
    case 2: command = Command.audioSpeakerVolume
    case 3: command = Command.contrast
    default: command = Command.brightness
    }
    return command
  }

  @IBAction func audioDeviceNameOverride(_ sender: NSTextField) {
    if let display = display as? OtherDisplay {
      display.audioDeviceNameOverride = sender.stringValue
    }
    app.configure()
  }

  @IBAction func updateWithCurrentAudioName(_: NSButton) {
    if let defaultDevice = app.coreAudio.defaultOutputDevice {
      self.audioDeviceNameOverride.stringValue = defaultDevice.name
      self.audioDeviceNameOverride(self.audioDeviceNameOverride)
    }
  }

  @IBAction func unavailableDDC(_ sender: NSButton) {
    let command = self.tagCommand(sender.tag)
    let prefKey = PrefKey.unavailableDDC
    if let display = display as? OtherDisplay {
      switch sender.state {
      case .on:
        display.savePrefValueKeyBool(forkey: prefKey, value: false, for: command)
      case .off:
        display.savePrefValueKeyBool(forkey: prefKey, value: true, for: command)
      default:
        break
      }
      app.configure()
    }
  }

  @IBAction func minDDCOverride(_ sender: NSTextField) {
    let command = self.tagCommand(sender.tag)
    let prefKey = PrefKey.minDDCOverride
    let value = sender.stringValue
    if let display = display as? OtherDisplay {
      if let intValue = Int(value), intValue >= 0, intValue <= 65535 {
        display.savePrefValueKeyInt(forkey: prefKey, value: intValue, for: command)
      } else {
        display.removePrefValueKey(forkey: prefKey, for: command)
      }
      app.configure()
      if display.prefValueExistsKey(forkey: prefKey, for: command) {
        sender.stringValue = String(display.readPrefValueKeyInt(forkey: prefKey, for: command))
      } else {
        sender.stringValue = ""
      }
    } else {
      sender.stringValue = ""
    }
  }

  @IBAction func maxDDCOverride(_ sender: NSTextField) {
    let command = self.tagCommand(sender.tag)
    let prefKey = PrefKey.maxDDCOverride
    let value = sender.stringValue
    if let display = display as? OtherDisplay {
      if !value.isEmpty, let intValue = UInt(value) {
        display.savePrefValueKeyInt(forkey: prefKey, value: Int(intValue), for: command)
      } else {
        display.removePrefValueKey(forkey: prefKey, for: command)
      }
      app.configure()
      if display.prefValueExistsKey(forkey: prefKey, for: command) {
        sender.stringValue = String(display.readPrefValueKeyInt(forkey: prefKey, for: command))
      } else {
        sender.stringValue = ""
      }
    } else {
      sender.stringValue = ""
    }
  }

  @IBAction func curveDDC(_ sender: NSSlider) {
    let command = self.tagCommand(sender.tag)
    let prefKey = PrefKey.curveDDC
    let value = Int(sender.intValue)
    if let display = display as? OtherDisplay {
      display.savePrefValueKeyInt(forkey: prefKey, value: value, for: command)
    }
  }

  @IBAction func invertDDC(_ sender: NSButton) {
    let command = self.tagCommand(sender.tag)
    let prefKey = PrefKey.invertDDC
    if let display = display as? OtherDisplay {
      switch sender.state {
      case .on:
        display.savePrefValueKeyBool(forkey: prefKey, value: true, for: command)
      case .off:
        display.savePrefValueKeyBool(forkey: prefKey, value: false, for: command)
      default:
        break
      }
      app.configure()
    }
  }

  @IBAction func remapDDC(_ sender: NSTextField) {
    let command = self.tagCommand(sender.tag)
    let prefKey = PrefKey.remapDDC
    let value = sender.stringValue
    if let display = display as? OtherDisplay {
      if !value.isEmpty, let intValue = UInt(value, radix: 16), intValue != 0 {
        display.savePrefValueKeyInt(forkey: prefKey, value: Int(intValue), for: command)
      } else {
        display.removePrefValueKey(forkey: prefKey, for: command)
      }
      app.configure()
      if display.prefValueExistsKey(forkey: prefKey, for: command) {
        sender.stringValue = String(format: "%02x", display.readPrefValueKeyInt(forkey: prefKey, for: command))
      } else {
        sender.stringValue = ""
      }
    } else {
      sender.stringValue = ""
    }
  }

  @IBAction func resetSettings(_: NSButton) {
    if let disp = display {
      if self.ddcButton.isEnabled { // This signifies that the DDC block is enabled
        self.ddcButton.state = .on
        self.ddcButtonToggled(self.ddcButton)
        self.enabledButton.state = .on
        self.enabledButtonToggled(self.enabledButton)
        self.disableVolumeOSDButton.state = .off
        self.disableVolumeOSDButton(self.disableVolumeOSDButton)
        self.pollingModeMenu.selectItem(withTag: 2)
        self.pollingModeValueChanged(self.pollingModeMenu)
        self.longerDelayButton.state = .off
        self.longerDelayButtonToggled(self.longerDelayButton)
        self.enableMuteButton.state = .off
        self.enableMuteButtonToggled(self.enableMuteButton)
        self.friendlyName.stringValue = disp.name
        self.friendlyNameValueChanged(self.friendlyName)

        self.audioDeviceNameOverride.stringValue = ""
        self.audioDeviceNameOverride(self.audioDeviceNameOverride)

        self.unavailableDDCBrightness.state = .on
        self.unavailableDDCVolume.state = .on
        self.unavailableDDCContrast.state = .on

        self.minDDCOverrideBrightness.stringValue = ""
        self.minDDCOverrideVolume.stringValue = ""
        self.minDDCOverrideContrast.stringValue = ""

        self.maxDDCOverrideBrightness.stringValue = ""
        self.maxDDCOverrideVolume.stringValue = ""
        self.maxDDCOverrideContrast.stringValue = ""

        self.curveDDCBrightness.intValue = 5
        self.curveDDCVolume.intValue = 5
        self.curveDDCContrast.intValue = 5

        self.invertDDCBrightness.state = .off
        self.invertDDCVolume.state = .off
        self.invertDDCContrast.state = .off

        self.remapDDCBrightness.stringValue = ""
        self.remapDDCVolume.stringValue = ""
        self.remapDDCContrast.stringValue = ""

        self.unavailableDDC(self.unavailableDDCBrightness)

        self.unavailableDDC(self.unavailableDDCBrightness)
        self.unavailableDDC(self.unavailableDDCVolume)
        self.unavailableDDC(self.unavailableDDCContrast)

        self.minDDCOverride(self.minDDCOverrideBrightness)
        self.minDDCOverride(self.minDDCOverrideVolume)
        self.minDDCOverride(self.minDDCOverrideContrast)

        self.maxDDCOverride(self.maxDDCOverrideBrightness)
        self.maxDDCOverride(self.maxDDCOverrideVolume)
        self.maxDDCOverride(self.maxDDCOverrideContrast)

        self.curveDDC(self.curveDDCBrightness)
        self.curveDDC(self.curveDDCVolume)
        self.curveDDC(self.curveDDCContrast)

        self.invertDDC(self.invertDDCBrightness)
        self.invertDDC(self.invertDDCVolume)
        self.invertDDC(self.invertDDCContrast)

        self.remapDDC(self.remapDDCBrightness)
        self.remapDDC(self.remapDDCVolume)
        self.remapDDC(self.remapDDCContrast)
      }
    }
  }
}
