import Cocoa
import os.log
import Preferences

class KeysPrefsViewController: NSViewController, PreferencePane {
  var preferencePaneIdentifier = Preferences.PaneIdentifier.keys
  var preferencePaneTitle: String = NSLocalizedString("Keys", comment: "Shown in the main prefs window")
  var toolbarItemIcon = NSImage(named: "KeyboardPref")!

  let prefs = UserDefaults.standard

  @IBOutlet var listenFor: NSPopUpButton!

  override func viewWillAppear() {
    super.viewWillAppear()
    self.listenFor.selectItem(at: self.prefs.integer(forKey: Utils.PrefKeys.listenFor.rawValue))
  }

  @IBAction func listenForChanged(_ sender: NSPopUpButton) {
    self.prefs.set(sender.selectedTag(), forKey: Utils.PrefKeys.listenFor.rawValue)
    #if DEBUG
      os_log("Toggle keys listened for state state: %{public}@", type: .info, sender.selectedItem?.title ?? "")
    #endif
    NotificationCenter.default.post(name: Notification.Name(Utils.PrefKeys.listenFor.rawValue), object: nil)
  }
}
