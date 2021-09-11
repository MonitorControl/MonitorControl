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
  let DDC_HARD_MAX_LIMIT: Int = 100
  let DDC_HARD_MIN_LIMIT: Int = 0
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
    return self.getValue(for: .audioMuteScreenBlank) == 1
  }

  func toggleMute(fromVolumeSlider: Bool = false) {
    var muteValue: Int
    var volumeOSDValue: Int
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
    self.saveValue(muteValue, for: .audioMuteScreenBlank)
    if !self.enableMuteUnmute || volumeOSDValue > 0 {
      _ = self.writeDDCValues(command: .audioSpeakerVolume, value: self.convValueToDDC(for: .audioSpeakerVolume, from: volumeOSDValue))
    }
    if !fromVolumeSlider {
      if !self.hideOsd {
        self.showOsd(command: volumeOSDValue > 0 ? .audioSpeakerVolume : .audioMuteScreenBlank, value: volumeOSDValue, roundChiclet: true)
      }
      if let slider = self.volumeSliderHandler?.slider {
        slider.intValue = Int32(volumeOSDValue)
      }
    }
  }

  func setupCurrentAndMaxValues(command: Command) {
    var ddcValues: (UInt16, UInt16)?
    var maxDDCValue: UInt16 = 100
    var currentDDCValue: UInt16 = 0
    var currentValue: Int = 0
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
          (currentDDCValue, maxDDCValue) = ddcValues ?? (75, 100)
          self.saveMaxDDCValue(Int(maxDDCValue), for: command)
          self.saveValue(self.convDDCToValue(for: command, from: currentDDCValue), for: command)
          os_log("DDC read successful.", type: .info)
        } else {
          os_log("DDC read failed.", type: .info)
        }
      } else {
        os_log("DDC read disabled.", type: .info)
      }
      if ddcValues == nil {
        self.saveValue(self.getValueExists(for: command) ? self.getValue(for: command) : 75, for: command)
        currentDDCValue = self.convValueToDDC(for: command, from: self.getValue(for: command))
        self.saveMaxDDCValue(Int(maxDDCValue), for: command)
      }
      os_log(" - current DDC value: %{public}@", type: .info, String(currentDDCValue))
      os_log(" - minimum DDC value: %{public}@ (override 0)", type: .info, String(self.getMinDDCOverrideValue(for: command)))
      os_log(" - maximum DDC value: %{public}@", type: .info, String(self.getMaxDDCValue(for: command)))
      os_log(" - current internal value: %{public}@", type: .info, String(self.getValue(for: command)))
      if prefs.bool(forKey: PrefKeys.restoreLastSavedValues.rawValue) {
        os_log("Writing last saved DDC values.", type: .info, self.name, String(reflecting: command))
        _ = self.writeDDCValues(command: command, value: currentDDCValue)
      }
    }
  }

  func getSliderCurrentAndMaxValues(command: Command) -> (value: Int, maxValue: Int) {
    var returnIntegerValue: Int = 75
    var returnMaxValue: Int = 100
    let currentValue = self.getValue(for: command)
    if command == .brightness {
      if !self.isSw(), prefs.bool(forKey: PrefKeys.lowerSwAfterBrightness.rawValue) {
        returnMaxValue = 200
        returnIntegerValue = returnMaxValue / 2 + Int(currentValue)
      } else {
        returnIntegerValue = Int(currentValue)
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
          self.saveValue(Int(muteValues.current), for: .audioMuteScreenBlank)
          self.saveMaxDDCValue(Int(muteValues.max), for: .audioMuteScreenBlank)
        } else {
          os_log(" - read failed or disabled, skipping", type: .info)
        }
      }
      // If the system is not currently muted, or doesn't support the mute command, display the current volume as the slider value
      if muteValues == nil || muteValues!.current == 2 {
        returnIntegerValue = Int(currentValue)
      } else {
        returnIntegerValue = 0
      }
    } else {
      returnIntegerValue = currentValue
    }
    return (returnIntegerValue, returnMaxValue)
  }

  func stepVolume(isUp: Bool, isSmallIncrement: Bool) {
    let currentValue = self.getValue(for: .audioSpeakerVolume)
    var muteValue: Int?
    let volumeOSDValue = self.calcNewValue(currentValue: currentValue, maxValue: 100, isUp: isUp, isSmallIncrement: isSmallIncrement)
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
        self.saveValue(muteValue, for: .audioMuteScreenBlank)
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
        slider.intValue = Int32(volumeOSDValue)
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
        self.showOsd(command: .brightness, value: value, roundChiclet: false)
        Thread.sleep(forTimeInterval: Double(value * 2) / 300)
      }
      for value: Int in stride(from: 5, to: 0, by: -1) {
        guard self.getValue(for: .brightness) == 0 else {
          self.swAfterOsdAnimationSemaphore.signal()
          return
        }
        self.showOsd(command: .brightness, value: value, roundChiclet: false)
        Thread.sleep(forTimeInterval: Double(value * 2) / 300)
      }
      self.showOsd(command: .brightness, value: 0, roundChiclet: true)
      self.swAfterOsdAnimationSemaphore.signal()
    }
  }

  func stepBrightnessPart(osdValue: Int, isSmallIncrement: Bool) -> Bool {
    if self.isSw(), prefs.bool(forKey: PrefKeys.fallbackSw.rawValue) {
      if self.setSwBrightness(value: UInt8(osdValue), smooth: true) {
        self.showOsd(command: .brightness, value: osdValue, roundChiclet: !isSmallIncrement)
        self.saveValue(osdValue, for: .brightness)
        if let slider = brightnessSliderHandler?.slider {
          slider.intValue = Int32(osdValue)
        }
      }
      return true
    }
    return false
  }

  func stepBrightnessswAfterBirghtnessMode(osdValue: Int, isUp: Bool, isSmallIncrement: Bool) -> Bool {
    let isAlreadySet = osdValue == self.getValue(for: .brightness)
    var swAfterBirghtnessMode: Bool = isSwBrightnessNotDefault()
    if isAlreadySet, !isUp, !swAfterBirghtnessMode, prefs.bool(forKey: PrefKeys.lowerSwAfterBrightness.rawValue) {
      swAfterBirghtnessMode = true
    }

    if swAfterBirghtnessMode {
      let currentSwBrightness = UInt8(self.getSwBrightnessPrefValue())
      var swBirghtnessValue = self.calcNewValue(currentValue: Int(currentSwBrightness), maxValue: Int(getSwMaxBrightness()), isUp: isUp, isSmallIncrement: isSmallIncrement)
      if swBirghtnessValue >= Int(getSwMaxBrightness()) {
        swBirghtnessValue = Int(getSwMaxBrightness())
        swAfterBirghtnessMode = false
      }
      if self.setSwBrightness(value: UInt8(swBirghtnessValue)) {
        if let slider = brightnessSliderHandler?.slider {
          slider.intValue = Int32(Float(slider.maxValue / 2) * (Float(swBirghtnessValue) / Float(getSwMaxBrightness())))
        }
        self.doSwAfterOsdAnimation()
      }
    }
    return swAfterBirghtnessMode
  }

  override func stepBrightness(isUp: Bool, isSmallIncrement: Bool) {
    let currentValue = self.getValue(for: .brightness)
    let maxValue = self.isSw() ? Int(self.getSwMaxBrightness()) : 100
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
        slider.intValue = Int32(slider.maxValue / 2) + Int32(osdValue)
      } else {
        slider.intValue = Int32(osdValue)
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

  func calcNewValue(currentValue: Int, maxValue: Int, isUp: Bool, isSmallIncrement: Bool) -> Int {
    let nextValue: Int
    if isSmallIncrement {
      nextValue = currentValue + (isUp ? 1 : -1)
    } else {
      let osdChicletFromValue = OSDUtils.chiclet(fromValue: Float(currentValue), maxValue: Float(maxValue))
      let distance = OSDUtils.getDistance(fromNearestChiclet: osdChicletFromValue)
      // get the next rounded chiclet
      var nextFilledChiclet = isUp ? ceil(osdChicletFromValue) : floor(osdChicletFromValue)
      // Depending on the direction, if the chiclet is above or below a certain threshold, we go to the next whole chiclet
      let distanceThreshold = Float(0.25) // 25% of the distance between the edges of an osd box
      if distance == 0 {
        nextFilledChiclet += isUp ? 1 : -1
      } else if !isUp, distance < distanceThreshold {
        nextFilledChiclet -= 1
      } else if isUp, distance > (1 - distanceThreshold) {
        nextFilledChiclet += 1
      }
      nextValue = Int(round(OSDUtils.value(fromChiclet: nextFilledChiclet, maxValue: Float(maxValue))))
      os_log("next: .value %{public}@/%{public}@, .osd %{public}@/%{public}@", type: .debug, String(nextValue), String(maxValue), String(nextFilledChiclet), String(OSDUtils.chicletCount))
    }
    return max(0, min(maxValue, nextValue))
  }

  func convValueToDDC(for command: Command, from: Int) -> UInt16 {
    let minDDCValue = Float(self.getMinDDCOverrideValue(for: command))
    let maxDDCValue = Float(self.getMaxDDCValue(for: command))
    let curvedValue: Float = pow(max(min(Float(from), 100), 0) / 100, self.getCurveDDC(for: command)) * 100
    let deNormalizedValue: Float = (maxDDCValue - minDDCValue) * (curvedValue / 100) + minDDCValue
    var intDDCValue = UInt16(min(max(Float(deNormalizedValue), minDDCValue), maxDDCValue))
    if from > 0, command == Command.audioSpeakerVolume {
      intDDCValue = max(1, intDDCValue) // Never let sound to mute accidentally, keep it digitally to at digital 1 if needed as muting breaks some displays
    }
    return intDDCValue
  }

  func convDDCToValue(for command: Command, from: UInt16) -> Int {
    let minDDCValue = Float(self.getMinDDCOverrideValue(for: command))
    let maxDDCValue = Float(self.getMaxDDCValue(for: command))
    let normalizedValue: Float = ((min(max(Float(from), minDDCValue), maxDDCValue) - minDDCValue) / (maxDDCValue - minDDCValue)) * 100
    let deCurvedValue: Float = pow(normalizedValue / 100, 1.0 / self.getCurveDDC(for: command)) * 100
    var intValue = Int(max(min(Float(deCurvedValue), 100), 0))
    if from > 0, command == Command.audioSpeakerVolume {
      intValue = max(1, intValue) // Never let sound to mute accidentally, keep it digitally to at digital 1 if needed as muting breaks some displays
    }
    return intValue
  }

  func getValue(for command: Command) -> Int {
    return prefs.integer(forKey: PrefKeys.value.rawValue + String(command.rawValue) + self.prefsId)
  }

  func getValueExists(for command: Command) -> Bool {
    return prefs.object(forKey: PrefKeys.value.rawValue + String(command.rawValue) + self.prefsId) != nil
  }

  func saveValue(_ value: Int, for command: Command) {
    prefs.set(value, forKey: PrefKeys.value.rawValue + String(command.rawValue) + self.prefsId)
  }

  func saveMaxDDCValue(_ maxValue: Int, for command: Command) {
    prefs.set(maxValue, forKey: PrefKeys.maxDDC.rawValue + String(command.rawValue) + self.prefsId)
  }

  func getMaxDDCValue(for command: Command) -> Int {
    let maxVal = prefs.integer(forKey: PrefKeys.maxDDC.rawValue + String(command.rawValue) + self.prefsId)
    return min(self.DDC_HARD_MAX_LIMIT, maxVal)
  }

  func saveMaxDDCOverrideValue(_ maxValue: Int, for command: Command) {
    prefs.set(maxValue, forKey: PrefKeys.maxDDCOverride.rawValue + String(command.rawValue) + self.prefsId)
  }

  func getMaxDDCOverrideValue(for command: Command) -> Int {
    let maxVal = prefs.integer(forKey: PrefKeys.maxDDCOverride.rawValue + String(command.rawValue) + self.prefsId)
    return min(self.DDC_HARD_MAX_LIMIT, maxVal)
  }

  func saveMinDDCOverrideValue(_ minValue: Int, for command: Command) {
    prefs.set(minValue, forKey: PrefKeys.mindDDCOverride.rawValue + String(command.rawValue) + self.prefsId)
  }

  func getMinDDCOverrideValue(for command: Command) -> Int {
    let minVal = prefs.integer(forKey: PrefKeys.mindDDCOverride.rawValue + String(command.rawValue) + self.prefsId)
    return max(self.DDC_HARD_MIN_LIMIT, minVal)
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

  private func stepSize(for _: Command, isSmallIncrement: Bool) -> Int {
    return isSmallIncrement ? 1 : Int(floor(Float(100) / OSDUtils.chicletCount))
  }

  override func showOsd(command: Command, value: Int, maxValue _: Int = 100, roundChiclet: Bool = false, lock: Bool = false) {
    super.showOsd(command: command, value: value, maxValue: 100, roundChiclet: roundChiclet, lock: lock)
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
