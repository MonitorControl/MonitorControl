import Cocoa
import DDC
import os.log
import Preferences

class DisplayPrefsViewController: NSViewController, PreferencePane, NSTableViewDataSource, NSTableViewDelegate {
  var preferencePaneIdentifier = Preferences.PaneIdentifier.display
  var preferencePaneTitle: String = NSLocalizedString("Display", comment: "Shown in the main prefs window")

  var toolbarItemIcon: NSImage {
    if #available(macOS 11.0, *) {
      return NSImage(systemSymbolName: "display", accessibilityDescription: "Display")!
    } else {
      // Fallback on earlier versions
      return NSImage(named: NSImage.computerName)!
    }
  }

  let prefs = UserDefaults.standard

  var displays: [Display] = []

  enum DisplayColumn: Int {
    case checkbox
    case ddc
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
    NotificationCenter.default.addObserver(self, selector: #selector(self.loadDisplayList), name: .displayListUpdate, object: nil)
    self.loadDisplayList()
  }

  override func viewWillAppear() {
    super.viewWillAppear()
    self.allScreens.state = self.prefs.bool(forKey: Utils.PrefKeys.allScreens.rawValue) ? .on : .off
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
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

  @objc func loadDisplayList() {
    self.displays = DisplayManager.shared.getAllDisplays()
    self.displayList.reloadData()
  }

  func numberOfRows(in _: NSTableView) -> Int {
    return self.displays.count
  }

  // MARK: - Table delegate

  func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
    guard let tableColumn = tableColumn,
          let columnIndex = tableView.tableColumns.firstIndex(of: tableColumn),
          let column = DisplayColumn(rawValue: columnIndex)
    else {
      return nil
    }
    let display = self.displays[row]

    switch column {
    case .checkbox:
      if let cell = tableView.makeView(withIdentifier: tableColumn.identifier, owner: nil) as? ButtonCellView {
        cell.display = display
        cell.button.state = display.isEnabled ? .on : .off
        return cell
      }
    case .ddc:

      #if arch(arm64)

        if let cell = tableView.makeView(withIdentifier: tableColumn.identifier, owner: nil) as? ButtonCellView {
          cell.display = display
          cell.button.state = ((display as? ExternalDisplay)?.arm64ddc ?? false) ? .on : .off
          cell.button.isEnabled = false
          return cell
        }

      #else

        if let cell = tableView.makeView(withIdentifier: tableColumn.identifier, owner: nil) as? ButtonCellView {
          cell.display = display
          cell.button.state = DDC(for: display.identifier) != nil ? .on : .off
          cell.button.isEnabled = false
          return cell
        }

      #endif

    case .friendlyName:
      if let cell = tableView.makeView(withIdentifier: tableColumn.identifier, owner: nil) as? FriendlyNameCellView {
        cell.display = display
        cell.textField?.stringValue = display.getFriendlyName()
        cell.textField?.isEditable = true
        return cell
      }
    default:
      if let cell = tableView.makeView(withIdentifier: tableColumn.identifier, owner: nil) as? NSTableCellView {
        cell.textField?.stringValue = self.getText(for: column, with: display)
        return cell
      }
    }

    return nil
  }

  private func getText(for column: DisplayColumn, with display: Display) -> String {
    switch column {
    case .name:
      return display.name
    case .identifier:
      return "\(display.identifier)"
    case .vendor:
      return display.identifier.vendorNumber.map { String(format: "0x%02X", $0) } ?? NSLocalizedString("Unknown", comment: "Unknown vendor")
    case .model:
      return display.identifier.modelNumber.map { String(format: "0x%02X", $0) } ?? NSLocalizedString("Unknown", comment: "Unknown model")
    default:
      return ""
    }
  }
}
