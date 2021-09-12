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
    get {
      return prefs.bool(forKey: PrefKeys.enableMuteUnmute.rawValue + self.prefsId)
    }
    set {
      prefs.set(newValue, forKey: PrefKeys.enableMuteUnmute.rawValue + self.prefsId)
    }
  }

  var hideOsd: Bool {
    get {
      return prefs.bool(forKey: PrefKeys.hideOsd.rawValue + self.prefsId)
    }
    set {
      prefs.set(newValue, forKey: PrefKeys.hideOsd.rawValue + self.prefsId)
    }
  }

  var needsLongerDelay: Bool {
    get {
      return prefs.object(forKey: PrefKeys.longerDelay.rawValue + self.prefsId) as? Bool ?? false
    }
    set {
      prefs.set(newValue, forKey: PrefKeys.longerDelay.rawValue + self.prefsId)
    }
  }

  override init(_ identifier: CGDirectDisplayID, name: String, vendorNumber: UInt32?, modelNumber: UInt32?, isVirtual: Bool = false) {
    super.init(identifier, name: name, vendorNumber: vendorNumber, modelNumber: modelNumber, isVirtual: isVirtual)
    if !isVirtual, !Arm64DDC.isArm64 {
      self.ddc = IntelDDC(for: identifier)
    }
  }

  func isMuted() -> Bool {
    return self.getIntValue(for: .audioMuteScreenBlank) == 1
  }

  func toggleMute(fromVolumeSlider: Bool = false) {
    var muteValue: Int
    var volumeOSDValue: Float
    if !self.isMuted() {
      muteValue = 1
      volumeOSDValue = 0
    } else {
      muteValue = 2
      volumeOSDValue = self.getValue(for: .audioSpeakerVolume)
      // The volume that will be set immediately after setting unmute while the old set volume was 0 is unpredictable. Hence, just set it to a single filled chiclet
      if volumeOSDValue == 0 {
        volumeOSDValue = self.stepSize(for: .audioSpeakerVolume, isSmallIncrement: false)
        self.saveValue(volumeOSDValue, for: .audioSpeakerVolume)
      }
    }
    if self.enableMuteUnmute {
      guard self.writeDDCValues(command: .audioMuteScreenBlank, value: UInt16(muteValue)) == true else {
        return
      }
    }
    self.saveIntValue(muteValue, for: .audioMuteScreenBlank)
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
    var currentValue: Float = SCALE
    os_log("** Setting up %{public}@ for %{public}@ **", type: .info, self.name, String(reflecting: command))
    if self.isSw(), command == Command.brightness {
      os_log("Software control is used.", type: .info)
      currentValue = self.getSwBrightnessPrefValue()
      os_log(" - current internal value: %{public}@", type: .info, String(currentValue))
    } else {
      let tries = UInt(self.getPollingCount())
      if !prefs.bool(forKey: PrefKeys.restoreLastSavedValues.rawValue), tries != 0, !(app.safeMode) {
        os_log("Reading DDC from display %{public}@ times", type: .info, String(tries))
        let delay = self.needsLongerDelay ? UInt64(40 * kMillisecondScale) : nil
        ddcValues = self.readDDCValues(for: command, tries: tries, minReplyDelay: delay)
        if ddcValues != nil {
          (currentDDCValue, maxDDCValue) = ddcValues ?? (currentDDCValue, maxDDCValue)
          self.saveValue(self.convDDCToValue(for: command, from: currentDDCValue), for: command)
          os_log("DDC read successful.", type: .info)
        } else {
          os_log("DDC read failed.", type: .info)
        }
      } else {
        os_log("DDC read disabled.", type: .info)
      }
      if ddcValues == nil {
        self.saveValue(self.getValueExists(for: command) ? self.getValue(for: command) : SCALE * 0.75, for: command)
        currentDDCValue = self.convValueToDDC(for: command, from: self.getValue(for: command))
      }
      if self.getMaxDDCOverrideValue(for: command) > self.getMinDDCOverrideValue(for: command) {
        self.saveMaxDDCValue(self.getMaxDDCOverrideValue(for: command), for: command)
      } else {
        self.saveMaxDDCValue(min(Int(maxDDCValue), self.DDC_MAX_DETECT_LIMIT), for: command)
      }
      os_log(" - current DDC value: %{public}@", type: .info, String(currentDDCValue))
      os_log(" - minimum DDC value: %{public}@ (overrides 0)", type: .info, String(self.getMinDDCOverrideValue(for: command)))
      os_log(" - maximum DDC value: %{public}@ (overrides %{public}@)", type: .info, String(self.getMaxDDCValue(for: command)), String(maxDDCValue))
      os_log(" - current internal value: %{public}@", type: .info, String(self.getValue(for: command)))
      if prefs.bool(forKey: PrefKeys.restoreLastSavedValues.rawValue) {
        os_log("Writing last saved DDC values.", type: .info, self.name, String(reflecting: command))
        _ = self.writeDDCValues(command: command, value: currentDDCValue)
      }
    }
  }

  func getSliderCurrentAndMaxValues(command: Command) -> (value: Float, maxValue: Float) {
    var returnValue: Float = 0.75 * SCALE
    var returnMaxValue: Float = SCALE
    let currentValue = self.getValue(for: command)
    if command == .brightness {
      if !self.isSw(), prefs.bool(forKey: PrefKeys.lowerSwAfterBrightness.rawValue) {
        returnMaxValue = SCALE + SCALE
        returnValue = returnMaxValue / 2 + currentValue
      } else {
        returnValue = currentValue
      }
    } else if command == .audioSpeakerVolume, !self.isSw() {
      // If we're looking at the audio speaker volume, also retrieve the values for the mute command
      var muteValues: (current: UInt16, max: UInt16)?
      let tries = UInt(self.getPollingCount())
      if self.enableMuteUnmute, tries != 0, !app.safeMode, !prefs.bool(forKey: PrefKeys.restoreLastSavedValues.rawValue) {
        os_log("Reading DDC from display %{public}@ times for mute", type: .info, String(tries))
        let delay = self.needsLongerDelay ? UInt64(40 * kMillisecondScale) : nil
        muteValues = self.readDDCValues(for: .audioMuteScreenBlank, tries: tries, minReplyDelay: delay)
        if let muteValues = muteValues {
          os_log(" - success, current DDC value: %{public}@", type: .info, String(muteValues.current))
          self.saveIntValue(Int(muteValues.current), for: .audioMuteScreenBlank)
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
    return (returnValue, returnMaxValue)
  }

  func stepVolume(isUp: Bool, isSmallIncrement: Bool) {
    let currentValue = self.getValue(for: .audioSpeakerVolume)
    var muteValue: Int?
    let volumeOSDValue = self.calcNewValue(currentValue: currentValue, maxValue: SCALE, isUp: isUp, isSmallIncrement: isSmallIncrement)
    if self.isMuted(), volumeOSDValue > 0 {
      muteValue = 2
    } else if !self.isMuted(), volumeOSDValue == 0 {
      muteValue = 1
    }
    let isAlreadySet = volumeOSDValue == self.getValue(for: .audioSpeakerVolume)
    if !isAlreadySet {
      if let muteValue = muteValue, self.enableMuteUnmute {
        guard self.writeDDCValues(command: .audioMuteScreenBlank, value: UInt16(muteValue)) == true else {
          return
        }
        self.saveIntValue(muteValue, for: .audioMuteScreenBlank)
      }
      if !self.enableMuteUnmute || volumeOSDValue != 0 {
        _ = self.writeDDCValues(command: .audioSpeakerVolume, value: self.convValueToDDC(for: .audioSpeakerVolume, from: volumeOSDValue))
      }
    }
    if !self.hideOsd {
      self.showOsd(command: .audioSpeakerVolume, value: volumeOSDValue, roundChiclet: !isSmallIncrement)
    }
    if !isAlreadySet {
      self.saveValue(volumeOSDValue, for: .audioSpeakerVolume)
      if let slider = self.volumeSliderHandler?.slider {
        slider.floatValue = volumeOSDValue
      }
    }
  }

  func isSwOnly() -> Bool {
    return (!self.arm64ddc && self.ddc == nil && !self.isVirtual)
  }

  func isSw() -> Bool {
    if prefs.bool(forKey: PrefKeys.forceSw.rawValue + self.prefsId) || self.isSwOnly() {
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
        guard self.getValue(for: .brightness) == 0 else {
          self.swAfterOsdAnimationSemaphore.signal()
          return
        }
        self.showOsd(command: .brightness, value: Float(value), maxValue: 100, roundChiclet: false)
        Thread.sleep(forTimeInterval: Double(value * 2) / 300)
      }
      for value: Int in stride(from: 5, to: 0, by: -1) {
        guard self.getValue(for: .brightness) == 0 else {
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
    if self.isSw(), prefs.bool(forKey: PrefKeys.fallbackSw.rawValue) {
      if self.setSwBrightness(value: osdValue, smooth: true) {
        self.showOsd(command: .brightness, value: osdValue, maxValue: SCALE, roundChiclet: !isSmallIncrement)
        self.saveValue(osdValue, for: .brightness)
        if let slider = brightnessSliderHandler?.slider {
          slider.floatValue = osdValue
        }
      }
      return true
    }
    return false
  }

  func stepBrightnessswAfterBirghtnessMode(osdValue: Float, isUp: Bool, isSmallIncrement: Bool) -> Bool {
    let isAlreadySet = osdValue == self.getValue(for: .brightness)
    var swAfterBirghtnessMode: Bool = isSwBrightnessNotDefault()
    if isAlreadySet, !isUp, !swAfterBirghtnessMode, prefs.bool(forKey: PrefKeys.lowerSwAfterBrightness.rawValue) {
      swAfterBirghtnessMode = true
    }

    if swAfterBirghtnessMode {
      let currentSwBrightness = self.getSwBrightnessPrefValue()
      var swBirghtnessValue = self.calcNewValue(currentValue: currentSwBrightness, maxValue: SCALE, isUp: isUp, isSmallIncrement: isSmallIncrement)
      if swBirghtnessValue >= SCALE {
        swBirghtnessValue = SCALE
        swAfterBirghtnessMode = false
      }
      if self.setSwBrightness(value: swBirghtnessValue) {
        if let slider = brightnessSliderHandler?.slider {
          slider.floatValue = (Float(slider.maxValue) / 2 * (swBirghtnessValue / SCALE))
        }
        self.doSwAfterOsdAnimation()
      }
    }
    return swAfterBirghtnessMode
  }

  override func stepBrightness(isUp: Bool, isSmallIncrement: Bool) {
    let currentValue = self.getValue(for: .brightness)
    let maxValue: Float = SCALE
    let osdValue = self.calcNewValue(currentValue: currentValue, maxValue: maxValue, isUp: isUp, isSmallIncrement: isSmallIncrement)
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
      if !self.isSw(), prefs.bool(forKey: PrefKeys.lowerSwAfterBrightness.rawValue) {
        slider.floatValue = Float(slider.maxValue / 2) + osdValue
      } else {
        slider.floatValue = osdValue
      }
    }
    self.showOsd(command: .brightness, value: osdValue, roundChiclet: !isSmallIncrement)
    self.saveValue(osdValue, for: .brightness)
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

  func calcNewValue(currentValue: Float, maxValue: Float, isUp: Bool, isSmallIncrement: Bool) -> Float {
    let nextValue: Float
    if isSmallIncrement {
      nextValue = currentValue + (isUp ? SCALE * 0.01 : SCALE * -0.01)
    } else {
      let osdChicletFromValue = OSDUtils.chiclet(fromValue: currentValue, maxValue: maxValue)
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
      nextValue = OSDUtils.value(fromChiclet: nextFilledChiclet, maxValue: maxValue)
    }
    return max(0, min(maxValue, nextValue))
  }

  func convValueToDDC(for command: Command, from: Float) -> UInt16 {
    let minDDCValue = Float(self.getMinDDCOverrideValue(for: command))
    let maxDDCValue = Float(self.getMaxDDCValue(for: command))
    let curvedValue = pow(max(min(from, SCALE), 0) / SCALE, self.getCurveDDC(for: command)) * SCALE
    let deNormalizedValue = (maxDDCValue - minDDCValue) * (curvedValue / SCALE) + minDDCValue
    var intDDCValue = UInt16(min(max(deNormalizedValue, minDDCValue), maxDDCValue))
    if from > 0, command == Command.audioSpeakerVolume {
      intDDCValue = max(1, intDDCValue) // Never let sound to mute accidentally, keep it digitally to at digital 1 if needed as muting breaks some displays
    }
    return intDDCValue
  }

  func convDDCToValue(for command: Command, from: UInt16) -> Float {
    let minDDCValue = Float(self.getMinDDCOverrideValue(for: command))
    let maxDDCValue = Float(self.getMaxDDCValue(for: command))
    let normalizedValue = ((min(max(Float(from), minDDCValue), maxDDCValue) - minDDCValue) / (maxDDCValue - minDDCValue)) * SCALE
    let deCurvedValue = pow(normalizedValue / SCALE, 1.0 / self.getCurveDDC(for: command)) * SCALE
    return max(min(deCurvedValue, SCALE), 0)
  }

  func getValueExists(for command: Command) -> Bool {
    return prefs.object(forKey: PrefKeys.value.rawValue + String(command.rawValue) + self.prefsId) != nil
  }

  func getValue(for command: Command) -> Float {
    return prefs.float(forKey: PrefKeys.value.rawValue + String(command.rawValue) + self.prefsId)
  }

  func getIntValue(for command: Command) -> Int {
    return prefs.integer(forKey: PrefKeys.value.rawValue + String(command.rawValue) + self.prefsId)
  }

  func saveValue(_ value: Float, for command: Command) {
    prefs.set(value, forKey: PrefKeys.value.rawValue + String(command.rawValue) + self.prefsId)
  }

  func saveIntValue(_ value: Int, for command: Command) {
    prefs.set(value, forKey: PrefKeys.value.rawValue + String(command.rawValue) + self.prefsId)
  }

  func saveMaxDDCValue(_ maxValue: Int, for command: Command) {
    prefs.set(maxValue, forKey: PrefKeys.maxDDC.rawValue + String(command.rawValue) + self.prefsId)
  }

  func getMaxDDCValue(for command: Command) -> Int {
    return prefs.integer(forKey: PrefKeys.maxDDC.rawValue + String(command.rawValue) + self.prefsId)
  }

  func saveMaxDDCOverrideValue(_ maxValue: Int, for command: Command) {
    prefs.set(maxValue, forKey: PrefKeys.maxDDCOverride.rawValue + String(command.rawValue) + self.prefsId)
  }

  func getMaxDDCOverrideValue(for command: Command) -> Int {
    return prefs.integer(forKey: PrefKeys.maxDDCOverride.rawValue + String(command.rawValue) + self.prefsId)
  }

  func saveMinDDCOverrideValue(_ minValue: Int, for command: Command) {
    prefs.set(minValue, forKey: PrefKeys.mindDDCOverride.rawValue + String(command.rawValue) + self.prefsId)
  }

  func getMinDDCOverrideValue(for command: Command) -> Int {
    return prefs.integer(forKey: PrefKeys.mindDDCOverride.rawValue + String(command.rawValue) + self.prefsId)
  }

  func getCurveDDC(for command: Command) -> Float {
    if prefs.object(forKey: PrefKeys.curveDDC.rawValue + String(command.rawValue) + self.prefsId) != nil {
      return prefs.float(forKey: PrefKeys.curveDDC.rawValue + String(command.rawValue) + self.prefsId)
    }
    return 1
  }

  func saveCurveDDC(_ value: Float, for command: Command) {
    prefs.set(value, forKey: PrefKeys.curveDDC.rawValue + String(command.rawValue) + self.prefsId)
  }

  func setPollingMode(_ value: Int) {
    prefs.set(String(value), forKey: PrefKeys.pollingMode.rawValue + self.prefsId)
  }

  func getPollingMode() -> Int {
    return Int(prefs.string(forKey: PrefKeys.pollingMode.rawValue + self.prefsId) ?? "2") ?? 2 // Reading as string so we don't get "0" as the default value
  }

  func getPollingCount() -> Int {
    let selectedMode = self.getPollingMode()
    switch selectedMode {
    case 0: return Utils.PollingMode.none.value
    case 1: return Utils.PollingMode.minimal.value
    case 2: return Utils.PollingMode.normal.value
    case 3: return Utils.PollingMode.heavy.value
    case 4:
      let val = prefs.integer(forKey: PrefKeys.pollingCount.rawValue + self.prefsId)
      return Utils.PollingMode.custom(value: val).value
    default: return 0
    }
  }

  func setPollingCount(_ value: Int) {
    prefs.set(value, forKey: PrefKeys.pollingCount.rawValue + self.prefsId)
  }

  private func stepSize(for _: Command, isSmallIncrement: Bool) -> Float {
    return isSmallIncrement ? 1 : floor(SCALE / OSDUtils.chicletCount)
  }

  override func showOsd(command: Command, value: Float, maxValue: Float = SCALE, roundChiclet: Bool = false, lock: Bool = false) {
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
