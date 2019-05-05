import Cocoa
import MASPreferences

class KeysPrefsViewController: NSViewController, MASPreferencesViewController {
  var viewIdentifier: String = "Keys"
  var toolbarItemLabel: String? = NSLocalizedString("Keys", comment: "Shown in the main prefs window")
  var toolbarItemImage: NSImage? = NSImage(named: "KeyboardPref")
  let prefs = UserDefaults.standard

  @IBOutlet var listenFor: NSPopUpButton!

  override func viewDidLoad() {
    super.viewDidLoad()

    self.listenFor.selectItem(at: self.prefs.integer(forKey: Utils.PrefKeys.listenFor.rawValue))
  }

  @IBAction func listenForChanged(_ sender: NSPopUpButton) {
    self.prefs.set(sender.selectedTag(), forKey: Utils.PrefKeys.listenFor.rawValue)

    #if DEBUG
      print("Toggle keys listened for state state -> \(sender.selectedItem?.title ?? "")")
    #endif

    NotificationCenter.default.post(name: Notification.Name(Utils.PrefKeys.listenFor.rawValue), object: nil)
  }
}
