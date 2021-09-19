//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Cocoa
import CoreGraphics
import os.log

let DEBUG_GAMMA_ENFORCER = false

class DisplayManager {
  public static let shared = DisplayManager()

  var displays: [Display] = []
  var audioControlTargetDisplays: [OtherDisplay] = []

  // Gamma activity enforcer and window shade

  func resolveEffectiveDisplayID(_ displayID: CGDirectDisplayID) -> CGDirectDisplayID {
    var realDisplayID = displayID
    if CGDisplayIsInHWMirrorSet(displayID) != 0 || CGDisplayIsInMirrorSet(displayID) != 0 {
      let mirroredDisplayID = CGDisplayMirrorsDisplay(displayID)
      if mirroredDisplayID != 0 {
        realDisplayID = mirroredDisplayID
      }
    }
    return realDisplayID
  }

  let gammaActivityEnforcer = NSWindow(contentRect: .init(origin: NSPoint(x: 0, y: 0), size: .init(width: DEBUG_GAMMA_ENFORCER ? 15 : 1, height: DEBUG_GAMMA_ENFORCER ? 15 : 1)), styleMask: [], backing: .buffered, defer: false)

  func createGammaActivityEnforcer() {
    self.gammaActivityEnforcer.title = "Monior Control Gamma Activity Enforcer"
    self.gammaActivityEnforcer.isMovableByWindowBackground = false
    self.gammaActivityEnforcer.backgroundColor = DEBUG_GAMMA_ENFORCER ? .red : .black
    self.gammaActivityEnforcer.ignoresMouseEvents = true
    self.gammaActivityEnforcer.level = .screenSaver
    self.gammaActivityEnforcer.orderFrontRegardless()
    self.gammaActivityEnforcer.collectionBehavior = [.stationary, .canJoinAllSpaces]
    os_log("Gamma activity enforcer created.", type: .debug)
  }

  func enforceGammaActivity() {
    if self.gammaActivityEnforcer.alphaValue == 1 * (DEBUG_GAMMA_ENFORCER ? 0.5 : 0.01) {
      self.gammaActivityEnforcer.alphaValue = 2 * (DEBUG_GAMMA_ENFORCER ? 0.5 : 0.01)
    } else {
      self.gammaActivityEnforcer.alphaValue = 1 * (DEBUG_GAMMA_ENFORCER ? 0.5 : 0.01)
    }
  }

  func moveGammaActivityEnforcer(displayID: CGDirectDisplayID) {
    if let screen = NSScreen.getByDisplayID(displayID: resolveEffectiveDisplayID(displayID)) {
      self.gammaActivityEnforcer.setFrameOrigin(screen.frame.origin)
    }
    self.gammaActivityEnforcer.orderFrontRegardless()
  }

  internal var shades: [CGDirectDisplayID: NSWindow] = [:]

  func isDisqualifiedFromShade(_ displayID: CGDirectDisplayID) -> Bool { // We ban mirror members from shade control as it might lead to double control
    return (CGDisplayIsInHWMirrorSet(displayID) != 0 || CGDisplayIsInMirrorSet(displayID) != 0) ? true : false
  }

  internal func createShadeOnDisplay(displayID: CGDirectDisplayID) -> NSWindow? {
    if let screen = NSScreen.getByDisplayID(displayID: displayID) {
      let windowShade = NSWindow(contentRect: .init(origin: NSPoint(x: 0, y: 0), size: .init(width: 10, height: 1)), styleMask: [], backing: .buffered, defer: false)
      windowShade.title = "Monitor Control Window Shade for Display " + String(displayID)
      windowShade.isMovableByWindowBackground = false
      windowShade.backgroundColor = .black
      windowShade.ignoresMouseEvents = true
      windowShade.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
      windowShade.alphaValue = 0
      windowShade.orderFrontRegardless()
      windowShade.collectionBehavior = [.stationary, .canJoinAllSpaces, .ignoresCycle]
      windowShade.setFrame(screen.frame, display: true)
      os_log("Window shade created.", type: .debug)
      return windowShade
    }
    return nil
  }

  func getShade(displayID: CGDirectDisplayID) -> NSWindow? {
    guard !self.isDisqualifiedFromShade(displayID) else {
      return nil
    }
    if let shade = shades[displayID] {
      return shade
    } else {
      if let shade = self.createShadeOnDisplay(displayID: displayID) {
        self.shades[displayID] = shade
        return shade
      }
    }
    return nil
  }

  func destroyShade(displayID: CGDirectDisplayID) -> Bool {
    guard !self.isDisqualifiedFromShade(displayID) else {
      return false
    }
    if let shade = shades[displayID] {
      shade.alphaValue = 1
      shade.close()
      self.shades.removeValue(forKey: displayID)
      return true
    }
    return false
  }

  func updateShade(displayID: CGDirectDisplayID) -> Bool {
    guard !self.isDisqualifiedFromShade(displayID) else {
      return false
    }
    if let screen = NSScreen.getByDisplayID(displayID: displayID) {
      if let shade = getShade(displayID: displayID) {
        shade.setFrame(screen.frame, display: true)
        return true
      }
    }
    return false
  }

  func getShadeAlpha(displayID: CGDirectDisplayID) -> Float? {
    guard !self.isDisqualifiedFromShade(displayID) else {
      return 1
    }
    if let shade = getShade(displayID: displayID) {
      return Float(shade.alphaValue)
    } else {
      return 1
    }
  }

  func setShadeAlpha(value: Float, displayID: CGDirectDisplayID) -> Bool {
    guard !self.isDisqualifiedFromShade(displayID) else {
      return false
    }
    if let shade = getShade(displayID: displayID) {
      shade.alphaValue = CGFloat(value)
      return true
    }
    return false
  }

  // Display utilities

  func updateDisplays() {
    self.clearDisplays()
    var onlineDisplayIDs = [CGDirectDisplayID](repeating: 0, count: 16)
    var displayCount: UInt32 = 0
    guard CGGetOnlineDisplayList(16, &onlineDisplayIDs, &displayCount) == .success else {
      os_log("Unable to get display list.", type: .info)
      return
    }
    for onlineDisplayID in onlineDisplayIDs where onlineDisplayID != 0 {
      let name = DisplayManager.getDisplayNameByID(displayID: onlineDisplayID)
      let id = onlineDisplayID
      let vendorNumber = CGDisplayVendorNumber(onlineDisplayID)
      let modelNumber = CGDisplayModelNumber(onlineDisplayID)
      let display: Display
      var isVirtual: Bool = false
      if #available(macOS 11.0, *) {
        if let dictionary = ((CoreDisplay_DisplayCreateInfoDictionary(onlineDisplayID))?.takeRetainedValue() as NSDictionary?) {
          let isVirtualDevice = dictionary["kCGDisplayIsVirtualDevice"] as? Bool
          let displayIsAirplay = dictionary["kCGDisplayIsAirPlay"] as? Bool
          if isVirtualDevice ?? displayIsAirplay ?? false {
            isVirtual = true
          }
        }
      }
      if !DEBUG_SW, DisplayManager.isAppleDisplay(displayID: onlineDisplayID) { // MARK: (point of interest for testing)
        display = AppleDisplay(id, name: name, vendorNumber: vendorNumber, modelNumber: modelNumber, isVirtual: isVirtual)
      } else {
        display = OtherDisplay(id, name: name, vendorNumber: vendorNumber, modelNumber: modelNumber, isVirtual: isVirtual)
      }
      self.addDisplay(display: display)
    }
  }

  func normalizedName(_ name: String) -> String {
    var normalizedName = name.replacingOccurrences(of: "(", with: "")
    normalizedName = normalizedName.replacingOccurrences(of: ")", with: "")
    normalizedName = normalizedName.replacingOccurrences(of: " ", with: "")
    for i in 0 ... 9 {
      normalizedName = normalizedName.replacingOccurrences(of: String(i), with: "")
    }
    return normalizedName
  }

  func updateAudioControlTargetDisplays(deviceName: String) -> Int {
    self.audioControlTargetDisplays.removeAll()
    os_log("Detecting displays for audio control via audio device name matching...", type: .debug)
    var numOfAddedDisplays: Int = 0
    for ddcCapableDisplay in self.getDdcCapableDisplays() {
      var displayAudioDeviceName = ddcCapableDisplay.audioDeviceNameOverride
      if displayAudioDeviceName == "" {
        displayAudioDeviceName = DisplayManager.getDisplayRawNameByID(displayID: ddcCapableDisplay.identifier)
      }
      if self.normalizedName(displayAudioDeviceName) == self.normalizedName(deviceName) {
        self.audioControlTargetDisplays.append(ddcCapableDisplay)
        numOfAddedDisplays += 1
        os_log("Added display for audio control - %{public}@", type: .debug, ddcCapableDisplay.name)
      }
    }
    return numOfAddedDisplays
  }

  func getOtherDisplays() -> [OtherDisplay] {
    return self.displays.compactMap { $0 as? OtherDisplay }
  }

  func getAllDisplays() -> [Display] {
    return self.displays
  }

  func getDdcCapableDisplays() -> [OtherDisplay] {
    return self.displays.compactMap { display -> OtherDisplay? in
      if let otherDisplay = display as? OtherDisplay, !otherDisplay.isSw() {
        return otherDisplay
      } else { return nil }
    }
  }

  func getAppleDisplays() -> [AppleDisplay] {
    return self.displays.compactMap { $0 as? AppleDisplay }
  }

  func getBuiltInDisplay() -> Display? {
    return self.displays.first { CGDisplayIsBuiltin($0.identifier) != 0 }
  }

  func getCurrentDisplay(byFocus: Bool = false) -> Display? {
    if byFocus {
      guard let mainDisplayID = NSScreen.main?.displayID else {
        return nil
      }
      return self.displays.first { $0.identifier == mainDisplayID }
    } else {
      let mouseLocation = NSEvent.mouseLocation
      let screens = NSScreen.screens
      if let screenWithMouse = (screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }) {
        return self.displays.first { $0.identifier == screenWithMouse.displayID }
      }
      return nil
    }
  }

  func addDisplay(display: Display) {
    self.displays.append(display)
  }

  func clearDisplays() {
    self.displays = []
  }

  func addDisplayCounterSuffixes() {
    var nameDisplays: [String: [Display]] = [:]
    for display in self.displays {
      if nameDisplays[display.name] != nil {
        nameDisplays[display.name]?.append(display)
      } else {
        nameDisplays[display.name] = [display]
      }
    }
    for nameDisplayKey in nameDisplays.keys where nameDisplays[nameDisplayKey]?.count ?? 0 > 1 {
      for i in 0 ... (nameDisplays[nameDisplayKey]?.count ?? 1) - 1 {
        if let display = nameDisplays[nameDisplayKey]?[i] {
          display.name = "" + display.name + " (" + String(i + 1) + ")"
        }
      }
    }
  }

  func updateArm64AVServices() {
    if Arm64DDC.isArm64 {
      os_log("arm64 AVService update requested", type: .info)
      var displayIDs: [CGDirectDisplayID] = []
      for otherDisplay in self.getOtherDisplays() {
        displayIDs.append(otherDisplay.identifier)
      }
      for serviceMatch in Arm64DDC.getServiceMatches(displayIDs: displayIDs) {
        for otherDisplay in self.getOtherDisplays() where otherDisplay.identifier == serviceMatch.displayID && serviceMatch.service != nil {
          otherDisplay.arm64avService = serviceMatch.service
          os_log("Display service match successful for display %{public}@", type: .info, String(serviceMatch.displayID))
          if serviceMatch.isDiscouraged {
            os_log("Display %{public}@ is flagged as discouraged by Arm64DDC.", type: .info, String(serviceMatch.displayID))
            otherDisplay.isDiscouraged = serviceMatch.isDiscouraged
          } else {
            otherDisplay.arm64ddc = DEBUG_SW ? false : true // MARK: (point of interest when testing)
          }
        }
      }
      os_log("AVService update done", type: .info)
    }
  }

  // Semi-static functions (could be moved elsewhere easily)

  func resetSwBrightnessForAllDisplays(settingsOnly: Bool = false, async: Bool = false) {
    for otherDisplay in self.getOtherDisplays() {
      if !settingsOnly {
        _ = otherDisplay.setSwBrightness(1, smooth: async)
        otherDisplay.smoothBrightnessTransient = 1
      } else {
        otherDisplay.swBrightness = 1
        otherDisplay.smoothBrightnessTransient = 1
      }
      if otherDisplay.isSw() {
        otherDisplay.savePrefValue(1, for: .brightness)
      }
    }
  }

  func restoreSwBrightnessForAllDisplays(async: Bool = false) {
    for otherDisplay in self.getOtherDisplays() {
      if (otherDisplay.readPrefValue(for: .brightness) == 0 && !prefs.bool(forKey: PrefKey.disableCombinedBrightness.rawValue)) || (otherDisplay.readPrefValue(for: .brightness) < 0.5 && !prefs.bool(forKey: PrefKey.separateCombinedScale.rawValue) && !prefs.bool(forKey: PrefKey.disableCombinedBrightness.rawValue)) || otherDisplay.isSw() {
        let savedPrefValue = otherDisplay.swBrightness
        if otherDisplay.getSwBrightness() != savedPrefValue {
          OSDUtils.popEmptyOsd(displayID: otherDisplay.identifier, command: Command.brightness) // This will give the user a hint why is the brightness suddenly changes and also give screen activity to counter the 'no gamma change when there is no screen activity' issue on some macs
        }
        otherDisplay.swBrightness = otherDisplay.getSwBrightness()
        _ = otherDisplay.setSwBrightness(savedPrefValue, smooth: async)
        if otherDisplay.isSw() {
          DisplayManager.setBrightnessSliderValue(otherDisplay: otherDisplay, value: savedPrefValue)
        }
      } else {
        _ = otherDisplay.setSwBrightness(1)
      }
    }
  }

  func getAffectedDisplays(isBrightness: Bool = false, isVolume: Bool = false) -> [Display]? {
    var affectedDisplays: [Display]
    let allDisplays = self.getAllDisplays()
    var currentDisplay: Display?
    if isBrightness {
      if prefs.bool(forKey: PrefKey.allScreensBrightness.rawValue) {
        affectedDisplays = allDisplays
        return affectedDisplays
      }
      currentDisplay = self.getCurrentDisplay(byFocus: prefs.bool(forKey: PrefKey.useFocusInsteadOfMouse.rawValue))
    }
    if isVolume {
      if prefs.bool(forKey: PrefKey.allScreensVolume.rawValue) {
        affectedDisplays = allDisplays
        return affectedDisplays
      } else if prefs.bool(forKey: PrefKey.useAudioDeviceNameMatching.rawValue) {
        return self.audioControlTargetDisplays
      }
      currentDisplay = self.getCurrentDisplay(byFocus: false)
    }
    if let currentDisplay = currentDisplay {
      affectedDisplays = [currentDisplay]
      if CGDisplayIsInHWMirrorSet(currentDisplay.identifier) != 0 || CGDisplayIsInMirrorSet(currentDisplay.identifier) != 0, CGDisplayMirrorsDisplay(currentDisplay.identifier) == 0 {
        for display in allDisplays where CGDisplayMirrorsDisplay(display.identifier) == currentDisplay.identifier {
          affectedDisplays.append(display)
        }
      }
    } else {
      affectedDisplays = []
    }
    return affectedDisplays
  }

  static func engageMirror() -> Bool {
    var onlineDisplayIDs = [CGDirectDisplayID](repeating: 0, count: 16)
    var displayCount: UInt32 = 0
    guard CGGetOnlineDisplayList(16, &onlineDisplayIDs, &displayCount) == .success, displayCount > 1 else {
      return false
    }
    // Break display mirror if there is any
    var mirrorBreak = false
    var displayConfigRef: CGDisplayConfigRef?
    for onlineDisplayID in onlineDisplayIDs where onlineDisplayID != 0 {
      if CGDisplayIsInHWMirrorSet(onlineDisplayID) != 0 || CGDisplayIsInMirrorSet(onlineDisplayID) != 0 {
        if mirrorBreak == false {
          CGBeginDisplayConfiguration(&displayConfigRef)
        }
        CGConfigureDisplayMirrorOfDisplay(displayConfigRef, onlineDisplayID, kCGNullDirectDisplay)
        mirrorBreak = true
      }
    }
    if mirrorBreak {
      CGCompleteDisplayConfiguration(displayConfigRef, CGConfigureOption.permanently)
      return true
    }
    // Build display mirror
    var mainDisplayId = kCGNullDirectDisplay
    for onlineDisplayID in onlineDisplayIDs where onlineDisplayID != 0 {
      if CGDisplayIsBuiltin(onlineDisplayID) == 0, mainDisplayId == kCGNullDirectDisplay {
        mainDisplayId = onlineDisplayID
      }
    }
    guard mainDisplayId != kCGNullDirectDisplay else {
      return false
    }
    CGBeginDisplayConfiguration(&displayConfigRef)
    for onlineDisplayID in onlineDisplayIDs where onlineDisplayID != 0 && onlineDisplayID != mainDisplayId {
      CGConfigureDisplayMirrorOfDisplay(displayConfigRef, onlineDisplayID, mainDisplayId)
    }
    CGCompleteDisplayConfiguration(displayConfigRef, CGConfigureOption.permanently)
    return true
  }

  // Static functions (could be anywhere)

  static func setBrightnessSliderValue(otherDisplay: OtherDisplay, value: Float) {
    if let slider = otherDisplay.brightnessSliderHandler {
      slider.setValue(value)
    }
  }

  static func isAppleDisplay(displayID: CGDirectDisplayID) -> Bool {
    var brightness: Float = -1
    let ret = DisplayServicesGetBrightness(displayID, &brightness)
    // If brightness read appears to be successful using DisplayServices then it should be an Apple display
    if ret == 0, brightness >= 0 {
      return true
    }
    // If built-in display then it should be Apple (except for hackintosh notebooks...)
    if CGDisplayIsBuiltin(displayID) != 0 {
      return true
    }
    /*
     // If Vendor ID is Anpple, then it is probably an Apple display
     if CGDisplayVendorNumber(displayID) == 0x05AC {
       return true
     }
     // If the display has a known Apple name, then it might be an Apple display. I am not sure about this one though
     let rawName = self.getDisplayRawNameByID(displayID: displayID)
     if rawName.contains("LG UltraFine") || rawName.contains("Thunderbolt") || rawName.contains("Cinema") || rawName.contains("Color LCD") {
        return true
     }
     */
    return false
  }

  static func getDisplayRawNameByID(displayID: CGDirectDisplayID) -> String {
    let defaultName: String = ""
    if #available(macOS 11.0, *) {
      if let dictionary = ((CoreDisplay_DisplayCreateInfoDictionary(displayID))?.takeRetainedValue() as NSDictionary?), let nameList = dictionary["DisplayProductName"] as? [String: String], let name = nameList["en_US"] ?? nameList.first?.value {
        return name
      }
    }
    if let screen = NSScreen.getByDisplayID(displayID: displayID) {
      return screen.displayName ?? defaultName
    }
    return defaultName
  }

  static func getDisplayNameByID(displayID: CGDirectDisplayID) -> String {
    let defaultName: String = NSLocalizedString("Unknown", comment: "Unknown display name")
    if #available(macOS 11.0, *) {
      if let dictionary = ((CoreDisplay_DisplayCreateInfoDictionary(displayID))?.takeRetainedValue() as NSDictionary?), let nameList = dictionary["DisplayProductName"] as? [String: String], var name = nameList[Locale.current.identifier] ?? nameList["en_US"] ?? nameList.first?.value {
        if CGDisplayIsInHWMirrorSet(displayID) != 0 || CGDisplayIsInMirrorSet(displayID) != 0 {
          let mirroredDisplayID = CGDisplayMirrorsDisplay(displayID)
          if mirroredDisplayID != 0, let dictionary = ((CoreDisplay_DisplayCreateInfoDictionary(mirroredDisplayID))?.takeRetainedValue() as NSDictionary?), let nameList = dictionary["DisplayProductName"] as? [String: String], let mirroredName = nameList[Locale.current.identifier] ?? nameList["en_US"] ?? nameList.first?.value {
            name.append("~" + mirroredName)
          }
        }
        return name
      }
    }
    if let screen = NSScreen.getByDisplayID(displayID: displayID) {
      if #available(OSX 10.15, *) {
        return screen.localizedName
      } else {
        return screen.displayName ?? defaultName
      }
    }
    return defaultName
  }
}
