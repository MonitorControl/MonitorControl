import Cocoa
import Preferences
import ServiceManagement

class AdvancedPrefsViewController: NSViewController, PreferencePane {
  let preferencePaneIdentifier = Preferences.PaneIdentifier.advanced
  let preferencePaneTitle: String = NSLocalizedString("Advanced", comment: "Shown in the main prefs window")

  var toolbarItemIcon: NSImage {
    if #available(macOS 11.0, *) {
      return NSImage(systemSymbolName: "gearshape.2", accessibilityDescription: "Advanced")!
    } else {
      return NSImage(named: NSImage.infoName)!
    }
  }

  override func viewDidLoad() {
    super.viewDidLoad()
  }

  override func viewWillAppear() {
    super.viewWillAppear()
  }
}
