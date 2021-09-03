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
      // Fallback on earlier versions
      return NSImage(named: NSImage.computerName)!
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
  }

  public static func getDisplayInfo(display: Display) -> DisplayInfo {
    var displayType = ""
    var displayImage = ""
    var controlMethod = ""
    if display.isVirtual {
      displayType = NSLocalizedString("Virtual Display", comment: "Shown in the Display Preferences")
      displayImage = "tv.and.mediabox"
      controlMethod = NSLocalizedString("No Control Available", comment: "Shown in the Display Preferences")
    } else if display is ExternalDisplay {
      displayType = NSLocalizedString("External Display", comment: "Shown in the Display Preferences")
      displayImage = "display"
      if let externalDisplay: ExternalDisplay = display as? ExternalDisplay {
        if externalDisplay.isSwOnly() {
          controlMethod = NSLocalizedString("Software Only", comment: "Shown in the Display Preferences")
          displayImage = "display.trianglebadge.exclamationmark"
        } else {
          if externalDisplay.isSw() {
            controlMethod = NSLocalizedString("Software (Forced)", comment: "Shown in the Display Preferences")
          } else {
            controlMethod = NSLocalizedString("Hardware (DDC)", comment: "Shown in the Display Preferences")
          }
        }
      } else {
        controlMethod = NSLocalizedString("Unspecified", comment: "Shown in the Display Preferences")
      }
    } else if display is AppleDisplay {
      displayType = NSLocalizedString("Built-in Display", comment: "Shown in the Display Preferences")
      if self.isImac() {
        displayImage = "desktopcomputer"
      } else {
        displayImage = "laptopcomputer"
      }
      controlMethod = NSLocalizedString("Hardware (Apple)", comment: "Shown in the Display Preferences")
    } else {
      displayType = NSLocalizedString("Other Display", comment: "Shown in the Display Preferences")
      displayImage = "display.trianglebadge.exclamationmark"
      controlMethod = NSLocalizedString("No Control Available", comment: "Shown in the Display Preferences")
    }
    return DisplayInfo(displayType: displayType, displayImage: displayImage, controlMethod: controlMethod)
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
      if self.prefs.bool(forKey: Utils.PrefKeys.showAdvancedDisplays.rawValue) {
        cell.advancedSettings.isHidden = false
      } else {
        cell.advancedSettings.isHidden = true
      }
      return cell
    }
    return nil
  }

  func updateDisplayListRowHeight() {
    if self.prefs.bool(forKey: Utils.PrefKeys.showAdvancedDisplays.rawValue) {
      self.displayList.rowHeight = 300
    } else {
      self.displayList.rowHeight = 150
    }
  }
}
