//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import AVFoundation
import Cocoa
import IOKit
import os.log

class OtherDisplay: Display {
  var volumeSliderHandler: SliderHandler?
  var contrastSliderHandler: SliderHandler?
  var ddc: IntelDDC?
  var arm64ddc: Bool = false
  var arm64avService: IOAVService?
  var isDiscouraged: Bool = false
  let DDC_MAX_DETECT_LIMIT: Int = 100
  private var audioPlayer: AVAudioPlayer?

  var pollingMode: Int {
    get { return Int(prefs.string(forKey: PKey.pollingMode.rawValue + self.prefsId) ?? String(PollingMode.normal.rawValue)) ?? PollingMode.normal.rawValue }
    set { prefs.set(String(newValue), forKey: PKey.pollingMode.rawValue + self.prefsId) }
  }

  var pollingCount: Int {
    get {
      switch self.pollingMode {
      case PollingMode.none.rawValue: return 0
      case PollingMode.minimal.rawValue: return 5
      case PollingMode.normal.rawValue: return 10
      case PollingMode.heavy.rawValue: return 100
      case PollingMode.custom.rawValue: return prefs.integer(forKey: PKey.pollingCount.rawValue + self.prefsId)
      default: return PollingMode.none.rawValue
      }
    }
    set { prefs.set(newValue, forKey: PKey.pollingCount.rawValue + self.prefsId) }
  }

  var audioDeviceNameOverride: String {
    get { return prefs.string(forKey: PKey.audioDeviceNameOverride.rawValue + self.prefsId) ?? "" }
    set { prefs.set(newValue, forKey: PKey.audioDeviceNameOverride.rawValue + self.prefsId) }
  }

  override init(_ identifier: CGDirectDisplayID, name: String, vendorNumber: UInt32?, modelNumber: UInt32?, isVirtual: Bool = false) {
    super.init(identifier, name: name, vendorNumber: vendorNumber, modelNumber: modelNumber, isVirtual: isVirtual)
    if !isVirtual, !Arm64DDC.isArm64 {
      self.ddc = IntelDDC(for: identifier)
    }
  }

  func processCurrentDDCValue(read: Bool, command: Command, firstrun: Bool, currentDDCValue: UInt16) {
    if read {
      var currentValue = self.convDDCToValue(for: command, from: currentDDCValue)
      if !prefs.bool(forKey: PKey.disableCombinedBrightness.rawValue), command == .brightness {
        os_log("- Combined brightness mapping on DDC data.", type: .info)
        if currentValue > 0 {
          currentValue = 0.5 + currentValue / 2
        } else if currentValue == 0, firstrun {
          currentValue = 0.5
        } else if self.prefExists(for: command), self.readPrefAsFloat(for: command) <= 0.5 {
          currentValue = self.readPrefAsFloat(for: command)
        } else {
          currentValue = 0.5
        }
      }
      self.savePref(currentValue, for: command)
      if command == .brightness {
        self.smoothBrightnessTransient = currentValue
      }
    } else {
      var currentValue: Float = self.readPrefAsFloat(for: command)
      if !prefs.bool(forKey: PKey.disableCombinedBrightness.rawValue), command == .brightness {
        os_log("- Combined brightness mapping on saved data.", type: .info)
        if !self.prefExists(for: command) {
          currentValue = 0.5 + self.convDDCToValue(for: command, from: currentDDCValue) / 2
        } else if firstrun, currentValue < 0.5 {
          currentValue = 0.5
        }
      } else {
        currentValue = self.prefExists(for: command) ? self.readPrefAsFloat(for: command) : self.convDDCToValue(for: command, from: currentDDCValue)
      }
      self.savePref(currentValue, for: command)
      if command == .brightness {
        self.smoothBrightnessTransient = currentValue
      }
    }
  }

  func setupCurrentAndMaxValues(command: Command, firstrun: Bool = false) {
    var ddcValues: (UInt16, UInt16)?
    var maxDDCValue = UInt16(DDC_MAX_DETECT_LIMIT)
    var currentDDCValue = UInt16(Float(DDC_MAX_DETECT_LIMIT) * 0.75)
    if command == .audioSpeakerVolume {
      currentDDCValue = UInt16(Float(self.DDC_MAX_DETECT_LIMIT) * 0.125) // lower default audio value as high volume might rattle the user.
    }
    os_log("Setting up display %{public}@ for %{public}@", type: .info, String(self.identifier), String(reflecting: command))
    if !self.isSw() {
      if prefs.bool(forKey: PKey.enableDDCDuringStartup.rawValue), prefs.bool(forKey: PKey.readDDCInsteadOfRestoreValues.rawValue), self.pollingCount != 0, !(app.safeMode) {
        os_log("- Reading DDC from display %{public}@ times", type: .info, String(self.pollingCount))
        let delay = self.readPrefAsBool(key: .longerDelay) ? UInt64(40 * kMillisecondScale) : nil
        ddcValues = self.readDDCValues(for: command, tries: UInt(self.pollingCount), minReplyDelay: delay)
        if ddcValues != nil {
          (currentDDCValue, maxDDCValue) = ddcValues ?? (currentDDCValue, maxDDCValue)
          self.processCurrentDDCValue(read: true, command: command, firstrun: firstrun, currentDDCValue: currentDDCValue)
          os_log("- DDC read successful.", type: .info)
        } else {
          os_log("- DDC read failed.", type: .info)
        }
      } else {
        os_log("- DDC read disabled.", type: .info)
      }
      if self.readPrefAsInt(key: .maxDDCOverride, for: command) > self.readPrefAsInt(key: .minDDCOverride, for: command) {
        self.savePref(self.readPrefAsInt(key: .maxDDCOverride, for: command), key: .maxDDC, for: command)
      } else {
        self.savePref(min(Int(maxDDCValue), self.DDC_MAX_DETECT_LIMIT), key: .maxDDC, for: command)
      }
      if ddcValues == nil {
        self.processCurrentDDCValue(read: false, command: command, firstrun: firstrun, currentDDCValue: currentDDCValue)
        currentDDCValue = self.convValueToDDC(for: command, from: (!prefs.bool(forKey: PKey.disableCombinedBrightness.rawValue) && command == .brightness) ? max(0, self.readPrefAsFloat(for: command) - 0.5) * 2 : self.readPrefAsFloat(for: command))
      }
      os_log("- Current DDC value: %{public}@", type: .info, String(currentDDCValue))
      os_log("- Minimum DDC value: %{public}@ (overrides 0)", type: .info, String(self.readPrefAsInt(key: .minDDCOverride, for: command)))
      os_log("- Maximum DDC value: %{public}@ (overrides %{public}@)", type: .info, String(self.readPrefAsInt(key: .maxDDC, for: command)), String(maxDDCValue))
      os_log("- Current internal value: %{public}@", type: .info, String(self.readPrefAsFloat(for: command)))
      if prefs.bool(forKey: PKey.enableDDCDuringStartup.rawValue), !prefs.bool(forKey: PKey.readDDCInsteadOfRestoreValues.rawValue), !(app.safeMode) {
        os_log("- Writing last saved DDC values.", type: .info, self.name, String(reflecting: command))
        _ = self.writeDDCValues(command: command, value: currentDDCValue)
      }
    } else {
      self.savePref(max(0.1, self.prefExists(for: command) ? self.readPrefAsFloat(for: command) : Float(1)), for: command)
      self.savePref(self.readPrefAsFloat(for: command), key: .SwBrightness)
      self.brightnessSyncSourceValue = self.readPrefAsFloat(for: command)
      self.smoothBrightnessTransient = self.readPrefAsFloat(for: command)
      os_log("- Software controlled display current internal value: %{public}@", type: .info, String(self.readPrefAsFloat(for: command)))
    }
    if command == .audioSpeakerVolume {
      self.setupMuteUnMute()
    }
  }

  func setupMuteUnMute() {
    guard !self.readPrefAsBool(key: .unavailableDDC, for: .audioSpeakerVolume) else {
      return
    }
    var currentMuteValue = self.readPrefAsInt(for: .audioMuteScreenBlank)
    currentMuteValue = currentMuteValue == 0 ? 2 : currentMuteValue
    var muteValues: (current: UInt16, max: UInt16)?
    if self.readPrefAsBool(key: .enableMuteUnmute) {
      if self.pollingCount != 0, !app.safeMode, prefs.bool(forKey: PKey.enableDDCDuringStartup.rawValue), prefs.bool(forKey: PKey.readDDCInsteadOfRestoreValues.rawValue) {
        os_log("Reading DDC from display %{public}@ times for Mute", type: .info, String(self.pollingCount))
        let delay = self.readPrefAsBool(key: .longerDelay) ? UInt64(40 * kMillisecondScale) : nil
        muteValues = self.readDDCValues(for: .audioMuteScreenBlank, tries: UInt(self.pollingCount), minReplyDelay: delay)
        if let muteValues = muteValues {
          os_log("Success, current Mute setting: %{public}@", type: .info, String(muteValues.current))
          currentMuteValue = Int(muteValues.current)
        } else {
          os_log("Mute read failed", type: .info)
        }
      }
      if prefs.bool(forKey: PKey.enableDDCDuringStartup.rawValue), !prefs.bool(forKey: PKey.readDDCInsteadOfRestoreValues.rawValue), !(app.safeMode) {
        os_log("Writing last saved DDC value for Mute: %{public}@", type: .info, String(currentMuteValue))
        _ = self.writeDDCValues(command: .audioMuteScreenBlank, value: UInt16(currentMuteValue))
      }
      self.savePref(Int(currentMuteValue), for: .audioMuteScreenBlank)
    }
  }

  func setupSliderCurrentValue(command: Command) -> Float {
    let currentValue = self.readPrefAsFloat(for: command)
    var returnValue = currentValue
    if command == .audioSpeakerVolume, self.readPrefAsBool(key: .enableMuteUnmute) {
      if self.readPrefAsInt(for: .audioMuteScreenBlank) == 1 {
        returnValue = 0
      }
    }
    return returnValue
  }

  func stepVolume(isUp: Bool, isSmallIncrement: Bool) {
    guard !self.readPrefAsBool(key: .unavailableDDC, for: .audioSpeakerVolume) else {
      OSDUtils.showOsdVolumeDisabled(displayID: self.identifier)
      return
    }
    let currentValue = self.readPrefAsFloat(for: .audioSpeakerVolume)
    var muteValue: Int?
    let volumeOSDValue = self.calcNewValue(currentValue: currentValue, isUp: isUp, isSmallIncrement: isSmallIncrement)
    if self.readPrefAsInt(for: .audioMuteScreenBlank) == 1, volumeOSDValue > 0 {
      muteValue = 2
    } else if self.readPrefAsInt(for: .audioMuteScreenBlank) != 1, volumeOSDValue == 0 {
      muteValue = 1
    }
    let isAlreadySet = volumeOSDValue == self.readPrefAsFloat(for: .audioSpeakerVolume)
    if !isAlreadySet {
      if let muteValue = muteValue, self.readPrefAsBool(key: .enableMuteUnmute) {
        guard self.writeDDCValues(command: .audioMuteScreenBlank, value: UInt16(muteValue)) == true else {
          return
        }
        self.savePref(muteValue, for: .audioMuteScreenBlank)
      }
      if !self.readPrefAsBool(key: .enableMuteUnmute) || volumeOSDValue != 0 {
        _ = self.writeDDCValues(command: .audioSpeakerVolume, value: self.convValueToDDC(for: .audioSpeakerVolume, from: volumeOSDValue))
      }
    }
    if !self.readPrefAsBool(key: .hideOsd) {
      OSDUtils.showOsd(displayID: self.identifier, command: .audioSpeakerVolume, value: volumeOSDValue, roundChiclet: !isSmallIncrement)
    }
    if !isAlreadySet {
      self.savePref(volumeOSDValue, for: .audioSpeakerVolume)
      if let slider = self.volumeSliderHandler {
        slider.setValue(volumeOSDValue, displayID: self.identifier)
      }
    }
  }

  func toggleMute(fromVolumeSlider: Bool = false) {
    guard !self.readPrefAsBool(key: .unavailableDDC, for: .audioSpeakerVolume) else {
      OSDUtils.showOsdMuteDisabled(displayID: self.identifier)
      return
    }
    var muteValue: Int
    var volumeOSDValue: Float
    if self.readPrefAsInt(for: .audioMuteScreenBlank) != 1 {
      muteValue = 1
      volumeOSDValue = 0
    } else {
      muteValue = 2
      volumeOSDValue = self.readPrefAsFloat(for: .audioSpeakerVolume)
      // The volume that will be set immediately after setting unmute while the old set volume was 0 is unpredictable. Hence, just set it to a single filled chiclet
      if volumeOSDValue == 0 {
        volumeOSDValue = 1 / OSDUtils.chicletCount
        self.savePref(volumeOSDValue, for: .audioSpeakerVolume)
      }
    }
    if self.readPrefAsBool(key: .enableMuteUnmute) {
      guard self.writeDDCValues(command: .audioMuteScreenBlank, value: UInt16(muteValue)) == true else {
        return
      }
    }
    self.savePref(muteValue, for: .audioMuteScreenBlank)
    if !self.readPrefAsBool(key: .enableMuteUnmute) || volumeOSDValue > 0 {
      _ = self.writeDDCValues(command: .audioSpeakerVolume, value: self.convValueToDDC(for: .audioSpeakerVolume, from: volumeOSDValue))
    }
    if !fromVolumeSlider {
      if !self.readPrefAsBool(key: .hideOsd) {
        OSDUtils.showOsd(displayID: self.identifier, command: volumeOSDValue > 0 ? .audioSpeakerVolume : .audioMuteScreenBlank, value: volumeOSDValue, roundChiclet: true)
      }
      if let slider = self.volumeSliderHandler {
        slider.setValue(volumeOSDValue)
      }
    }
  }

  func isSwOnly() -> Bool {
    return (!self.arm64ddc && self.ddc == nil) || self.isVirtual
  }

  func isSw() -> Bool {
    if prefs.bool(forKey: PKey.forceSw.rawValue + self.prefsId) || self.isSwOnly() {
      return true
    } else {
      return false
    }
  }

  let swAfterOsdAnimationSemaphore = DispatchSemaphore(value: 1)
  var lastAnimationStartedTime: CFTimeInterval = CACurrentMediaTime()
  func doSwAfterOsdAnimation() {
    self.lastAnimationStartedTime = CACurrentMediaTime()
    DispatchQueue.global(qos: .userInteractive).async {
      self.swAfterOsdAnimationSemaphore.wait()
      guard CACurrentMediaTime() < self.lastAnimationStartedTime + 0.05 else {
        self.swAfterOsdAnimationSemaphore.signal()
        return
      }
      for value: Int in stride(from: 1, to: 6, by: 1) {
        guard self.readPrefAsFloat(for: .brightness) <= 0.5 else {
          self.swAfterOsdAnimationSemaphore.signal()
          return
        }
        OSDUtils.showOsd(displayID: self.identifier, command: .brightness, value: Float(value), maxValue: 100, roundChiclet: false)
        Thread.sleep(forTimeInterval: Double(value * 2) / 300)
      }
      for value: Int in stride(from: 5, to: 0, by: -1) {
        guard self.readPrefAsFloat(for: .brightness) <= 0.5 else {
          self.swAfterOsdAnimationSemaphore.signal()
          return
        }
        OSDUtils.showOsd(displayID: self.identifier, command: .brightness, value: Float(value), maxValue: 100, roundChiclet: false)
        Thread.sleep(forTimeInterval: Double(value * 2) / 300)
      }
      OSDUtils.showOsd(displayID: self.identifier, command: .brightness, value: 0, roundChiclet: true)
      self.swAfterOsdAnimationSemaphore.signal()
    }
  }

  override func stepBrightness(isUp: Bool, isSmallIncrement: Bool) {
    if self.isSw() {
      if !prefs.bool(forKey: PKey.disableSoftwareFallback.rawValue) {
        super.stepBrightness(isUp: isUp, isSmallIncrement: isSmallIncrement)
      }
      return
    }
    guard !self.readPrefAsBool(key: .unavailableDDC, for: .brightness) else {
      return
    }
    let currentValue = self.readPrefAsFloat(for: .brightness)
    var osdValue: Float = 1
    if !prefs.bool(forKey: PKey.disableCombinedBrightness.rawValue), prefs.bool(forKey: PKey.separateCombinedScale.rawValue) {
      osdValue = self.calcNewValue(currentValue: currentValue, isUp: isUp, isSmallIncrement: isSmallIncrement, half: true)
      _ = self.setBrightness(osdValue)
      if osdValue > 0.5 {
        OSDUtils.showOsd(displayID: self.identifier, command: .brightness, value: osdValue - 0.5, maxValue: 0.5, roundChiclet: !isSmallIncrement)
      } else {
        self.doSwAfterOsdAnimation()
      }
    } else {
      osdValue = self.calcNewValue(currentValue: currentValue, isUp: isUp, isSmallIncrement: isSmallIncrement)
      _ = self.setBrightness(osdValue)
      OSDUtils.showOsd(displayID: self.identifier, command: .brightness, value: osdValue, roundChiclet: !isSmallIncrement)
    }
    if let slider = brightnessSliderHandler {
      slider.setValue(osdValue, displayID: self.identifier)
      self.brightnessSyncSourceValue = osdValue
    }
  }

  override func setDirectBrightness(_ to: Float, transient: Bool = false) -> Bool {
    let value = max(min(to, 1), 0)
    if !self.isSw() {
      if !prefs.bool(forKey: PKey.disableCombinedBrightness.rawValue) {
        var brightnessValue: Float = 0
        var brightnessSwValue: Float = 1
        if value >= 0.5 {
          brightnessValue = (value - 0.5) * 2
          brightnessSwValue = 1
        } else {
          brightnessValue = 0
          brightnessSwValue = (value / 0.5)
        }
        _ = self.writeDDCValues(command: .brightness, value: self.convValueToDDC(for: .brightness, from: brightnessValue))
        _ = self.setSwBrightness(brightnessSwValue)
      } else {
        _ = self.writeDDCValues(command: .brightness, value: self.convValueToDDC(for: .brightness, from: value))
      }
      if !transient {
        self.savePref(value, for: .brightness)
        self.smoothBrightnessTransient = value
      }
    } else {
      _ = super.setDirectBrightness(to, transient: transient)
    }
    return true
  }

  override func getBrightness() -> Float {
    return self.prefExists(for: .brightness) ? self.readPrefAsFloat(for: .brightness) : 1
  }

  public func writeDDCValues(command: Command, value: UInt16, errorRecoveryWaitTime _: UInt32? = nil) -> Bool? {
    guard app.sleepID == 0, app.reconfigureID == 0, !self.readPrefAsBool(key: .forceSw), !self.readPrefAsBool(key: .unavailableDDC, for: command) else {
      return false
    }
    var success: Bool = false
    var controlCode = UInt8(self.readPrefAsInt(key: .remapDDC, for: command))
    if controlCode == 0 {
      controlCode = command.rawValue
    }
    DisplayManager.shared.ddcQueue.sync {
      if Arm64DDC.isArm64 {
        if self.arm64ddc {
          success = Arm64DDC.write(service: self.arm64avService, command: controlCode, value: value)
        }
      } else {
        success = self.ddc?.write(command: command.rawValue, value: value, errorRecoveryWaitTime: 2000) ?? false
      }
    }
    return success
  }

  func readDDCValues(for command: Command, tries: UInt, minReplyDelay delay: UInt64?) -> (current: UInt16, max: UInt16)? {
    var values: (UInt16, UInt16)?
    guard app.sleepID == 0, app.reconfigureID == 0, !self.readPrefAsBool(key: .forceSw), !self.readPrefAsBool(key: .unavailableDDC, for: command) else {
      return values
    }
    var controlCode = UInt8(self.readPrefAsInt(key: .remapDDC, for: command))
    if controlCode == 0 {
      controlCode = command.rawValue
    }
    if Arm64DDC.isArm64 {
      guard self.arm64ddc else {
        return nil
      }
      DisplayManager.shared.ddcQueue.sync {
        if let unwrappedDelay = delay {
          values = Arm64DDC.read(service: self.arm64avService, command: command.rawValue, tries: UInt8(min(tries, 255)), minReplyDelay: UInt32(unwrappedDelay / 1000))
        } else {
          values = Arm64DDC.read(service: self.arm64avService, command: command.rawValue, tries: UInt8(min(tries, 255)))
        }
      }
    } else {
      DisplayManager.shared.ddcQueue.sync {
        values = self.ddc?.read(command: command.rawValue, tries: tries, minReplyDelay: delay)
      }
    }
    return values
  }

  func calcNewValue(currentValue: Float, isUp: Bool, isSmallIncrement: Bool, half: Bool = false) -> Float {
    let nextValue: Float
    if isSmallIncrement {
      nextValue = currentValue + (isUp ? 0.01 : -0.01)
    } else {
      let osdChicletFromValue = OSDUtils.chiclet(fromValue: currentValue, maxValue: 1, half: half)
      let distance = OSDUtils.getDistance(fromNearestChiclet: osdChicletFromValue)
      var nextFilledChiclet = isUp ? ceil(osdChicletFromValue) : floor(osdChicletFromValue)
      let distanceThreshold: Float = 0.25 // 25% of the distance between the edges of an osd box
      if distance == 0 {
        nextFilledChiclet += (isUp ? 1 : -1)
      } else if !isUp, distance < distanceThreshold {
        nextFilledChiclet -= 1
      } else if isUp, distance > (1 - distanceThreshold) {
        nextFilledChiclet += 1
      }
      nextValue = OSDUtils.value(fromChiclet: nextFilledChiclet, maxValue: 1, half: half)
    }
    return max(0, min(1, nextValue))
  }

  func getCurveMultiplier(_ curveDDC: Int) -> Float {
    switch curveDDC {
    case 1: return 0.6
    case 2: return 0.7
    case 3: return 0.8
    case 4: return 0.9
    case 6: return 1.3
    case 7: return 1.5
    case 8: return 1.7
    case 9: return 1.88
    default: return 1.0
    }
  }

  func convValueToDDC(for command: Command, from: Float) -> UInt16 {
    var value = from
    if self.readPrefAsBool(key: .invertDDC, for: command) {
      value = 1 - value
    }
    let curveMultiplier = self.getCurveMultiplier(self.readPrefAsInt(key: .curveDDC, for: command))
    let minDDCValue = Float(self.readPrefAsInt(key: .minDDCOverride, for: command))
    let maxDDCValue = Float(self.readPrefAsInt(key: .maxDDC, for: command))
    let curvedValue = pow(max(min(value, 1), 0), curveMultiplier)
    let deNormalizedValue = (maxDDCValue - minDDCValue) * curvedValue + minDDCValue
    var intDDCValue = UInt16(min(max(deNormalizedValue, minDDCValue), maxDDCValue))
    if from > 0, command == Command.audioSpeakerVolume {
      intDDCValue = max(1, intDDCValue) // Never let sound to mute accidentally, keep it digitally to at digital 1 if needed as muting breaks some displays
    }
    return intDDCValue
  }

  func convDDCToValue(for command: Command, from: UInt16) -> Float {
    let curveMultiplier = self.getCurveMultiplier(self.readPrefAsInt(key: .curveDDC, for: command))
    let minDDCValue = Float(self.readPrefAsInt(key: .minDDCOverride, for: command))
    let maxDDCValue = Float(self.readPrefAsInt(key: .maxDDC, for: command))
    let normalizedValue = ((min(max(Float(from), minDDCValue), maxDDCValue) - minDDCValue) / (maxDDCValue - minDDCValue))
    let deCurvedValue = pow(normalizedValue, 1.0 / curveMultiplier)
    var value = deCurvedValue
    if self.readPrefAsBool(key: .invertDDC, for: command) {
      value = 1 - value
    }
    return max(min(value, 1), 0)
  }

  func playVolumeChangedSound() {
    // Check if user has enabled "Play feedback when volume is changed" in Sound Preferences
    guard let preferences = app.getSystemPreferences(), let hasSoundEnabled = preferences["com.apple.sound.beep.feedback"] as? Int, hasSoundEnabled == 1 else {
      return
    }
    do {
      self.audioPlayer = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: "/System/Library/LoginPlugins/BezelServices.loginPlugin/Contents/Resources/volume.aiff"))
      self.audioPlayer?.volume = 1
      self.audioPlayer?.play()
    } catch {
      os_log("%{public}@", type: .error, error.localizedDescription)
    }
  }
}
