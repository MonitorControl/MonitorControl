import Cocoa
import DDC
import MASPreferences
import os.log

class AdvancedPrefsViewController: NSViewController, MASPreferencesViewController, NSTableViewDataSource, NSTableViewDelegate, DisplayDelegate {
  var viewIdentifier: String = "Advanced"
  var toolbarItemLabel: String? = NSLocalizedString("Advanced", comment: "Shown in the main prefs window")
  var toolbarItemImage: NSImage? = NSImage(named: NSImage.advancedName)
  let prefs = UserDefaults.standard

  var displays: [Display] = []
  var displayManager: DisplayManager?

  enum DisplayColumn: Int {
    case friendlyName
    case identifier
    case pollingMode
    case pollingCount
  }

  @IBOutlet var displayList: NSTableView!

  override func viewDidLoad() {
    super.viewDidLoad()
    self.displayManager?.displayDelegate = self
    self.loadDisplayList()
  }

  override func viewDidAppear() {
    super.viewDidAppear()
    self.displayList.reloadData()
  }

  func didUpdateDisplays(displays: [Display]) {
    self.displays = displays
    self.displayList.reloadData()
  }

  func loadDisplayList() {
    if let displays = displayManager?.getDisplays() {
      self.displays = displays
      self.displayList.reloadData()
    }
  }

  func numberOfRows(in _: NSTableView) -> Int {
    return self.displays.count
  }

  func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
    guard let tableColumn = tableColumn,
      let columnIndex = tableView.tableColumns.firstIndex(of: tableColumn),
      let column = DisplayColumn(rawValue: columnIndex) else {
      return nil
    }
    let display = self.displays[row]
    let pollingMode = display.getPollingMode()

    switch column {
    case .friendlyName:
      if let cell = tableView.makeView(withIdentifier: tableColumn.identifier, owner: nil) as? NSTableCellView {
        cell.textField?.stringValue = "\(display.getFriendlyName())"
        return cell
      }
    case .identifier:
      if let cell = tableView.makeView(withIdentifier: tableColumn.identifier, owner: nil) as? NSTableCellView {
        cell.textField?.stringValue = "\(display.identifier)"
        return cell
      }
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
        if pollingMode == 4 {
          cell.textField?.isEnabled = true
        } else {
          cell.textField?.isEnabled = false
        }
        return cell
      }
    }
    return nil
  }

  func pollingModeDidChange(newMode: Int) {
    if newMode == 4 {} else {}
  }
}
