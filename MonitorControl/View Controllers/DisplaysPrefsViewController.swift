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
      return NSImage(named: NSImage.infoName)!
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

      // Firendly name

      cell.friendlyName.stringValue = display.getFriendlyName()
      cell.friendlyName.isEditable = true

      // Name

      cell.displayName.stringValue = display.name
      cell.friendlyName.isEditable = false

      return cell
    }
    return nil
  }
}
