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
    NotificationCenter.default.addObserver(self, selector: #selector(self.loadDisplayList), name: .displayListUpdate, object: nil)
    self.loadDisplayList()
  }

  @available(macOS, deprecated: 10.10)
  override func viewWillAppear() {
    super.viewWillAppear()
  }

  @objc func loadDisplayList() {
    os_log("Reloading Displays preferences display list", type: .info)
    self.displays = DisplayManager.shared.getAllDisplays()
    self.displayList.reloadData()
  }

  func numberOfRows(in _: NSTableView) -> Int {
    return self.displays.count
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
      // Display type
      var displayImage = ""
      if display.isVirtual {
        cell.displayType.stringValue = "Virtual Display"
        if #available(macOS 11.0, *) {
          displayImage = "tv.and.mediabox"
        }
        cell.controlMethod.stringValue = "No Control Available"
      } else if display is ExternalDisplay {
        cell.displayType.stringValue = "External Display"
        if #available(macOS 11.0, *) {
          displayImage = "display"
        }
        if let externalDisplay: ExternalDisplay = display as? ExternalDisplay {
          if externalDisplay.isSwOnly() {
            cell.controlMethod.stringValue = "Software Only"
          } else {
            if externalDisplay.isSw() {
              cell.controlMethod.stringValue = "Software (Forced)"
            } else {
              cell.controlMethod.stringValue = "Hardware (DDC)"
            }
          }
        } else {
          cell.controlMethod.stringValue = "Unspecified"
        }
      } else if display is InternalDisplay {
        cell.displayType.stringValue = "Built-in Display"
        var isImac: Bool = false
        let platformExpertDevice = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        if let modelData = IORegistryEntryCreateCFProperty(platformExpertDevice, "model" as CFString, kCFAllocatorDefault, 0).takeRetainedValue() as? Data, let modelIdentifierCString = String(data: modelData, encoding: .utf8)?.cString(using: .utf8) {
          let modelIdentifier = String(cString: modelIdentifierCString)
          isImac = modelIdentifier.contains("iMac")
        }
        if #available(macOS 11.0, *) {
          if isImac {
            displayImage = "desktopcomputer"
          } else {
            displayImage = "laptopcomputer"
          }
        }
        cell.controlMethod.stringValue = "Hardware (CoreDisplay)" // TODO: Unfinished
      } else {
        cell.displayType.stringValue = "Other Display"
        displayImage = "display.trianglebadge.exclamationmark"
        cell.controlMethod.stringValue = "No Control Available" // TODO: Unfinished
      }
      if #available(macOS 11.0, *) {
        cell.displayImage.image = NSImage(systemSymbolName: displayImage, accessibilityDescription: display.name)!
      } else {
        cell.displayImage.image = NSImage(named: NSImage.computerName)!
      }
      // Disable Volume OSD
      cell.disableVolumeOSDButton.state = .off // TODO: Unfinished
      return cell
    }
    return nil
  }
}
