import Cocoa
import DDC
import os.log
import ServiceManagement

class Utils: NSObject {
  // MARK: - Menu

  /// Create a slider and add it to the menu
  ///
  /// - Parameters:
  ///   - menu: Menu containing the slider
  ///   - display: Display to control
  ///   - command: Command (Brightness/Volume/...)
  ///   - title: Title of the slider
  /// - Returns: An `NSSlider` slider
  static func addSliderMenuItem(toMenu menu: NSMenu, forDisplay display: Display, command: DDC.Command, title: String) -> SliderHandler {
    let item = NSMenuItem()

    let handler = SliderHandler(display: display, command: command)

    let slider = NSSlider(value: 0, minValue: 0, maxValue: 100, target: handler, action: #selector(SliderHandler.valueChanged))
    slider.isEnabled = false
    slider.frame.size.width = 180
    slider.frame.origin = NSPoint(x: 20, y: 5)

    handler.slider = slider

    let view = NSView(frame: NSRect(x: 0, y: 0, width: slider.frame.width + 30, height: slider.frame.height + 10))
    view.addSubview(slider)

    item.view = view

    menu.insertItem(item, at: 0)
    menu.insertItem(withTitle: title, action: nil, keyEquivalent: "", at: 0)

    DispatchQueue.global(qos: .background).async {
      defer {
        DispatchQueue.main.async {
          slider.isEnabled = true
        }
      }

      var values: (UInt16, UInt16)?
      let delay = display.needsLongerDelay ? UInt64(40 * kMillisecondScale) : nil

      let tries = UInt(display.getPollingCount())
      os_log("Polling %{public}@ times", type: .info, String(tries))

      if tries != 0 {
        values = display.readDDCValues(for: command, tries: tries, minReplyDelay: delay)
      }

      let (currentDDCValue, maxValue) = values ?? (UInt16(display.getValue(for: command)), UInt16(display.getMaxValue(for: command)))

      display.saveValue(Int(currentDDCValue), for: command)
      display.saveMaxValue(Int(maxValue), for: command)

      os_log("%{public}@ (%{public}@):", type: .info, display.name, String(reflecting: command))
      os_log(" - current ddc value: %{public}@", type: .info, String(currentDDCValue))
      os_log(" - maximum ddc value: %{public}@", type: .info, String(maxValue))

      if command != .audioSpeakerVolume {
        DispatchQueue.main.async {
          slider.integerValue = Int(currentDDCValue)
          slider.maxValue = Double(maxValue)
        }
      } else {
        // If we're looking at the audio speaker volume, also retrieve the values for the mute command
        var muteValues: (current: UInt16, max: UInt16)?
        os_log("Polling %{public}@ times", type: .info, String(tries))

        if tries != 0 {
          muteValues = display.readDDCValues(for: .audioMuteScreenBlank, tries: tries, minReplyDelay: delay)
        }

        os_log("%{public}@ (%{public}@):", type: .info, display.name, String(reflecting: DDC.Command.audioMuteScreenBlank))

        if muteValues != nil {
          os_log(" - current ddc value: %{public}@", type: .info, String(muteValues!.current))
          os_log(" - maximum ddc value: %{public}@", type: .info, String(muteValues!.max))

          display.saveValue(Int(muteValues!.current), for: .audioMuteScreenBlank)
          display.saveMaxValue(Int(muteValues!.max), for: .audioMuteScreenBlank)
        }

        // If the system is not currently muted, or doesn't support the mute command, display the current volume as the slider value
        DispatchQueue.main.async {
          if muteValues == nil || muteValues!.current == 2 {
            slider.integerValue = Int(currentDDCValue)
          } else {
            slider.integerValue = 0
          }

          slider.maxValue = Double(maxValue)
        }
      }
    }
    return handler
  }

  // MARK: - Utilities

  /// Acquire Privileges (Necessary to listen to keyboard event globally)
  static func acquirePrivileges() {
    let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: true]
    let accessibilityEnabled = AXIsProcessTrustedWithOptions(options)

    if !accessibilityEnabled {
      let alert = NSAlert()
      alert.addButton(withTitle: NSLocalizedString("Ok", comment: "Shown in the alert dialog"))
      alert.messageText = NSLocalizedString("Shortcuts not available", comment: "Shown in the alert dialog")
      alert.informativeText = NSLocalizedString("You need to enable MonitorControl in System Preferences > Security and Privacy > Accessibility for the keyboard shortcuts to work", comment: "Shown in the alert dialog")
      alert.alertStyle = .warning
      alert.runModal()
    }

    return
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

  // MARK: - Display Infos

  /// Get the name of a display
  ///
  /// - Parameter edid: the EDID of a display
  /// - Returns: a string
  static func getDisplayName(forEdid edid: EDID) -> String {
    return edid.displayName() ?? NSLocalizedString("Unknown", comment: "Unknown display name")
  }

  /// Get the main display from a list of display
  ///
  /// - Parameter displays: List of Display
  /// - Returns: the main display or nil if not found
  static func getCurrentDisplay(from displays: [Display]) -> Display? {
    guard let mainDisplayID = NSScreen.main?.displayID else {
      return nil
    }

    return displays.first { $0.identifier == mainDisplayID }
  }

  // MARK: - Enums

  /// UserDefault Keys for the app prefs
  enum PrefKeys: String {
    /// Was the app launched once
    case appAlreadyLaunched

    /// Does the app start when plugged to an external monitor
    case startWhenExternal

    /// Keys listened for (Brightness/Volume)
    case listenFor

    /// Show contrast sliders
    case showContrast

    /// Lower contrast after brightness
    case lowerContrast

    /// Change Brightness/Volume for all screens
    case allScreens

    /// Friendly name changed
    case friendlyName

    /// Prefs Reset
    case preferenceReset

    /// Used for notification when displays are updated in DisplayManager
    case displayListUpdate
  }

  /// Keys for the value of listenFor option
  enum ListenForKeys: Int {
    /// Listen for Brightness and Volume keys
    case brightnessAndVolumeKeys = 0

    /// Listen for Brightness keys only
    case brightnessOnlyKeys = 1

    /// Listen for Volume keys only
    case volumeOnlyKeys = 2
  }
}
