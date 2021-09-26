//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Cocoa
import CoreGraphics
import os.log

let DEBUG_GAMMA_ENFORCER = false

class DisplayManager {
  public static let shared = DisplayManager()

  var displays: [Display] = []
  var audioControlTargetDisplays: [OtherDisplay] = []
  let ddcQueue = DispatchQueue(label: "DDC queue")

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
    if let screen = DisplayManager.getByDisplayID(displayID: resolveEffectiveDisplayID(displayID)) {
      self.gammaActivityEnforcer.setFrameOrigin(screen.frame.origin)
    }
    self.gammaActivityEnforcer.orderFrontRegardless()
  }

  internal var shades: [CGDirectDisplayID: NSWindow] = [:]
  internal var shadeGrave: [NSWindow] = []

  func isDisqualifiedFromShade(_ displayID: CGDirectDisplayID) -> Bool { // We ban mirror members from shade control as it might lead to double control
    return (CGDisplayIsInHWMirrorSet(displayID) != 0 || CGDisplayIsInMirrorSet(displayID) != 0) ? true : false
  }

  internal func createShadeOnDisplay(displayID: CGDirectDisplayID) -> NSWindow? {
    if let screen = DisplayManager.getByDisplayID(displayID: displayID) {
      let shade = NSWindow(contentRect: .init(origin: NSPoint(x: 0, y: 0), size: .init(width: 10, height: 1)), styleMask: [], backing: .buffered, defer: false)
      shade.title = "Monitor Control Window Shade for Display " + String(displayID)
      shade.isMovableByWindowBackground = false
      shade.backgroundColor = .black
      shade.ignoresMouseEvents = true
      shade.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
      shade.alphaValue = 0
      shade.orderFrontRegardless()
      shade.collectionBehavior = [.stationary, .canJoinAllSpaces, .ignoresCycle]
      shade.setFrame(screen.frame, display: true)
      os_log("Window shade created for display %{public}@", type: .debug, String(displayID))
      return shade
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

  func destroyAllShades() -> Bool {
    var ret = false
    for displayID in shades.keys {
      os_log("Attempting to destory shade for display  %{public}@", type: .debug, String(displayID))
      if destroyShade(displayID: displayID) {
        ret = true
      }
    }
    if ret {
      os_log("Destroyed all shades.", type: .debug)
    } else {
      os_log("No shades were found to be destroyed.", type: .debug)
    }
    return ret
  }

  func destroyShade(displayID: CGDirectDisplayID) -> Bool {
    if let shade = shades[displayID] {
      os_log("Destroying shade for display %{public}@", type: .debug, String(displayID))
      shadeGrave.append(shade)
      self.shades.removeValue(forKey: displayID)
      shade.close()
      return true
    }
    return false
  }

  func updateShade(displayID: CGDirectDisplayID) -> Bool {
    guard !self.isDisqualifiedFromShade(displayID) else {
      return false
    }
    if let screen = DisplayManager.getByDisplayID(displayID: displayID) {
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

  func configureDisplays() {
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
      var isVirtual: Bool = false
      if !DEBUG_MACOS10, #available(macOS 11.0, *) {
        if let dictionary = ((CoreDisplay_DisplayCreateInfoDictionary(onlineDisplayID))?.takeRetainedValue() as NSDictionary?) {
          let isVirtualDevice = dictionary["kCGDisplayIsVirtualDevice"] as? Bool
          let displayIsAirplay = dictionary["kCGDisplayIsAirPlay"] as? Bool
          if isVirtualDevice ?? displayIsAirplay ?? false {
            isVirtual = true
          }
        }
      }
      if !DEBUG_SW, DisplayManager.isAppleDisplay(displayID: onlineDisplayID) { // MARK: (point of interest for testing)
        let appleDisplay = AppleDisplay(id, name: name, vendorNumber: vendorNumber, modelNumber: modelNumber, isVirtual: isVirtual)
        os_log("Apple display found - %{public}@", type: .info, "ID: \(appleDisplay.identifier) Name: \(appleDisplay.name) (Vendor: \(appleDisplay.vendorNumber ?? 0), Model: \(appleDisplay.modelNumber ?? 0))")
        self.addDisplay(display: appleDisplay)
      } else {
        let otherDisplay = OtherDisplay(id, name: name, vendorNumber: vendorNumber, modelNumber: modelNumber, isVirtual: isVirtual)
        os_log("Other display found - %{public}@", type: .info, "ID: \(otherDisplay.identifier) Name: \(otherDisplay.name) (Vendor: \(otherDisplay.vendorNumber ?? 0), Model: \(otherDisplay.modelNumber ?? 0))")
        self.addDisplay(display: otherDisplay)
      }
    }
  }

  func setupOtherDisplays(firstrun: Bool = false) {
    for otherDisplay in self.getOtherDisplays() {
      if !otherDisplay.isSw(), !otherDisplay.readPrefAsBool(key: .unavailableDDC, for: .audioSpeakerVolume) {
        otherDisplay.setupCurrentAndMaxValues(command: .audioSpeakerVolume, firstrun: firstrun)
      }
      if !otherDisplay.isSw(), !otherDisplay.readPrefAsBool(key: .unavailableDDC, for: .contrast) {
        otherDisplay.setupCurrentAndMaxValues(command: .contrast, firstrun: firstrun)
      }
      if (!otherDisplay.isSw() && !otherDisplay.readPrefAsBool(key: .unavailableDDC, for: .brightness)) || otherDisplay.isSw() {
        otherDisplay.setupCurrentAndMaxValues(command: .brightness, firstrun: firstrun)
        otherDisplay.brightnessSyncSourceValue = otherDisplay.readPrefAsFloat(for: .brightness)
      }
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
      var displayAudioDeviceName = ddcCapableDisplay.readPrefAsString(key: .audioDeviceNameOverride)
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
        otherDisplay.savePref(1, key: .SwBrightness)
        otherDisplay.smoothBrightnessTransient = 1
      }
      if otherDisplay.isSw() {
        otherDisplay.savePref(1, for: .brightness)
      }
    }
  }

  func restoreSwBrightnessForAllDisplays(async: Bool = false) {
    for otherDisplay in self.getOtherDisplays() {
      if (otherDisplay.readPrefAsFloat(for: .brightness) == 0 && !prefs.bool(forKey: PKey.disableCombinedBrightness.rawValue)) || (otherDisplay.readPrefAsFloat(for: .brightness) < 0.5 && !prefs.bool(forKey: PKey.separateCombinedScale.rawValue) && !prefs.bool(forKey: PKey.disableCombinedBrightness.rawValue)) || otherDisplay.isSw() {
        let savedPrefValue = otherDisplay.readPrefAsFloat(key: .SwBrightness)
        if otherDisplay.getSwBrightness() != savedPrefValue {
          OSDUtils.popEmptyOsd(displayID: otherDisplay.identifier, command: Command.brightness) // This will give the user a hint why is the brightness suddenly changes and also give screen activity to counter the 'no gamma change when there is no screen activity' issue on some macs
        }
        otherDisplay.savePref(otherDisplay.getSwBrightness(), key: .SwBrightness)
        os_log("Restoring sw brightness to %{public}@ on other display %{public}@", type: .debug, String(savedPrefValue), String(otherDisplay.identifier))
        _ = otherDisplay.setSwBrightness(savedPrefValue, smooth: async)
        if otherDisplay.isSw(), let slider = otherDisplay.brightnessSliderHandler {
          os_log("Restoring sw slider to %{public}@ for other display %{public}@", type: .debug, String(savedPrefValue), String(otherDisplay.identifier))
          slider.setValue(savedPrefValue, displayID: otherDisplay.identifier)
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
      if prefs.bool(forKey: PKey.allScreensBrightness.rawValue) {
        affectedDisplays = allDisplays
        return affectedDisplays
      }
      currentDisplay = self.getCurrentDisplay(byFocus: prefs.bool(forKey: PKey.useFocusInsteadOfMouse.rawValue))
    }
    if isVolume {
      if prefs.bool(forKey: PKey.allScreensVolume.rawValue) {
        affectedDisplays = allDisplays
        return affectedDisplays
      } else if prefs.bool(forKey: PKey.useAudioDeviceNameMatching.rawValue) {
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
     // If Vendor ID is Apple, then it is probably an Apple display
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

  static func getByDisplayID(displayID: CGDirectDisplayID) -> NSScreen? {
    return NSScreen.screens.first { $0.displayID == displayID }
  }

  static func getDisplayRawNameByID(displayID: CGDirectDisplayID) -> String {
    let defaultName: String = ""
    if !DEBUG_MACOS10, #available(macOS 11.0, *) {
      if let dictionary = ((CoreDisplay_DisplayCreateInfoDictionary(displayID))?.takeRetainedValue() as NSDictionary?), let nameList = dictionary["DisplayProductName"] as? [String: String], let name = nameList["en_US"] ?? nameList.first?.value {
        return name
      }
    }
    if let screen = getByDisplayID(displayID: displayID) {
      return screen.displayName ?? defaultName
    }
    return defaultName
  }

  static func getDisplayNameByID(displayID: CGDirectDisplayID) -> String {
    let defaultName: String = NSLocalizedString("Unknown", comment: "Unknown display name")
    if !DEBUG_MACOS10, #available(macOS 11.0, *) {
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
    if let screen = getByDisplayID(displayID: displayID) { // MARK: This, and NSScreen+Extension.swift will not be needed when we drop MacOS 10 support.
      return screen.localizedName
    }
    return defaultName
  }
}
