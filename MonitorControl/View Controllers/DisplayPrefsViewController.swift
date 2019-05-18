import Cocoa
import DDC
import MASPreferences
import os.log

class DisplayPrefsViewController: NSViewController, MASPreferencesViewController, NSTableViewDataSource, NSTableViewDelegate {
  var viewIdentifier: String = "Display"
  var toolbarItemLabel: String? = NSLocalizedString("Display", comment: "Shown in the main prefs window")
  var toolbarItemImage: NSImage? = NSImage(named: NSImage.computerName)
  let prefs = UserDefaults.standard

  var displays: [Display] = []
  enum DisplayCell: String {
    case checkbox
    case name
    case friendlyName
    case identifier
    case vendor
    case model
  }

  @IBOutlet var allScreens: NSButton!
  @IBOutlet var displayList: NSTableView!

  override func viewDidLoad() {
    super.viewDidLoad()

    self.allScreens.state = self.prefs.bool(forKey: Utils.PrefKeys.allScreens.rawValue) ? .on : .off

    self.loadDisplayList()
  }

  @IBAction func allScreensTouched(_ sender: NSButton) {
    switch sender.state {
    case .on:
      self.prefs.set(true, forKey: Utils.PrefKeys.allScreens.rawValue)
    case .off:
      self.prefs.set(false, forKey: Utils.PrefKeys.allScreens.rawValue)
    default: break
    }

    #if DEBUG
      os_log("Toggle allScreens state: %{public}@", type: .info, sender.state == .on ? "on" : "off")
    #endif
  }

  // MARK: - Table datasource

  func loadDisplayList() {
    for screen in NSScreen.screens {
      let id = screen.displayID

      // Disable built-in displays.
      if screen.isBuiltin {
        let display = Display(id, name: screen.displayName ?? NSLocalizedString("Unknown", comment: "Unknown display name"), isEnabled: false)
        self.displays.append(display)
        continue
      }

      guard let ddc = DDC(for: id) else {
        os_log("Display “%{public}@” cannot be controlled via DDC.", screen.displayName ?? NSLocalizedString("Unknown", comment: "Unknown display name"))
        continue
      }

      guard let edid = ddc.edid() else {
        os_log("Cannot read EDID information for display “%{public}@”.", screen.displayName ?? NSLocalizedString("Unknown", comment: "Unknown display name"))
        continue
      }

      let name = Utils.getDisplayName(forEdid: edid)
      let isEnabled = (prefs.object(forKey: "\(id)-state") as? Bool) ?? true

      let display = Display(id, name: name, isEnabled: isEnabled)
      self.displays.append(display)
    }

    self.displayList.reloadData()
  }

  func numberOfRows(in _: NSTableView) -> Int {
    return self.displays.count
  }

  // MARK: - Table delegate

  func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
    var cellType = DisplayCell.checkbox
    var checked = false
    var text = ""
    let display = self.displays[row]

    if tableColumn == tableView.tableColumns[0] {
      // Checkbox
      checked = display.isEnabled
    } else if tableColumn == tableView.tableColumns[1] {
      // Name
      text = display.name
      cellType = DisplayCell.name
    } else if tableColumn == tableView.tableColumns[2] {
      // Friendly Name
      text = display.getFriendlyName()
      cellType = DisplayCell.friendlyName
    } else if tableColumn == tableView.tableColumns[3] {
      // Identifier
      text = "\(display.identifier)"
      cellType = DisplayCell.identifier
    } else if tableColumn == tableView.tableColumns[4] {
      // Vendor
      text = display.identifier.vendorNumber.map { String(format: "0x%02X", $0) } ?? NSLocalizedString("Unknown", comment: "Unknown vendor")
      cellType = DisplayCell.vendor
    } else if tableColumn == tableView.tableColumns[5] {
      // Model
      text = display.identifier.modelNumber.map { String(format: "0x%02X", $0) } ?? NSLocalizedString("Unknown", comment: "Unknown model")
      cellType = DisplayCell.model
    }
    if cellType == DisplayCell.checkbox {
      if let cell = tableView.makeView(withIdentifier: (tableColumn?.identifier)!, owner: nil) as? ButtonCellView {
        cell.button.state = checked ? .on : .off
        cell.display = display
        if display.name == "Mac built-in Display" {
          cell.button.isEnabled = false
        }
        return cell
      }
    } else if cellType == DisplayCell.friendlyName {
      if let cell = tableView.makeView(withIdentifier: (tableColumn?.identifier)!, owner: nil) as? FriendlyNameCellView {
        cell.display = display
        cell.textField?.stringValue = text
        cell.textField?.isEditable = true
        return cell
      }
    } else {
      if let cell = tableView.makeView(withIdentifier: (tableColumn?.identifier)!, owner: nil) as? NSTableCellView {
        cell.textField?.stringValue = text
        return cell
      }
    }

    return nil
  }
}
