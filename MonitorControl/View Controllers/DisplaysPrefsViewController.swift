//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Cocoa
import os.log
import Preferences

class DisplaysPrefsViewController: NSViewController, PreferencePane, NSTableViewDataSource, NSTableViewDelegate {
  let preferencePaneIdentifier = Preferences.PaneIdentifier.displays
  let preferencePaneTitle: String = NSLocalizedString("Displays", comment: "Shown in the main prefs window")

  var toolbarItemIcon: NSImage {
    if !DEBUG_MACOS10, #available(macOS 11.0, *) {
      return NSImage(systemSymbolName: "display.2", accessibilityDescription: "Displays")!
    } else {
      return NSImage(named: NSImage.infoName)!
    }
  }

  var displays: [Display] = []

  @IBOutlet var displayList: NSTableView!
  @IBOutlet var displayScrollView: NSScrollView!
  @IBOutlet var constraintHeight: NSLayoutConstraint!

  override func viewDidLoad() {
    super.viewDidLoad()
    self.loadDisplayList()
  }

  override func viewWillAppear() {
    super.viewWillAppear()
  }

  func showAdvanced() -> Bool {
    let hide = !prefs.bool(forKey: PrefKey.showAdvancedSettings.rawValue)
    self.loadDisplayList()
    return !hide
  }

  @objc func loadDisplayList() {
    os_log("Reloading Displays preferences display list", type: .info)
    self.displays = DisplayManager.shared.getAllDisplays()
    self.displayList.reloadData()
    self.updateDisplayListRowHeight()
  }

  func numberOfRows(in _: NSTableView) -> Int {
    return self.displays.count
  }

  public static func isImac() -> Bool {
    let platformExpertDevice = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
    if let modelData = IORegistryEntryCreateCFProperty(platformExpertDevice, "model" as CFString, kCFAllocatorDefault, 0).takeRetainedValue() as? Data, let modelIdentifierCString = String(data: modelData, encoding: .utf8)?.cString(using: .utf8) {
      let modelIdentifier = String(cString: modelIdentifierCString)
      return modelIdentifier.contains("iMac")
    }
    return false
  }

  public struct DisplayInfo {
    var displayType = ""
    var displayImage = ""
    var controlMethod = ""
    var controlStatus = ""
  }

  public static func getDisplayInfo(display: Display) -> DisplayInfo {
    var displayType = NSLocalizedString("Other Display", comment: "Shown in the Display Preferences")
    var displayImage = "display.trianglebadge.exclamationmark"
    var controlMethod = NSLocalizedString("No Control", comment: "Shown in the Display Preferences") + "  ⚠️"
    var controlStatus = NSLocalizedString("This display has an unspecified control status.", comment: "Shown in the Display Preferences")
    if display.isVirtual {
      displayType = NSLocalizedString("Virtual Display", comment: "Shown in the Display Preferences")
      displayImage = "tv.and.mediabox"
      controlMethod = NSLocalizedString("Software (Shade)", comment: "Shown in the Display Preferences") + "  ⚠️"
      controlStatus = NSLocalizedString("This is a virtual display (examples: AirPlay, Sidecar, display connected via a DisplayLink Dock or similar) which does not allow hardware or software gammatable control. Shading is used as a substitute but only in non-mirror scenarios. Mouse cursor will be unaffected and artifacts may appear when entering/leaving full screen mode.", comment: "Shown in the Display Preferences")
    } else if display is OtherDisplay {
      displayType = NSLocalizedString("External Display", comment: "Shown in the Display Preferences")
      displayImage = "display"
      if let otherDisplay: OtherDisplay = display as? OtherDisplay {
        if otherDisplay.isSwOnly() {
          controlMethod = NSLocalizedString("Software (Gamma)", comment: "Shown in the Display Preferences") + "  ⚠️"
          displayImage = "display.trianglebadge.exclamationmark"
          controlStatus = NSLocalizedString("This display allows for software brightness control via gammatable manipulation as it does not support hardware control. Reasons for this might be using the HDMI port of a Mac mini (which blocks hardware DDC control) or having a blacklisted display.", comment: "Shown in the Display Preferences")
        } else {
          if otherDisplay.isSw() {
            controlMethod = NSLocalizedString("Software (Gamma, Forced)", comment: "Shown in the Display Preferences") + "  ⚠️"
            controlStatus = NSLocalizedString("This display is reported to support hardware DDC control but the current settings allow for software control only.", comment: "Shown in the Display Preferences")
          } else {
            controlMethod = NSLocalizedString("Hardware (DDC)", comment: "Shown in the Display Preferences")
            controlStatus = NSLocalizedString("This display is reported to support hardware DDC control. If you encounter issues, you can disable hardware DDC control to force software control.", comment: "Shown in the Display Preferences")
          }
        }
      }
    } else if let appleDisplay: AppleDisplay = display as? AppleDisplay {
      if appleDisplay.isBuiltIn() {
        displayType = NSLocalizedString("Built-in Display", comment: "Shown in the Display Preferences")
        if self.isImac() {
          displayImage = "desktopcomputer"
        } else {
          displayImage = "laptopcomputer"
        }
      } else {
        displayType = NSLocalizedString("External Display", comment: "Shown in the Display Preferences")
        displayImage = "display"
      }
      controlMethod = NSLocalizedString("Hardware (Apple)", comment: "Shown in the Display Preferences")
      controlStatus = NSLocalizedString("This display supports native Apple brightness protocol. This allows macOS to control this display without MonitorControl as well.", comment: "Shown in the Display Preferences")
    }
    return DisplayInfo(displayType: displayType, displayImage: displayImage, controlMethod: controlMethod, controlStatus: controlStatus)
  }

  func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
    guard let tableColumn = tableColumn else {
      return nil
    }
    os_log("Populating Displays Table")
    let display = self.displays[row]
    if let cell = tableView.makeView(withIdentifier: tableColumn.identifier, owner: nil) as? DisplaysPrefsCellView {
      cell.display = display

      // ID
      cell.displayId.stringValue = String(display.identifier)
      // Firendly name
      cell.friendlyName.stringValue = display.friendlyName
      cell.friendlyName.isEditable = true
      // Enabled
      cell.enabledButton.state = display.isEnabled ? .on : .off
      // DDC
      cell.ddcButton.state = ((display as? OtherDisplay)?.isSw() ?? true) ? .off : .on
      if ((display as? OtherDisplay)?.isSwOnly() ?? true) || ((display as? OtherDisplay)?.isVirtual ?? true) {
        cell.ddcButton.isEnabled = false
      } else {
        cell.ddcButton.isEnabled = true
      }
      // Display type, image, control method
      let displayInfo = DisplaysPrefsViewController.getDisplayInfo(display: display)
      cell.displayType.stringValue = displayInfo.displayType
      cell.controlMethod.stringValue = displayInfo.controlMethod
      cell.controlMethod.controlView?.toolTip = displayInfo.controlStatus
      if !DEBUG_MACOS10, #available(macOS 11.0, *) {
        cell.displayImage.image = NSImage(systemSymbolName: displayInfo.displayImage, accessibilityDescription: display.name)!
      } else {
        cell.displayImage.image = NSImage(named: NSImage.computerName)!
      }
      // Disable Volume OSD
      if let otherDisplay = display as? OtherDisplay, !otherDisplay.isSw() {
        cell.disableVolumeOSDButton.state = otherDisplay.hideOsd ? .on : .off
        cell.disableVolumeOSDButton.isEnabled = true
      } else {
        cell.disableVolumeOSDButton.state = .off
        cell.disableVolumeOSDButton.isEnabled = false
      }
      // Advanced settings
      if let otherDisplay = display as? OtherDisplay, !otherDisplay.isSwOnly() {
        cell.pollingModeMenu.isEnabled = true
        cell.pollingModeMenu.selectItem(withTag: otherDisplay.pollingMode)
        if otherDisplay.pollingMode == PollingMode.custom.rawValue {
          cell.pollingCount.isEnabled = true
        } else {
          cell.pollingCount.isEnabled = false
        }
        cell.pollingCount.stringValue = String(otherDisplay.pollingCount)
        cell.longerDelayButton.isEnabled = true
        cell.longerDelayButton.state = otherDisplay.needsLongerDelay ? .on : .off
        cell.enableMuteButton.isEnabled = true
        cell.enableMuteButton.state = otherDisplay.enableMuteUnmute ? .on : .off

        cell.audioDeviceNameOverride.isEnabled = true
        cell.audioDeviceNameOverride.stringValue = otherDisplay.audioDeviceNameOverride
        cell.updateWithCurrentAudioName.isEnabled = true

        cell.unavailableDDCBrightness.isEnabled = true
        cell.unavailableDDCVolume.isEnabled = true
        cell.unavailableDDCContrast.isEnabled = true
        cell.unavailableDDCBrightness.state = !otherDisplay.readPrefValueKeyBool(forkey: PrefKey.unavailableDDC, for: .brightness) ? .on : .off
        cell.unavailableDDCVolume.state = !otherDisplay.readPrefValueKeyBool(forkey: PrefKey.unavailableDDC, for: .audioSpeakerVolume) ? .on : .off
        cell.unavailableDDCContrast.state = !otherDisplay.readPrefValueKeyBool(forkey: PrefKey.unavailableDDC, for: .contrast) ? .on : .off

        cell.minDDCOverrideBrightness.isEnabled = true
        cell.minDDCOverrideVolume.isEnabled = true
        cell.minDDCOverrideContrast.isEnabled = true
        cell.minDDCOverrideBrightness.stringValue = otherDisplay.readPrefValueKeyString(forkey: PrefKey.minDDCOverride, for: .brightness)
        cell.minDDCOverrideVolume.stringValue = otherDisplay.readPrefValueKeyString(forkey: PrefKey.minDDCOverride, for: .audioSpeakerVolume)
        cell.minDDCOverrideContrast.stringValue = otherDisplay.readPrefValueKeyString(forkey: PrefKey.minDDCOverride, for: .contrast)

        cell.maxDDCOverrideBrightness.isEnabled = true
        cell.maxDDCOverrideVolume.isEnabled = true
        cell.maxDDCOverrideContrast.isEnabled = true
        cell.maxDDCOverrideBrightness.stringValue = otherDisplay.readPrefValueKeyString(forkey: PrefKey.maxDDCOverride, for: .brightness)
        cell.maxDDCOverrideVolume.stringValue = otherDisplay.readPrefValueKeyString(forkey: PrefKey.maxDDCOverride, for: .audioSpeakerVolume)
        cell.maxDDCOverrideContrast.stringValue = otherDisplay.readPrefValueKeyString(forkey: PrefKey.maxDDCOverride, for: .contrast)

        cell.curveDDCBrightness.isEnabled = true
        cell.curveDDCVolume.isEnabled = true
        cell.curveDDCContrast.isEnabled = true
        cell.curveDDCBrightness.intValue = Int32(otherDisplay.readPrefValueKeyInt(forkey: PrefKey.curveDDC, for: .brightness) == 0 ? 5 : otherDisplay.readPrefValueKeyInt(forkey: PrefKey.curveDDC, for: .brightness))
        cell.curveDDCVolume.intValue = Int32(otherDisplay.readPrefValueKeyInt(forkey: PrefKey.curveDDC, for: .audioSpeakerVolume) == 0 ? 5 : otherDisplay.readPrefValueKeyInt(forkey: PrefKey.curveDDC, for: .audioSpeakerVolume))
        cell.curveDDCContrast.intValue = Int32(otherDisplay.readPrefValueKeyInt(forkey: PrefKey.curveDDC, for: .contrast) == 0 ? 5 : otherDisplay.readPrefValueKeyInt(forkey: PrefKey.curveDDC, for: .contrast))

        cell.invertDDCBrightness.state = otherDisplay.readPrefValueKeyBool(forkey: PrefKey.invertDDC, for: .brightness) ? .on : .off
        cell.invertDDCVolume.state = otherDisplay.readPrefValueKeyBool(forkey: PrefKey.invertDDC, for: .audioSpeakerVolume) ? .on : .off
        cell.invertDDCContrast.state = otherDisplay.readPrefValueKeyBool(forkey: PrefKey.invertDDC, for: .contrast) ? .on : .off
        cell.invertDDCBrightness.isEnabled = true
        cell.invertDDCVolume.isEnabled = true
        cell.invertDDCContrast.isEnabled = true

        cell.remapDDCBrightness.isEnabled = true
        cell.remapDDCVolume.isEnabled = true
        cell.remapDDCContrast.isEnabled = true
        cell.remapDDCBrightness.stringValue = otherDisplay.readPrefValueKeyString(forkey: PrefKey.remapDDC, for: .brightness) == "" ? "" : String(format: "%02x", otherDisplay.readPrefValueKeyInt(forkey: PrefKey.remapDDC, for: .brightness))
        cell.remapDDCVolume.stringValue = otherDisplay.readPrefValueKeyString(forkey: PrefKey.remapDDC, for: .audioSpeakerVolume) == "" ? "" : String(format: "%02x", otherDisplay.readPrefValueKeyInt(forkey: PrefKey.remapDDC, for: .audioSpeakerVolume))
        cell.remapDDCContrast.stringValue = otherDisplay.readPrefValueKeyString(forkey: PrefKey.remapDDC, for: .contrast) == "" ? "" : String(format: "%02x", otherDisplay.readPrefValueKeyInt(forkey: PrefKey.remapDDC, for: .contrast))
      } else {
        cell.pollingModeMenu.selectItem(withTag: 0)
        cell.pollingModeMenu.isEnabled = false
        cell.pollingCount.stringValue = ""
        cell.pollingCount.isEnabled = false
        cell.longerDelayButton.state = .off
        cell.longerDelayButton.isEnabled = false
        cell.enableMuteButton.state = .off
        cell.enableMuteButton.isEnabled = false

        cell.audioDeviceNameOverride.isEnabled = false
        cell.audioDeviceNameOverride.stringValue = ""
        cell.updateWithCurrentAudioName.isEnabled = false

        cell.unavailableDDCBrightness.state = .off
        cell.unavailableDDCVolume.state = .off
        cell.unavailableDDCContrast.state = .off
        cell.unavailableDDCBrightness.isEnabled = false
        cell.unavailableDDCVolume.isEnabled = false
        cell.unavailableDDCContrast.isEnabled = false

        cell.minDDCOverrideBrightness.stringValue = ""
        cell.minDDCOverrideVolume.stringValue = ""
        cell.minDDCOverrideContrast.stringValue = ""
        cell.minDDCOverrideBrightness.isEnabled = false
        cell.minDDCOverrideVolume.isEnabled = false
        cell.minDDCOverrideContrast.isEnabled = false

        cell.maxDDCOverrideBrightness.stringValue = ""
        cell.maxDDCOverrideVolume.stringValue = ""
        cell.maxDDCOverrideContrast.stringValue = ""
        cell.maxDDCOverrideBrightness.isEnabled = false
        cell.maxDDCOverrideVolume.isEnabled = false
        cell.maxDDCOverrideContrast.isEnabled = false

        cell.curveDDCBrightness.intValue = 5
        cell.curveDDCVolume.intValue = 5
        cell.curveDDCContrast.intValue = 5
        cell.curveDDCBrightness.isEnabled = false
        cell.curveDDCVolume.isEnabled = false
        cell.curveDDCContrast.isEnabled = false

        cell.invertDDCBrightness.state = .off
        cell.invertDDCVolume.state = .off
        cell.invertDDCContrast.state = .off
        cell.invertDDCBrightness.isEnabled = false
        cell.invertDDCVolume.isEnabled = false
        cell.invertDDCContrast.isEnabled = false

        cell.remapDDCBrightness.stringValue = ""
        cell.remapDDCVolume.stringValue = ""
        cell.remapDDCContrast.stringValue = ""
        cell.remapDDCBrightness.isEnabled = false
        cell.remapDDCVolume.isEnabled = false
        cell.remapDDCContrast.isEnabled = false
      }
      if prefs.bool(forKey: PrefKey.showAdvancedSettings.rawValue) {
        cell.advancedSettings.isHidden = false
      } else {
        cell.advancedSettings.isHidden = true
      }
      return cell
    }
    return nil
  }

  func updateDisplayListRowHeight() {
    if prefs.bool(forKey: PrefKey.showAdvancedSettings.rawValue) {
      self.displayList.rowHeight = 445
      self.constraintHeight.constant = self.displayList.rowHeight + 15
    } else {
      self.displayList.rowHeight = 165
      self.constraintHeight.constant = self.displayList.rowHeight * 2 + 15
    }
  }
}
