import Cocoa
import os.log
import ServiceManagement

public enum Command: UInt8 {
  // Display Control
  case horizontalFrequency = 0xAC
  case verticalFrequency = 0xAE
  case sourceColorCoding = 0xB5
  case displayUsageTime = 0xC0
  case displayControllerId = 0xC8
  case displayFirmwareLevel = 0xC9
  case osdLanguage = 0xCC
  case powerMode = 0xD6
  case imageMode = 0xDB
  case vcpVersion = 0xDF

  // Geometry
  case horizontalPosition = 0x20
  case horizontalSize = 0x22
  case horizontalPincushion = 0x24
  case horizontalPincushionBalance = 0x26
  case horizontalConvergenceRB = 0x28
  case horizontalConvergenceMG = 0x29
  case horizontalLinearity = 0x2A
  case horizontalLinearityBalance = 0x2C
  case verticalPosition = 0x30
  case verticalSize = 0x32
  case verticalPincushion = 0x34
  case verticalPincushionBalance = 0x36
  case verticalConvergenceRB = 0x38
  case verticalConvergenceMG = 0x39
  case verticalLinearity = 0x3A
  case verticalLinearityBalance = 0x3C
  case horizontalParallelogram = 0x40
  case verticalParallelogram = 0x41
  case horizontalKeystone = 0x42
  case verticalKeystone = 0x43
  case rotation = 0x44
  case topCornerFlare = 0x46
  case topCornerHook = 0x48
  case bottomCornerFlare = 0x4A
  case bottomCornerHook = 0x4C
  case horizontalMirror = 0x82
  case verticalMirror = 0x84
  case displayScaling = 0x86
  case windowPositionTopLeftX = 0x95
  case windowPositionTopLeftY = 0x96
  case windowPositionBottomRightX = 0x97
  case windowPositionBottomRightY = 0x98
  case scanMode = 0xDA

  // Miscellaneous
  case degauss = 0x01
  case newControlValue = 0x02
  case softControls = 0x03
  case activeControl = 0x52
  case performancePreservation = 0x54
  case inputSelect = 0x60
  case ambientLightSensor = 0x66
  case remoteProcedureCall = 0x76
  case displayIdentificationOnDataOperation = 0x78
  case tvChannelUpDown = 0x8B
  case flatPanelSubPixelLayout = 0xB2
  case displayTechnologyType = 0xB6
  case displayDescriptorLength = 0xC2
  case transmitDisplayDescriptor = 0xC3
  case enableDisplayOfDisplayDescriptor = 0xC4
  case applicationEnableKey = 0xC6
  case displayEnableKey = 0xC7
  case statusIndicator = 0xCD
  case auxiliaryDisplaySize = 0xCE
  case auxiliaryDisplayData = 0xCF
  case outputSelect = 0xD0
  case assetTag = 0xD2
  case auxiliaryPowerOutput = 0xD7
  case scratchPad = 0xDE

  // Audio
  case audioSpeakerVolume = 0x62
  case speakerSelect = 0x63
  case audioMicrophoneVolume = 0x64
  case audioJackConnectionStatus = 0x65
  case audioMuteScreenBlank = 0x8D
  case audioTreble = 0x8F
  case audioBass = 0x91
  case audioBalanceLR = 0x93
  case audioProcessorMode = 0x94

  // OSD/Button Event Control
  case osd = 0xCA

  // Image Adjustment
  case sixAxisHueControlBlue = 0x9F
  case sixAxisHueControlCyan = 0x9E
  case sixAxisHueControlGreen = 0x9D
  case sixAxisHueControlMagenta = 0xA0
  case sixAxisHueControlRed = 0x9B
  case sixAxisHueControlYellow = 0x9C
  case sixAxisSaturationControlBlue = 0x5D
  case sixAxisSaturationControlCyan = 0x5C
  case sixAxisSaturationControlGreen = 0x5B
  case sixAxisSaturationControlMagenta = 0x5E
  case sixAxisSaturationControlRed = 0x59
  case sixAxisSaturationControlYellow = 0x5A
  case adjustZoom = 0x7C
  case autoColorSetup = 0x1F
  case autoSetup = 0x1E
  case autoSetupOnOff = 0xA2
  case backlightControlLegacy = 0x13
  case backlightLevelWhite = 0x6B
  case backlightLevelRed = 0x6D
  case backlightLevelGreen = 0x6F
  case backlightLevelBlue = 0x71
  case blockLutOperation = 0x75
  case clock = 0x0E
  case clockPhase = 0x3E
  case colorSaturation = 0x8A
  case colorTemperatureIncrement = 0x0B
  case colorTemperatureRequest = 0x0C
  case contrast = 0x12
  case displayApplication = 0xDC
  case fleshToneEnhancement = 0x11
  case focus = 0x1C
  case gamma = 0x72
  case grayScaleExpansion = 0x2E
  case horizontalMoire = 0x56
  case hue = 0x90
  case luminance = 0x10
  case lutSize = 0x73
  case screenOrientation = 0xAA
  case selectColorPreset = 0x14
  case sharpness = 0x87
  case singlePointLutOperation = 0x74
  case stereoVideoMode = 0xD4
  case tvBlackLevel = 0x92
  case tvContrast = 0x8E
  case tvSharpness = 0x8C
  case userColorVisionCompensation = 0x17
  case velocityScanModulation = 0x88
  case verticalMoire = 0x58
  case videoBlackLevelBlue = 0x70
  case videoBlackLevelGreen = 0x6E
  case videoBlackLevelRed = 0x6C
  case videoGainBlue = 0x1A
  case videoGainGreen = 0x18
  case videoGainRed = 0x16
  case windowBackground = 0x9A
  case windowControlOnOff = 0xA4
  case windowSelect = 0xA5
  case windowSize = 0xA6
  case windowTransparency = 0xA7

  // Preset Operations
  case restoreFactoryDefaults = 0x04
  case restoreFactoryLuminanceContrastDefaults = 0x05
  case restoreFactoryGeometryDefaults = 0x06
  case restoreFactoryColorDefaults = 0x08
  case restoreFactoryTvDefaults = 0x0A
  case settings = 0xB0

  // Manufacturer Specific
  case blackStabilizer = 0xF9 // LG 38UC99-W
  case colorPresetC = 0xE0
  case powerControl = 0xE1
  case topLeftScreenPurity = 0xE8
  case topRightScreenPurity = 0xE9
  case bottomLeftScreenPurity = 0xEA
  case bottomRightScreenPurity = 0xEB

  public static let brightness = luminance
}

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
  static func addSliderMenuItem(toMenu menu: NSMenu, forDisplay display: ExternalDisplay, command: Command, title: String, numOfTickMarks: Int = 0) -> SliderHandler {
    let item = NSMenuItem()

    let handler = SliderHandler(display: display, command: command)

    let slider = NSSlider(value: 0, minValue: 0, maxValue: 100, target: handler, action: #selector(SliderHandler.valueChanged))
    slider.isEnabled = false
    handler.slider = slider

    if #available(macOS 11.0, *) {
      slider.frame.size.width = 160
      slider.frame.origin = NSPoint(x: 35, y: 5)
      let view = NSView(frame: NSRect(x: 0, y: 0, width: slider.frame.width + 47, height: slider.frame.height + 14))
      view.frame.origin = NSPoint(x: 12, y: 0)
      var iconName: String = "circle.dashed"
      switch command {
      case .audioSpeakerVolume: iconName = "speaker.wave.2"
      case .brightness: iconName = "sun.max"
      case .contrast: iconName = "circle.lefthalf.fill"
      default: break
      }
      let icon = NSImageView(image: NSImage(systemSymbolName: iconName, accessibilityDescription: title)!)
      icon.frame = view.frame
      icon.wantsLayer = true
      icon.alphaValue = 0.7
      icon.imageAlignment = NSImageAlignment.alignLeft
      view.addSubview(icon)
      view.addSubview(slider)
      item.view = view
      menu.insertItem(item, at: 0)
    } else {
      slider.frame.size.width = 180
      slider.frame.origin = NSPoint(x: 15, y: 5)
      let view = NSView(frame: NSRect(x: 0, y: 0, width: slider.frame.width + 30, height: slider.frame.height + 10))
      let sliderHeaderItem = NSMenuItem()
      let attrs: [NSAttributedString.Key: Any] = [.foregroundColor: NSColor.systemGray, .font: NSFont.systemFont(ofSize: 12)]
      sliderHeaderItem.attributedTitle = NSAttributedString(string: title, attributes: attrs)
      view.addSubview(slider)
      item.view = view
      menu.insertItem(item, at: 0)
      menu.insertItem(sliderHeaderItem, at: 0)
    }

    var values: (UInt16, UInt16)?
    let delay = display.needsLongerDelay ? UInt64(40 * kMillisecondScale) : nil

    let tries = UInt(display.getPollingCount())
    os_log("Polling %{public}@ times", type: .info, String(tries))

    var (currentValue, maxValue) = (UInt16(0), UInt16(0))

    if display.isSw(), command == Command.brightness {
      (currentValue, maxValue) = (UInt16(display.getSwBrightnessPrefValue()), UInt16(display.getSwMaxBrightness()))
    } else {
      if tries != 0 {
        values = display.readDDCValues(for: command, tries: tries, minReplyDelay: delay)
      }
      (currentValue, maxValue) = values ?? (UInt16(display.getValue(for: command)), 0) // We set 0 for max. value to indicate that there is no real DDC reported max. value - ExternalDisplay.getMaxValue() will return 100 in case of 0 max. values.
    }
    display.saveMaxValue(Int(maxValue), for: command)
    display.saveValue(min(Int(currentValue), display.getMaxValue(for: command)), for: command) // We won't allow currrent value to be higher than the max. value
    os_log("%{public}@ (%{public}@):", type: .info, display.name, String(reflecting: command))
    os_log(" - current value: %{public}@ - from display? %{public}@", type: .info, String(currentValue), String(values != nil))
    os_log(" - maximum value: %{public}@ - from display? %{public}@", type: .info, String(display.getMaxValue(for: command)), String(values != nil))

    if command == .brightness {
      if !display.isSw(), prefs.bool(forKey: Utils.PrefKeys.lowerSwAfterBrightness.rawValue) {
        slider.maxValue = Double(display.getMaxValue(for: command) * 2)
        slider.integerValue = Int(slider.maxValue) / 2 + Int(currentValue)
      } else {
        slider.integerValue = Int(currentValue)
        slider.maxValue = Double(display.getMaxValue(for: command))
      }
    } else if command == .audioSpeakerVolume {
      // If we're looking at the audio speaker volume, also retrieve the values for the mute command
      var muteValues: (current: UInt16, max: UInt16)?

      os_log("Polling %{public}@ times", type: .info, String(tries))
      os_log("%{public}@ (%{public}@):", type: .info, display.name, String(reflecting: Command.audioMuteScreenBlank))

      if tries != 0 {
        muteValues = display.readDDCValues(for: .audioMuteScreenBlank, tries: tries, minReplyDelay: delay)
      }

      if let muteValues = muteValues {
        os_log(" - current ddc value: %{public}@", type: .info, String(muteValues.current))
        os_log(" - maximum ddc value: %{public}@", type: .info, String(muteValues.max))

        display.saveValue(Int(muteValues.current), for: .audioMuteScreenBlank)
        display.saveMaxValue(Int(muteValues.max), for: .audioMuteScreenBlank)
      } else {
        os_log(" - current ddc value: unknown", type: .info)
        os_log(" - stored maximum ddc value: %{public}@", type: .info, String(display.getMaxValue(for: .audioMuteScreenBlank)))
      }

      // If the system is not currently muted, or doesn't support the mute command, display the current volume as the slider value
      if muteValues == nil || muteValues!.current == 2 {
        slider.integerValue = Int(currentValue)
      } else {
        slider.integerValue = 0
      }

      slider.maxValue = Double(display.getMaxValue(for: command))
    } else {
      slider.integerValue = Int(currentValue)
      slider.maxValue = Double(display.getMaxValue(for: command))
    }

    slider.numberOfTickMarks = numOfTickMarks
    slider.isEnabled = true
    return handler
  }

  // MARK: - Utilities

  /// Acquire Privileges (Necessary to listen to keyboard event globally)
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

  static func checksum(chk: UInt8, data: inout [UInt8], start: Int, end: Int) -> UInt8 {
    var chkd: UInt8 = chk
    for i in start ... end {
      chkd ^= data[i]
    }
    return chkd
  }

  static func alert(text: String) {
    let alert = NSAlert()
    alert.messageText = text
    alert.alertStyle = NSAlert.Style.informational
    alert.addButton(withTitle: "OK")
    alert.runModal()
  }

  // MARK: - Enums

  /// UserDefault Keys for the app prefs
  enum PrefKeys: String {
    /// Was the app launched once
    case appAlreadyLaunched

    /// Does the app start when plugged to an external monitor
    case startWhenExternal

    /// Hide menu icon
    case hideMenuIcon

    /// Keys listened for (Brightness/Volume)
    case listenFor

    /// Show contrast sliders
    case showContrast

    /// Show volume sliders
    case showVolume

    /// Lower via software after brightness
    case lowerSwAfterBrightness

    /// Fallback to software control for external displays with no DDC
    case fallbackSw

    /// Change Brightness/Volume for all screens
    case allScreens

    /// Friendly name changed
    case friendlyName

    /// Prefs Reset
    case preferenceReset

    /// Used for notification when displays are updated in DisplayManager
    case displayListUpdate

    /// Show advanced options under Displays tab in Preferences
    case showAdvancedDisplays
  }

  /// Keys for the value of listenFor option
  enum ListenForKeys: Int {
    /// Listen for Brightness and Volume keys
    case brightnessAndVolumeKeys = 0

    /// Listen for Brightness keys only
    case brightnessOnlyKeys = 1

    /// Listen for Volume keys only
    case volumeOnlyKeys = 2

    /// Don't listen for any keys
    case none = 3
  }
}
