import Cocoa
import os.log
import ServiceManagement

class Utils: NSObject {
  // Acquire Privileges (Necessary to listen to keyboard event globally)
  static func acquirePrivileges() {
    if !self.readPrivileges(prompt: true) {
      let alert = NSAlert()
      alert.addButton(withTitle: NSLocalizedString("Ok", comment: "Shown in the alert dialog"))
      alert.messageText = NSLocalizedString("Shortcuts not available", comment: "Shown in the alert dialog")
      alert.informativeText = NSLocalizedString("You need to enable MonitorControl in System Preferences > Security and Privacy > Accessibility for the keyboard shortcuts to work", comment: "Shown in the alert dialog")
      alert.alertStyle = .warning
      alert.runModal()
    }
  }

  static func readPrivileges(prompt: Bool) -> Bool {
    let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: prompt]
    let status = AXIsProcessTrustedWithOptions(options)
    os_log("Reading Accessibility privileges - Current access status %{public}@", type: .info, String(status))
    return status
  }

  static func setStartAtLogin(enabled: Bool) {
    let identifier = "\(Bundle.main.bundleIdentifier!)Helper" as CFString
    SMLoginItemSetEnabled(identifier, enabled)
    os_log("Toggle start at login state: %{public}@", type: .info, enabled ? "on" : "off")
  }

  static func getSystemPreferences() -> [String: AnyObject]? {
    var propertyListFormat = PropertyListSerialization.PropertyListFormat.xml
    let plistPath = NSString(string: "~/Library/Preferences/.GlobalPreferences.plist").expandingTildeInPath
    guard let plistXML = FileManager.default.contents(atPath: plistPath) else {
      return nil
    }
    do {
      return try PropertyListSerialization.propertyList(from: plistXML, options: .mutableContainersAndLeaves, format: &propertyListFormat) as? [String: AnyObject]
    } catch {
      os_log("Error reading system prefs plist: %{public}@", type: .info, error.localizedDescription)
      return nil
    }
  }

  static func alert(text: String, info: String = "") {
    let alert = NSAlert()
    alert.messageText = text
    if info != "" {
      alert.informativeText = info
    }
    alert.alertStyle = NSAlert.Style.informational
    alert.addButton(withTitle: "OK")
    alert.runModal()
  }

  // MARK: - Enums

  // UserDefault Keys for the app prefs
  enum PrefKeys: String {
    // Build number
    case buildNumber
    // Was the app launched once
    case appAlreadyLaunched
    // Does the app start when plugged to an external monitor
    case startWhenExternal
    // Hide menu icon
    case hideMenuIcon
    // Keys listened for (Brightness/Volume)
    case listenFor
    // Hide brightness sliders
    case hideBrightness
    // Show volume sliders
    case showContrast
    // Show volume sliders
    case showVolume
    // Lower via software after brightness
    case lowerSwAfterBrightness
    // Fallback to software control for external displays with no DDC
    case fallbackSw
    // Do not show sliders for Apple displays (including built-in display) in menu
    case hideAppleFromMenu
    // Disable slider snapping
    case enableSliderSnap
    // Show tick marks for sliders
    case showTickMarks
    // Friendly name changed
    case friendlyName
    // Prefs Reset
    case preferenceReset
    // Used for notification when displays are updated in DisplayManager
    case displayListUpdate
    // Restore last saved values upon startup or wake MARK: TODO: Not implemented yet
    case restoreLastSavedValues
    // Show advanced options under Displays tab in Preferences
    case showAdvancedDisplays
    // Change Brightness for all screens MARK: TODO: Still works for volume as well (outdated implementation)
    case allScreensBrightness
    // Use focus instead of mouse position to determine which display to control for brightness MARK: TODO: Still works for volume as well (outdated implementation)
    case useFocusInsteadOfMouse
    // Change Volume for all screens MARK: TODO: Not implemented yet
    case allScreensVolume
    // Use audio device name matching to determine display to control for volume MARK: TODO: Not implemented yet
    case useAudioDeviceNameMatching
    // Use fine OSD scale for brightness and volume MARK: TODO: Not implemented yet
    case useFineScale
  }

  // Keys for the value of listenFor option
  enum ListenForKeys: Int {
    // Listen for Brightness and Volume keys
    case brightnessAndVolumeKeys = 0
    // Listen for Brightness keys only
    case brightnessOnlyKeys = 1
    // Listen for Volume keys only
    case volumeOnlyKeys = 2
    // Don't listen for any keys
    case none = 3
  }

  enum PollingMode {
    case none
    case minimal
    case normal
    case heavy
    case custom(value: Int)

    var value: Int {
      switch self {
      case .none:
        return 0
      case .minimal:
        return 5
      case .normal:
        return 10
      case .heavy:
        return 100
      case let .custom(val):
        return val
      }
    }
  }
}
