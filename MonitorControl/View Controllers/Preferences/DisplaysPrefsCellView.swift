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
  @IBOutlet var avoidGamma: NSButton!
  @IBOutlet var controlMethod: NSTextFieldCell!
  @IBOutlet var displayType: NSTextFieldCell!
  @IBOutlet var disableVolumeOSDButton: NSButton!

  @IBOutlet var advancedSettings: NSBox!

  @IBOutlet var pollingModeMenu: NSPopUpButton!
  @IBOutlet var longerDelayButton: NSButton!
  @IBOutlet var pollingCount: NSTextFieldCell!
  @IBOutlet var enableMuteButton: NSButton!

  @IBOutlet var combinedBrightnessSwitchingPoint: NSSlider!

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

  @IBAction func pollingModeValueChanged(_ sender: NSPopUpButton) {
    if let display = display as? OtherDisplay {
      let newValue = sender.selectedTag()
      let originalValue = display.readPrefAsInt(key: .pollingMode)

      if newValue != originalValue {
        display.savePref(newValue, key: .pollingMode)
        if display.readPrefAsInt(key: .pollingMode) == PollingMode.custom.rawValue {
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
        display.savePref(true, key: .enableMuteUnmute)
      case .off:
        // If the display is currently muted, toggle back to unmute
        // to prevent the display becoming stuck in the muted state
        if display.readPrefAsInt(for: .audioMuteScreenBlank) == 1 {
          display.toggleMute()
        }
        display.savePref(false, key: .enableMuteUnmute)
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
              display.savePref(true, key: .longerDelay)
            } else {
              sender.state = .off
            }
          })
        }
      case .off:
        display.savePref(false, key: .longerDelay)
      default:
        break
      }
    }
  }

  @IBAction func enabledButtonToggled(_ sender: NSButton) {
    if let disp = display {
      disp.savePref(sender.state == .off, key: .isDisabled)
    }
  }

  @IBAction func ddcButtonToggled(_ sender: NSButton) {
    if let display = display {
      switch sender.state {
      case .off:
        display.savePref(true, key: .forceSw)
      case .on:
        _ = display.setDirectBrightness(1)
        display.savePref(false, key: .forceSw)
      default:
        break
      }
      _ = display.setSwBrightness(1)
      _ = display.setDirectBrightness(1)
      let displayInfo = DisplaysPrefsViewController.getDisplayInfo(display: display)
      self.controlMethod.stringValue = displayInfo.controlMethod
      self.controlMethod.controlView?.toolTip = displayInfo.controlStatus
      app.configure()
    }
  }

  @IBAction func friendlyNameValueChanged(_ sender: NSTextFieldCell) {
    if let display = display {
      let newValue = sender.stringValue
      let originalValue = (display.readPrefAsString(key: .friendlyName) != "" ? display.readPrefAsString(key: .friendlyName) : display.name)

      if newValue.isEmpty {
        self.friendlyName.stringValue = originalValue
        return
      }

      if newValue != originalValue, !newValue.isEmpty {
        display.savePref(newValue, key: .friendlyName)
      }
      app.updateMenusAndKeys()
    }
  }

  @IBAction func disableVolumeOSDButton(_ sender: NSButton) {
    if let display = display as? OtherDisplay {
      switch sender.state {
      case .on:
        display.savePref(true, key: .hideOsd)
      case .off:
        display.savePref(false, key: .hideOsd)
      default:
        break
      }
    }
  }

  @IBAction func avoidGamma(_ sender: NSButton) {
    if let display = display as? OtherDisplay {
      _ = display.setSwBrightness(1)
      _ = display.setDirectBrightness(1)
      switch sender.state {
      case .on:
        display.savePref(true, key: .avoidGamma)
      case .off:
        display.savePref(false, key: .avoidGamma)
      default:
        break
      }
      let displayInfo = DisplaysPrefsViewController.getDisplayInfo(display: display)
      self.controlMethod.stringValue = displayInfo.controlMethod
      self.controlMethod.controlView?.toolTip = displayInfo.controlStatus
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

  @IBAction func combinedBrightnessSwitchingPoint(_ sender: NSSlider) {
    if let display = display as? OtherDisplay {
      display.savePref(Int(sender.intValue), key: .combinedBrightnessSwitchingPoint)
    }
  }

  @IBAction func audioDeviceNameOverride(_ sender: NSTextField) {
    if let display = display as? OtherDisplay {
      display.savePref(sender.stringValue, key: .audioDeviceNameOverride)
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
    if let display = display {
      switch sender.state {
      case .on:
        display.savePref(false, key: prefKey, for: command)
      case .off:
        display.savePref(true, key: prefKey, for: command)
      default:
        break
      }
      _ = display.setDirectBrightness(1)
      _ = display.setSwBrightness(1)
    }
    app.configure()
  }

  @IBAction func minDDCOverride(_ sender: NSTextField) {
    let command = self.tagCommand(sender.tag)
    let prefKey = PrefKey.minDDCOverride
    let value = sender.stringValue
    if let display = display as? OtherDisplay {
      if let intValue = Int(value), intValue >= 0, intValue <= 65535 {
        display.savePref(intValue, key: prefKey, for: command)
      } else {
        display.removePref(key: prefKey, for: command)
      }
      app.configure()
      if display.prefExists(key: prefKey, for: command) {
        sender.stringValue = String(display.readPrefAsInt(key: prefKey, for: command))
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
        display.savePref(Int(intValue), key: prefKey, for: command)
      } else {
        display.removePref(key: prefKey, for: command)
      }
      app.configure()
      if display.prefExists(key: prefKey, for: command) {
        sender.stringValue = String(display.readPrefAsInt(key: prefKey, for: command))
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
      display.savePref(value, key: prefKey, for: command)
    }
  }

  @IBAction func invertDDC(_ sender: NSButton) {
    let command = self.tagCommand(sender.tag)
    let prefKey = PrefKey.invertDDC
    if let display = display as? OtherDisplay {
      switch sender.state {
      case .on:
        display.savePref(true, key: prefKey, for: command)
      case .off:
        display.savePref(false, key: prefKey, for: command)
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
    let values = value.components(separatedBy: ",")
    var normalizedValues: [String] = []
    var normalizedString: String = ""
    for value in values {
      let trimmedValue = value.trimmingCharacters(in: CharacterSet(charactersIn: " "))
      if !trimmedValue.isEmpty, let intValue = UInt8(trimmedValue, radix: 16), intValue != 0 {
        normalizedValues.append(String(format: "%02x", intValue))
      }
    }
    var first = true
    for normalizedValue in normalizedValues {
      if !first {
        normalizedString.append(", ")
      }
      normalizedString.append(normalizedValue)
      first = false
    }
    if let display = display as? OtherDisplay {
      display.savePref(normalizedString, key: prefKey, for: command)
    }
    sender.stringValue = normalizedString
  }

  @IBAction func resetSettings(_: NSButton) {
    if let disp = display {
      if self.ddcButton.isEnabled { // This signifies that the DDC block is enabled
        self.ddcButton.state = .on
        self.ddcButtonToggled(self.ddcButton)
        self.avoidGamma.state = .off
        self.avoidGamma(self.avoidGamma)
        self.disableVolumeOSDButton.state = .off
        self.disableVolumeOSDButton(self.disableVolumeOSDButton)
        self.pollingModeMenu.selectItem(withTag: 2)
        self.pollingModeValueChanged(self.pollingModeMenu)
        self.longerDelayButton.state = .off
        self.longerDelayButtonToggled(self.longerDelayButton)
        self.combinedBrightnessSwitchingPoint.intValue = 0
        self.combinedBrightnessSwitchingPoint(self.combinedBrightnessSwitchingPoint)
        self.audioDeviceNameOverride.stringValue = ""
        self.audioDeviceNameOverride(self.audioDeviceNameOverride)

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
      self.unavailableDDCBrightness.state = .on
      self.unavailableDDC(self.unavailableDDCBrightness)
      self.friendlyName.stringValue = disp.name
      self.friendlyNameValueChanged(self.friendlyName)
      self.enabledButton.state = .on
      self.enabledButtonToggled(self.enabledButton)
    }
  }
}
