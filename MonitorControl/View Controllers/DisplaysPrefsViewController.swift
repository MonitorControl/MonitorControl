import Cocoa
import os.log
import Preferences

class DisplaysPrefsViewController: NSViewController, PreferencePane, NSTableViewDataSource, NSTableViewDelegate {
  let preferencePaneIdentifier = Preferences.PaneIdentifier.displays
  let preferencePaneTitle: String = NSLocalizedString("Displays", comment: "Shown in the main prefs window")

  var toolbarItemIcon: NSImage {
    if #available(macOS 11.0, *) {
      return NSImage(systemSymbolName: "display.2", accessibilityDescription: "Displays")!
    } else {
      return NSImage(named: NSImage.infoName)!
    }
  }

  let prefs = UserDefaults.standard
  var displays: [Display] = []

  @IBOutlet var displayList: NSTableView!

  override func viewDidLoad() {
    super.viewDidLoad()
  }

  override func viewWillAppear() {
    super.viewWillAppear()
    self.loadDisplayList()
    NotificationCenter.default.addObserver(self, selector: #selector(self.loadDisplayList), name: .displayListUpdate, object: nil)
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
      controlMethod = NSLocalizedString("No Control", comment: "Shown in the Display Preferences") + "  ⚠️"
      controlStatus = NSLocalizedString("This is a virtual display (examples: AirPlay, SideCar, display connected via a DisplayLink Dock or similar) which does not allow control.", comment: "Shown in the Display Preferences")
    } else if display is ExternalDisplay {
      displayType = NSLocalizedString("External Display", comment: "Shown in the Display Preferences")
      displayImage = "display"
      if let externalDisplay: ExternalDisplay = display as? ExternalDisplay {
        if externalDisplay.isSwOnly() {
          controlMethod = NSLocalizedString("Software Only", comment: "Shown in the Display Preferences") + "  ⚠️"
          displayImage = "display.trianglebadge.exclamationmark"
          controlStatus = NSLocalizedString("This display allows for software control only. Reasons for this might be using the HDMI port of a Mac mini (which blocks hardware DDC control) or having a blacklisted display.", comment: "Shown in the Display Preferences")
        } else {
          if externalDisplay.isSw() {
            controlMethod = NSLocalizedString("Software (Forced)", comment: "Shown in the Display Preferences") + "  ⚠️"
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
      cell.friendlyName.stringValue = display.getFriendlyName()
      cell.friendlyName.isEditable = true
      // Enabled
      cell.enabledButton.state = display.isEnabled && !display.isVirtual ? .on : .off
      cell.enabledButton.isEnabled = !display.isVirtual
      // DDC
      cell.ddcButton.state = ((display as? ExternalDisplay)?.isSw() ?? true) || ((display as? ExternalDisplay)?.isVirtual ?? true) ? .off : .on
      if ((display as? ExternalDisplay)?.isSwOnly() ?? true) || ((display as? ExternalDisplay)?.isVirtual ?? true) {
        cell.ddcButton.isEnabled = false
      } else {
        cell.ddcButton.isEnabled = true
      }
      // Display type, image, control method
      let displayInfo = DisplaysPrefsViewController.getDisplayInfo(display: display)
      cell.displayType.stringValue = displayInfo.displayType
      cell.controlMethod.stringValue = displayInfo.controlMethod
      cell.controlMethod.controlView?.toolTip = displayInfo.controlStatus
      if #available(macOS 11.0, *) {
        cell.displayImage.image = NSImage(systemSymbolName: displayInfo.displayImage, accessibilityDescription: display.name)!
      } else {
        cell.displayImage.image = NSImage(named: NSImage.computerName)!
      }
      // Disable Volume OSD
      if let externalDisplay = display as? ExternalDisplay, !externalDisplay.isVirtual, !externalDisplay.isSw() {
        cell.disableVolumeOSDButton.state = externalDisplay.hideOsd ? .on : .off
        cell.disableVolumeOSDButton.isEnabled = true
      } else {
        cell.disableVolumeOSDButton.state = .off
        cell.disableVolumeOSDButton.isEnabled = false
      }
      // Advanced settings
      if let externalDisplay = display as? ExternalDisplay, !externalDisplay.isSwOnly(), !externalDisplay.isVirtual {
        // DDC read polling mode
        cell.pollingModeMenu.isEnabled = true
        cell.pollingModeMenu.selectItem(withTag: externalDisplay.getPollingMode())
        // Custom read polling count
        if externalDisplay.getPollingMode() == 4 {
          cell.pollingCount.isEnabled = true
        } else {
          cell.pollingCount.isEnabled = false
        }
        cell.pollingCount.stringValue = String(externalDisplay.getPollingCount())
        // DDC read delay
        cell.longerDelayButton.isEnabled = true
        cell.longerDelayButton.state = externalDisplay.needsLongerDelay ? .on : .off
        cell.enableMuteButton.isEnabled = true
        cell.enableMuteButton.state = externalDisplay.enableMuteUnmute ? .on : .off
      } else {
        cell.pollingModeMenu.selectItem(withTag: 0)
        cell.pollingModeMenu.isEnabled = false
        cell.pollingCount.stringValue = ""
        cell.pollingCount.isEnabled = false
        cell.longerDelayButton.state = .off
        cell.longerDelayButton.isEnabled = false
        cell.enableMuteButton.state = .off
        cell.enableMuteButton.isEnabled = false
      }
      if self.prefs.bool(forKey: PrefKeys.showAdvancedDisplays.rawValue) {
        cell.advancedSettings.isHidden = false
      } else {
        cell.advancedSettings.isHidden = true
      }
      return cell
    }
    return nil
  }

  func updateDisplayListRowHeight() {
    if self.prefs.bool(forKey: PrefKeys.showAdvancedDisplays.rawValue) {
      self.displayList.rowHeight = 300
    } else {
      self.displayList.rowHeight = 150
    }
  }
}
