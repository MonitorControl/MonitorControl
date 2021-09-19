//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Cocoa
import Preferences
import ServiceManagement

class SynchronizationViewController: NSViewController, PreferencePane {
  let preferencePaneIdentifier = Preferences.PaneIdentifier.synchronization
  let preferencePaneTitle: String = NSLocalizedString("Syncing", comment: "Shown in the main prefs window")

  var toolbarItemIcon: NSImage {
    if #available(macOS 11.0, *) {
      return NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: "Synchronization")!
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
