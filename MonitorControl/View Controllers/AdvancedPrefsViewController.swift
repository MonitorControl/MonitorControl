import Cocoa
import DDC
import os.log
import Preferences

class AdvancedPrefsViewController: NSViewController, PreferencePane, NSTableViewDataSource, NSTableViewDelegate {
  var preferencePaneIdentifier = Preferences.PaneIdentifier.advanced
  var preferencePaneTitle: String = NSLocalizedString("Advanced", comment: "Shown in the main prefs window")

  var toolbarItemIcon: NSImage {
    if #available(macOS 11.0, *) {
      return NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Advanced")!
    } else {
      // Fallback on earlier versions
      return NSImage(named: NSImage.advancedName)!
    }
  }

  let prefs = UserDefaults.standard

  var displays: [ExternalDisplay] = []

  enum DisplayColumn: Int {
    case friendlyName
    case identifier
    case pollingMode
    case pollingCount
    case longerDelay
  }

  @IBOutlet var displayList: NSTableView!

  override func viewDidLoad() {
    super.viewDidLoad()
    NotificationCenter.default.addObserver(self, selector: #selector(self.loadDisplayList), name: .displayListUpdate, object: nil)
    self.loadDisplayList()
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  @IBAction func helpClicked(_: NSButton) {
    if let url = URL(string: "https://github.com/the0neyouseek/MonitorControl/wiki/Advanced-Preferences") {
      NSWorkspace.shared.open(url)
    }
  }

  @objc func loadDisplayList() {
    os_log("Reloading advanced preferences display list", type: .info)
    self.displays = DisplayManager.shared.getDdcCapableDisplays()
    self.displayList.reloadData()
  }

  func numberOfRows(in _: NSTableView) -> Int {
    return self.displays.count
  }

  func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
    guard let tableColumn = tableColumn,
          let columnIndex = tableView.tableColumns.firstIndex(of: tableColumn),
          let column = DisplayColumn(rawValue: columnIndex)
    else {
      return nil
    }
    let display = self.displays[row]
    let pollingMode = display.getPollingMode()

    switch column {
    case .pollingMode:
      if let cell = tableView.makeView(withIdentifier: tableColumn.identifier, owner: nil) as? PollingModeCellView {
        cell.display = display
        cell.pollingModeMenu.selectItem(withTag: pollingMode)
        cell.didChangePollingMode = { _ in
          // if the polling mode changed, reload the row so we can enable/disable the PollingCount field
          tableView.reloadData(forRowIndexes: [row], columnIndexes: [DisplayColumn.pollingCount.rawValue])
        }
        return cell
      }
    case .pollingCount:
      if let cell = tableView.makeView(withIdentifier: tableColumn.identifier, owner: nil) as? PollingCountCellView {
        cell.textField?.stringValue = "\(display.getPollingCount())"
        cell.display = display
        cell.textField?.isEnabled = pollingMode == 4
        return cell
      }
    case .longerDelay:
      if let cell = tableView.makeView(withIdentifier: tableColumn.identifier, owner: nil) as? LongerDelayCellView {
        cell.button.state = display.needsLongerDelay ? .on : .off
        cell.display = display
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

  private func getText(for column: DisplayColumn, with display: ExternalDisplay) -> String {
    switch column {
    case .friendlyName:
      return display.getFriendlyName()
    case .identifier:
      return "\(display.identifier)"
    default:
      return ""
    }
  }
}
