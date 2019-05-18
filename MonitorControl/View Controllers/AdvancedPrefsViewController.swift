import Cocoa
import MASPreferences
import os.log

// TODO: translations
// TODO: display specific custom polling?

class AdvancedPrefsViewController: NSViewController, MASPreferencesViewController {
  var viewIdentifier: String = "Advanced"
  var toolbarItemLabel: String? = NSLocalizedString("Advanced", comment: "Shown in the main prefs window")
  var toolbarItemImage: NSImage? = NSImage(named: NSImage.advancedName)
  let prefs = UserDefaults.standard

  @IBOutlet var pollingMode: NSPopUpButton!
  @IBOutlet var pollingCustomCount: NSTextField!

  override func viewDidLoad() {
    super.viewDidLoad()
    self.pollingMode.selectItem(at: self.prefs.integer(forKey: Utils.PrefKeys.pollingMode.rawValue))
    self.pollingCustomCount.stringValue = self.prefs.string(forKey: Utils.PrefKeys.customPollingCount.rawValue) ?? ""
    self.setCustomPollingCountVisibility()
  }

  @IBAction func pollingModeChanged(_ sender: NSPopUpButton) {
    self.prefs.set(sender.selectedTag(), forKey: Utils.PrefKeys.pollingMode.rawValue)
    os_log("Polling mode set to: %{public}@", type: .info, sender.selectedItem?.title ?? "")
    self.setCustomPollingCountVisibility()
  }

  @IBAction func pollingCountChanged(_ sender: NSTextField) {
    self.prefs.set(sender.stringValue, forKey: Utils.PrefKeys.customPollingCount.rawValue)
    os_log("Custom polling count set to: %{public}@", type: .info, sender.stringValue)
  }

  private func setCustomPollingCountVisibility() {
    let shouldHide: Bool = self.pollingMode.selectedTag() != 4
    self.pollingCustomCount.isHidden = shouldHide
  }
}
