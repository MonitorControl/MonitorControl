import Cocoa
import DDC
import MASPreferences
import os.log

class AdvancedPrefsViewController: NSViewController, MASPreferencesViewController, NSTableViewDataSource, NSTableViewDelegate {
  var viewIdentifier: String = "Advanced"
  var toolbarItemLabel: String? = NSLocalizedString("Advanced", comment: "Shown in the main prefs window")
  var toolbarItemImage: NSImage? = NSImage(named: NSImage.advancedName)
  let prefs = UserDefaults.standard

  var displays: [ExternalDisplay] = []

  enum DisplayColumn: Int {
    case friendlyName
    case identifier
    case pollingMode
    case pollingCount
    case longerDelay
    case hideOsd
    case enableMute
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

  @IBAction func resetPrefsClicked(_: NSButton) {
    let alert: NSAlert = NSAlert()
    alert.messageText = NSLocalizedString("Reset Preferences?", comment: "Shown in the alert dialog")
    alert.informativeText = NSLocalizedString("Are you sure you want to reset all preferences?", comment: "Shown in the alert dialog")
    alert.addButton(withTitle: NSLocalizedString("Yes", comment: "Shown in the alert dialog"))
    alert.addButton(withTitle: NSLocalizedString("No", comment: "Shown in the alert dialog"))
    alert.alertStyle = NSAlert.Style.warning

    if let window = self.view.window {
      alert.beginSheetModal(for: window, completionHandler: { modalResponse in
        if modalResponse == NSApplication.ModalResponse.alertFirstButtonReturn {
          if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
            NotificationCenter.default.post(name: Notification.Name(Utils.PrefKeys.preferenceReset.rawValue), object: nil)
            os_log("Resetting all preferences.")
          }
        }
      })
    }
  }

  @IBAction func helpClicked(_: NSButton) {
    if let url = URL(string: "https://github.com/the0neyouseek/MonitorControl/wiki/Advanced-Preferences") {
      NSWorkspace.shared.open(url)
    }
  }

  @objc func loadDisplayList() {
    self.displays = DisplayManager.shared.getDdcCapableDisplays()
    self.displayList.reloadData()
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
    case .hideOsd:
      if let cell = tableView.makeView(withIdentifier: tableColumn.identifier, owner: nil) as? HideOsdCellView {
        cell.button.state = display.hideOsd ? .on : .off
        cell.display = display
        return cell
      }
    case .enableMute:
      if let cell = tableView.makeView(withIdentifier: tableColumn.identifier, owner: nil) as? EnableMuteCellView {
        cell.button.state = display.enableMuteUnmute ? .on : .off
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
