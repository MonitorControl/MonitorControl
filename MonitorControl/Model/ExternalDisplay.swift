import AVFoundation
import Cocoa
import IOKit
import os.log

class ExternalDisplay: Display {
  var volumeSliderHandler: SliderHandler?
  var contrastSliderHandler: SliderHandler?
  var ddc: IntelDDC?
  var arm64ddc: Bool = false
  var arm64avService: IOAVService?
  var isDiscouraged: Bool = false
  let DDC_MAX_DETECT_LIMIT: Int = 100
  private var audioPlayer: AVAudioPlayer?

  var enableMuteUnmute: Bool {
    get { return prefs.bool(forKey: PrefKey.enableMuteUnmute.rawValue + self.prefsId) }
    set { prefs.set(newValue, forKey: PrefKey.enableMuteUnmute.rawValue + self.prefsId) }
  }

  var hideOsd: Bool {
    get { return prefs.bool(forKey: PrefKey.hideOsd.rawValue + self.prefsId) }
    set { prefs.set(newValue, forKey: PrefKey.hideOsd.rawValue + self.prefsId) }
  }

  var needsLongerDelay: Bool {
    get { return prefs.object(forKey: PrefKey.longerDelay.rawValue + self.prefsId) as? Bool ?? false }
    set { prefs.set(newValue, forKey: PrefKey.longerDelay.rawValue + self.prefsId) }
  }

  var pollingMode: Int {
    get { return Int(prefs.string(forKey: PrefKey.pollingMode.rawValue + self.prefsId) ?? "2") ?? 2 }
    set { prefs.set(String(newValue), forKey: PrefKey.pollingMode.rawValue + self.prefsId) }
  }

  var pollingCount: Int {
    get {
      switch self.pollingMode {
      case 0: return Utils.PollingMode.none.value
      case 1: return Utils.PollingMode.minimal.value
      case 2: return Utils.PollingMode.normal.value
      case 3: return Utils.PollingMode.heavy.value
      case 4:
        let val = prefs.integer(forKey: PrefKey.pollingCount.rawValue + self.prefsId)
        return Utils.PollingMode.custom(value: val).value
      default: return 0
      }
    }
    set { prefs.set(newValue, forKey: PrefKey.pollingCount.rawValue + self.prefsId) }
  }

  override init(_ identifier: CGDirectDisplayID, name: String, vendorNumber: UInt32?, modelNumber: UInt32?, isVirtual: Bool = false) {
    super.init(identifier, name: name, vendorNumber: vendorNumber, modelNumber: modelNumber, isVirtual: isVirtual)
    if !isVirtual, !Arm64DDC.isArm64 {
      self.ddc = IntelDDC(for: identifier)
    }
  }

  func toggleMute(fromVolumeSlider: Bool = false) {
    var muteValue: Int
    var volumeOSDValue: Float
    if self.readPrefValueInt(for: .audioMuteScreenBlank) != 1 {
      muteValue = 1
      volumeOSDValue = 0
    } else {
      muteValue = 2
      volumeOSDValue = self.readPrefValue(for: .audioSpeakerVolume)
      // The volume that will be set immediately after setting unmute while the old set volume was 0 is unpredictable. Hence, just set it to a single filled chiclet
      if volumeOSDValue == 0 {
        volumeOSDValue = 1 / OSDUtils.chicletCount
        self.savePrefValue(volumeOSDValue, for: .audioSpeakerVolume)
      }
    }
    if self.enableMuteUnmute {
      guard self.writeDDCValues(command: .audioMuteScreenBlank, value: UInt16(muteValue)) == true else {
        return
      }
    }
    self.savePrefValueInt(muteValue, for: .audioMuteScreenBlank)
    if !self.enableMuteUnmute || volumeOSDValue > 0 {
      _ = self.writeDDCValues(command: .audioSpeakerVolume, value: self.convValueToDDC(for: .audioSpeakerVolume, from: volumeOSDValue))
    }
    if !fromVolumeSlider {
      if !self.hideOsd {
        self.showOsd(command: volumeOSDValue > 0 ? .audioSpeakerVolume : .audioMuteScreenBlank, value: volumeOSDValue, roundChiclet: true)
      }
      if let slider = self.volumeSliderHandler?.slider {
        slider.floatValue = volumeOSDValue
      }
    }
  }

  func setupCurrentAndMaxValues(command: Command) {
    var ddcValues: (UInt16, UInt16)?
    var maxDDCValue = UInt16(DDC_MAX_DETECT_LIMIT)
    var currentDDCValue = UInt16(Float(DDC_MAX_DETECT_LIMIT) * 0.75)
    var currentValue: Float = 1
    os_log("** Setting up %{public}@ for %{public}@ **", type: .info, self.name, String(reflecting: command))
    if self.isSw(), command == Command.brightness {
      os_log("Software control is used.", type: .info)
      currentValue = self.swBrightness
      os_log(" - current internal value: %{public}@", type: .info, String(currentValue))
    } else {
      let tries = UInt(self.pollingCount)
      if !prefs.bool(forKey: PrefKey.restoreLastSavedValues.rawValue), tries != 0, !(app.safeMode) {
        os_log("Reading DDC from display %{public}@ times", type: .info, String(tries))
        let delay = self.needsLongerDelay ? UInt64(40 * kMillisecondScale) : nil
        ddcValues = self.readDDCValues(for: command, tries: tries, minReplyDelay: delay)
        if ddcValues != nil {
          (currentDDCValue, maxDDCValue) = ddcValues ?? (currentDDCValue, maxDDCValue)
          self.savePrefValue(self.convDDCToValue(for: command, from: currentDDCValue), for: command)
          os_log("DDC read successful.", type: .info)
        } else {
          os_log("DDC read failed.", type: .info)
        }
      } else {
        os_log("DDC read disabled.", type: .info)
      }
      if ddcValues == nil {
        self.savePrefValue(self.prefValueExists(for: command) ? self.readPrefValue(for: command) : 0.75, for: command)
        currentDDCValue = self.convValueToDDC(for: command, from: self.readPrefValue(for: command))
      }
      if self.readPrefValueKeyInt(forkey: PrefKey.maxDDCOverride, for: command) > self.readPrefValueKeyInt(forkey: PrefKey.minDDCOverride, for: command) {
        self.savePrefValueKeyInt(forkey: PrefKey.maxDDC, value: self.readPrefValueKeyInt(forkey: PrefKey.maxDDCOverride, for: command), for: command)
      } else {
        self.savePrefValueKeyInt(forkey: PrefKey.maxDDC, value: min(Int(maxDDCValue), self.DDC_MAX_DETECT_LIMIT), for: command)
      }
      os_log(" - current DDC value: %{public}@", type: .info, String(currentDDCValue))
      os_log(" - minimum DDC value: %{public}@ (overrides 0)", type: .info, String(self.readPrefValueKeyInt(forkey: PrefKey.minDDCOverride, for: command)))
      os_log(" - maximum DDC value: %{public}@ (overrides %{public}@)", type: .info, String(self.readPrefValueKeyInt(forkey: PrefKey.maxDDC, for: command)), String(maxDDCValue))
      os_log(" - current internal value: %{public}@", type: .info, String(self.readPrefValue(for: command)))
      if prefs.bool(forKey: PrefKey.restoreLastSavedValues.rawValue) {
        os_log("Writing last saved DDC values.", type: .info, self.name, String(reflecting: command))
        _ = self.writeDDCValues(command: command, value: currentDDCValue)
      }
    }
  }

  func setupSliderCurrentValue(command: Command) -> Float {
    var returnValue: Float = 0.75
    let currentValue = self.readPrefValue(for: command)
    if command == .brightness {
      if !self.isSw(), prefs.bool(forKey: PrefKey.lowerSwAfterBrightness.rawValue) {
        returnValue = 0.5 + currentValue / 2
      } else {
        returnValue = currentValue
      }
    } else if command == .audioSpeakerVolume, !self.isSw() {
      // If we're looking at the audio speaker volume, also retrieve the values for the mute command
      var muteValues: (current: UInt16, max: UInt16)?
      let tries = UInt(self.pollingCount)
      if self.enableMuteUnmute, tries != 0, !app.safeMode, !prefs.bool(forKey: PrefKey.restoreLastSavedValues.rawValue) {
        os_log("Reading DDC from display %{public}@ times for mute", type: .info, String(tries))
        let delay = self.needsLongerDelay ? UInt64(40 * kMillisecondScale) : nil
        muteValues = self.readDDCValues(for: .audioMuteScreenBlank, tries: tries, minReplyDelay: delay)
        if let muteValues = muteValues {
          os_log(" - success, current DDC value: %{public}@", type: .info, String(muteValues.current))
          self.savePrefValueInt(Int(muteValues.current), for: .audioMuteScreenBlank)
        } else {
          os_log(" - read failed or disabled, skipping", type: .info)
        }
      }
      // If the system is not currently muted, or doesn't support the mute command, display the current volume as the slider value
      if muteValues == nil || muteValues!.current == 2 {
        returnValue = currentValue
      } else {
        returnValue = 0
      }
    } else {
      returnValue = currentValue
    }
    return returnValue
  }

  func stepVolume(isUp: Bool, isSmallIncrement: Bool) {
    let currentValue = self.readPrefValue(for: .audioSpeakerVolume)
    var muteValue: Int?
    let volumeOSDValue = self.calcNewValue(currentValue: currentValue, isUp: isUp, isSmallIncrement: isSmallIncrement)
    if self.readPrefValueInt(for: .audioMuteScreenBlank) == 1, volumeOSDValue > 0 {
      muteValue = 2
    } else if self.readPrefValueInt(for: .audioMuteScreenBlank) != 1, volumeOSDValue == 0 {
      muteValue = 1
    }
    let isAlreadySet = volumeOSDValue == self.readPrefValue(for: .audioSpeakerVolume)
    if !isAlreadySet {
      if let muteValue = muteValue, self.enableMuteUnmute {
        guard self.writeDDCValues(command: .audioMuteScreenBlank, value: UInt16(muteValue)) == true else {
          return
        }
        self.savePrefValueInt(muteValue, for: .audioMuteScreenBlank)
      }
      if !self.enableMuteUnmute || volumeOSDValue != 0 {
        _ = self.writeDDCValues(command: .audioSpeakerVolume, value: self.convValueToDDC(for: .audioSpeakerVolume, from: volumeOSDValue))
      }
    }
    if !self.hideOsd {
      self.showOsd(command: .audioSpeakerVolume, value: volumeOSDValue, roundChiclet: !isSmallIncrement)
    }
    if !isAlreadySet {
      self.savePrefValue(volumeOSDValue, for: .audioSpeakerVolume)
      if let slider = self.volumeSliderHandler?.slider {
        slider.floatValue = volumeOSDValue
      }
    }
  }

  func isSwOnly() -> Bool {
    return (!self.arm64ddc && self.ddc == nil && !self.isVirtual)
  }

  func isSw() -> Bool {
    if prefs.bool(forKey: PrefKey.forceSw.rawValue + self.prefsId) || self.isSwOnly() {
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
        guard self.readPrefValue(for: .brightness) == 0 else {
          self.swAfterOsdAnimationSemaphore.signal()
          return
        }
        self.showOsd(command: .brightness, value: Float(value), maxValue: 100, roundChiclet: false)
        Thread.sleep(forTimeInterval: Double(value * 2) / 300)
      }
      for value: Int in stride(from: 5, to: 0, by: -1) {
        guard self.readPrefValue(for: .brightness) == 0 else {
          self.swAfterOsdAnimationSemaphore.signal()
          return
        }
        self.showOsd(command: .brightness, value: Float(value), maxValue: 100, roundChiclet: false)
        Thread.sleep(forTimeInterval: Double(value * 2) / 300)
      }
      self.showOsd(command: .brightness, value: 0, roundChiclet: true)
      self.swAfterOsdAnimationSemaphore.signal()
    }
  }

  func stepBrightnessPart(osdValue: Float, isSmallIncrement: Bool) -> Bool {
    if self.isSw(), prefs.bool(forKey: PrefKey.fallbackSw.rawValue) {
      if self.setSwBrightness(value: osdValue, smooth: true) {
        self.showOsd(command: .brightness, value: osdValue, maxValue: 1, roundChiclet: !isSmallIncrement)
        self.savePrefValue(osdValue, for: .brightness)
        if let slider = brightnessSliderHandler?.slider {
          slider.floatValue = osdValue
        }
      }
      return true
    }
    return false
  }

  func stepBrightnessswAfterBirghtnessMode(osdValue: Float, isUp: Bool, isSmallIncrement: Bool) -> Bool {
    let isAlreadySet = osdValue == self.readPrefValue(for: .brightness)
    var swAfterBirghtnessMode: Bool = isSwBrightnessNotDefault()
    if isAlreadySet, !isUp, !swAfterBirghtnessMode, prefs.bool(forKey: PrefKey.lowerSwAfterBrightness.rawValue) {
      swAfterBirghtnessMode = true
    }

    if swAfterBirghtnessMode {
      let currentSwBrightness = self.swBrightness
      var swBirghtnessValue = self.calcNewValue(currentValue: currentSwBrightness, isUp: isUp, isSmallIncrement: isSmallIncrement)
      if swBirghtnessValue >= 1 {
        swBirghtnessValue = 1
        swAfterBirghtnessMode = false
      }
      if self.setSwBrightness(value: swBirghtnessValue) {
        if let slider = brightnessSliderHandler?.slider {
          slider.floatValue = swBirghtnessValue * 0.5
        }
        self.doSwAfterOsdAnimation()
      }
    }
    return swAfterBirghtnessMode
  }

  override func stepBrightness(isUp: Bool, isSmallIncrement: Bool) {
    let currentValue = self.readPrefValue(for: .brightness)
    let osdValue = self.calcNewValue(currentValue: currentValue, isUp: isUp, isSmallIncrement: isSmallIncrement)
    if self.stepBrightnessPart(osdValue: osdValue, isSmallIncrement: isSmallIncrement) {
      return
    }
    if self.stepBrightnessswAfterBirghtnessMode(osdValue: osdValue, isUp: isUp, isSmallIncrement: isSmallIncrement) {
      return
    }
    guard self.writeDDCValues(command: .brightness, value: self.convValueToDDC(for: .brightness, from: osdValue)) == true else {
      return
    }
    if let slider = brightnessSliderHandler?.slider {
      if !self.isSw(), prefs.bool(forKey: PrefKey.lowerSwAfterBrightness.rawValue) {
        slider.floatValue = 0.5 + osdValue / 2
      } else {
        slider.floatValue = osdValue
      }
    }
    self.showOsd(command: .brightness, value: osdValue, roundChiclet: !isSmallIncrement)
    self.savePrefValue(osdValue, for: .brightness)
  }

  public func writeDDCValues(command: Command, value: UInt16, errorRecoveryWaitTime _: UInt32? = nil) -> Bool? {
    guard app.sleepID == 0, app.reconfigureID == 0, !self.forceSw else {
      return false
    }
    var success: Bool = false
    app.ddcQueue.sync {
      if Arm64DDC.isArm64 {
        if self.arm64ddc {
          success = Arm64DDC.write(service: self.arm64avService, command: command.rawValue, value: value)
        }
      } else {
        success = self.ddc?.write(command: command.rawValue, value: value, errorRecoveryWaitTime: 2000) ?? false
      }
    }
    return success
  }

  func readDDCValues(for command: Command, tries: UInt, minReplyDelay delay: UInt64?) -> (current: UInt16, max: UInt16)? {
    var values: (UInt16, UInt16)?
    guard app.sleepID == 0, app.reconfigureID == 0, !self.forceSw else {
      return values
    }
    if Arm64DDC.isArm64 {
      guard self.arm64ddc else {
        return nil
      }
      app.ddcQueue.sync {
        if let unwrappedDelay = delay {
          values = Arm64DDC.read(service: self.arm64avService, command: command.rawValue, tries: UInt8(min(tries, 255)), minReplyDelay: UInt32(unwrappedDelay / 1000))
        } else {
          values = Arm64DDC.read(service: self.arm64avService, command: command.rawValue, tries: UInt8(min(tries, 255)))
        }
      }
    } else {
      app.ddcQueue.sync {
        values = self.ddc?.read(command: command.rawValue, tries: tries, minReplyDelay: delay)
      }
    }
    return values
  }

  func calcNewValue(currentValue: Float, isUp: Bool, isSmallIncrement: Bool) -> Float {
    let nextValue: Float
    if isSmallIncrement {
      nextValue = currentValue + (isUp ? 0.01 : -0.01)
    } else {
      let osdChicletFromValue = OSDUtils.chiclet(fromValue: currentValue, maxValue: 1)
      let distance = OSDUtils.getDistance(fromNearestChiclet: osdChicletFromValue)
      // get the next rounded chiclet
      var nextFilledChiclet = isUp ? ceil(osdChicletFromValue) : floor(osdChicletFromValue)
      // Depending on the direction, if the chiclet is above or below a certain threshold, we go to the next whole chiclet
      let distanceThreshold: Float = 0.25 // 25% of the distance between the edges of an osd box
      if distance == 0 {
        nextFilledChiclet += (isUp ? 1 : -1)
      } else if !isUp, distance < distanceThreshold {
        nextFilledChiclet -= 1
      } else if isUp, distance > (1 - distanceThreshold) {
        nextFilledChiclet += 1
      }
      nextValue = OSDUtils.value(fromChiclet: nextFilledChiclet, maxValue: 1)
    }
    return max(0, min(1, nextValue))
  }

  func convValueToDDC(for command: Command, from: Float) -> UInt16 {
    let curveDDC = self.prefValueExistsKey(forkey: PrefKey.curveDDC, for: command) ? self.readPrefValueKey(forkey: PrefKey.curveDDC, for: command) : 1
    let minDDCValue = Float(self.readPrefValueKeyInt(forkey: PrefKey.minDDCOverride, for: command))
    let maxDDCValue = Float(self.readPrefValueKeyInt(forkey: PrefKey.maxDDC, for: command))
    let curvedValue = pow(max(min(from, 1), 0), curveDDC)
    let deNormalizedValue = (maxDDCValue - minDDCValue) * curvedValue + minDDCValue
    var intDDCValue = UInt16(min(max(deNormalizedValue, minDDCValue), maxDDCValue))
    if from > 0, command == Command.audioSpeakerVolume {
      intDDCValue = max(1, intDDCValue) // Never let sound to mute accidentally, keep it digitally to at digital 1 if needed as muting breaks some displays
    }
    return intDDCValue
  }

  func convDDCToValue(for command: Command, from: UInt16) -> Float {
    let curveDDC = self.prefValueExistsKey(forkey: PrefKey.curveDDC, for: command) ? self.readPrefValueKey(forkey: PrefKey.curveDDC, for: command) : 1
    let minDDCValue = Float(self.readPrefValueKeyInt(forkey: PrefKey.minDDCOverride, for: command))
    let maxDDCValue = Float(self.readPrefValueKeyInt(forkey: PrefKey.maxDDC, for: command))
    let normalizedValue = ((min(max(Float(from), minDDCValue), maxDDCValue) - minDDCValue) / (maxDDCValue - minDDCValue))
    let deCurvedValue = pow(normalizedValue, 1.0 / curveDDC)
    return max(min(deCurvedValue, 1), 0)
  }

  override func showOsd(command: Command, value: Float, maxValue: Float = 1, roundChiclet: Bool = false, lock: Bool = false) {
    super.showOsd(command: command, value: value, maxValue: maxValue, roundChiclet: roundChiclet, lock: lock)
  }

  func playVolumeChangedSound() {
    // Check if user has enabled "Play feedback when volume is changed" in Sound Preferences
    guard let preferences = Utils.getSystemPreferences(), let hasSoundEnabled = preferences["com.apple.sound.beep.feedback"] as? Int, hasSoundEnabled == 1 else {
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
