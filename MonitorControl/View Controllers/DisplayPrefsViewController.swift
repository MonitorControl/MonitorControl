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
    case identifier
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
      os_log("Toggle allScreens state: %@", type: .info, sender.state == .on ? "on" : "off")
    #endif
  }

  // MARK: - Table datasource

  func loadDisplayList() {
    for screen in NSScreen.screens {
      let id = screen.displayID

      // Disable built-in displays.
      if screen.isBuiltin {
        let display = Display(id, name: screen.displayName ?? NSLocalizedString("Unknown", comment: "unknown display name"), isEnabled: false)
        self.displays.append(display)
        continue
      }

      let ddc = DDC(for: id)

      guard let edid = ddc?.edid() else {
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
      // Identifier
      text = "\(display.identifier)"
      cellType = DisplayCell.identifier
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
    } else {
      if let cell = tableView.makeView(withIdentifier: (tableColumn?.identifier)!, owner: nil) as? NSTableCellView {
        cell.textField?.stringValue = text
        return cell
      }
    }

    return nil
  }
}
