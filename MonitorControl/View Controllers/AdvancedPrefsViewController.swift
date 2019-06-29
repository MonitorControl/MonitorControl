import Cocoa
import DDC
import MASPreferences
import os.log

class AdvancedPrefsViewController: NSViewController, MASPreferencesViewController {
  var viewIdentifier: String = "Advanced"
  var toolbarItemLabel: String? = NSLocalizedString("Advanced", comment: "Shown in the main prefs window")
  var toolbarItemImage: NSImage? = NSImage(named: NSImage.advancedName)
  let prefs = UserDefaults.standard

  var displays: [Display] = []

  @IBOutlet var pollingModePopupBtn: NSPopUpButton!
  @IBOutlet var displayPopupBtn: NSPopUpButton!
  @IBOutlet var pollingCountTxt: NSTextField!

  override func viewDidLoad() {
    super.viewDidLoad()
    self.updateDisplayPopupBtn()
    self.setSelectedPollingMode()
    self.setCustomPollingCountVisibility()
    self.setPollingCountTxt()
  }

  @IBAction func selectedPollingModeChanged(_ sender: NSPopUpButton) {
    let selectedDisplayTag = self.displayPopupBtn.selectedTag()
    let display = self.getSelectedDisplay(fromTag: selectedDisplayTag)
    let displayId = display.identifier
    self.prefs.set(sender.selectedTag(), forKey: "pollingMode-\(displayId)")
    os_log("Polling mode set to: %{public}@ for: %{public}@", type: .info, sender.selectedItem?.title ?? "", display.getFriendlyName())
    self.setCustomPollingCountVisibility()
  }

  @IBAction func pollingCountChanged(_ sender: NSTextField) {
    let selectedDisplayTag = self.displayPopupBtn.selectedTag()
    let display = self.getSelectedDisplay(fromTag: selectedDisplayTag)
    let displayId = display.identifier
    self.prefs.set(sender.stringValue, forKey: "pollingCount-\(displayId)")
    os_log("Custom polling count set to: %{public}@ for: %{public}@", type: .info, sender.stringValue, display.getFriendlyName())
  }

  @IBAction func selectedDisplayChanged(_ sender: NSPopUpButton) {
    let selectedDisplay = self.getSelectedDisplay(fromTag: sender.selectedTag())
    let pollingMode = selectedDisplay.getPollingMode()
    let pollingCount = selectedDisplay.getPollingCount()
    self.pollingModePopupBtn.selectItem(withTag: pollingMode)
    self.pollingCountTxt.stringValue = String(pollingCount)
  }

  private func updateDisplayPopupBtn() {
    for screen in NSScreen.screens {
      let id = screen.displayID

      // Disable built-in displays.
      if screen.isBuiltin {
        let display = Display(id, name: screen.displayName ?? NSLocalizedString("Unknown", comment: "Unknown display name"), isEnabled: false)
        self.displays.append(display)
        continue
      }

      guard let ddc = DDC(for: id) else {
        os_log("Display “%{public}@” cannot be controlled via DDC.", screen.displayName ?? NSLocalizedString("Unknown", comment: "Unknown display name"))
        continue
      }

      guard let edid = ddc.edid() else {
        os_log("Cannot read EDID information for display “%{public}@”.", screen.displayName ?? NSLocalizedString("Unknown", comment: "Unknown display name"))
        continue
      }

      let name = Utils.getDisplayName(forEdid: edid)
      let isEnabled = (prefs.object(forKey: "\(id)-state") as? Bool) ?? true

      let display = Display(id, name: name, isEnabled: isEnabled)
      self.displays.append(display)
    }

    self.displayPopupBtn.removeAllItems()
    for i in 0..<self.displays.count {
      let item = NSMenuItem()
      item.title = self.displays[i].getFriendlyName()
      item.tag = i
      self.displayPopupBtn.menu?.addItem(item)
    }
    self.displayPopupBtn.addItems(withTitles: self.displays.map { $0.getFriendlyName() })
  }

  private func setSelectedPollingMode() {
    let selectedDisplayTag = self.displayPopupBtn.selectedTag()
    let display = self.getSelectedDisplay(fromTag: selectedDisplayTag)
    self.pollingModePopupBtn.selectItem(at: self.prefs.integer(forKey: "pollingMode-\(display.identifier)"))
  }

  private func setPollingCountTxt() {
    let selectedDisplayTag = self.displayPopupBtn.selectedTag()
    let display = self.getSelectedDisplay(fromTag: selectedDisplayTag)
    self.pollingCountTxt.stringValue = self.prefs.string(forKey: "pollingCount-\(display.identifier)") ?? ""
  }

  private func getSelectedDisplay(fromTag tag: Int) -> Display {
    return self.displays[tag]
  }

  private func setCustomPollingCountVisibility() {
    let shouldHide: Bool = self.pollingModePopupBtn.selectedTag() != 4
    self.pollingCountTxt.isHidden = shouldHide
  }
}
