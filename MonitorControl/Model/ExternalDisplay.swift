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

  let DDC_HARD_MAX_LIMIT: Int = 100

  private let prefs = UserDefaults.standard

  var enableMuteUnmute: Bool {
    get {
      return self.prefs.bool(forKey: "enableMuteUnmute-\(self.identifier)")
    }
    set {
      self.prefs.set(newValue, forKey: "enableMuteUnmute-\(self.identifier)")
      os_log("Set `enableMuteUnmute` for %{private}@ to: %{public}@", type: .info, String(self.identifier), String(newValue))
    }
  }

  var hideOsd: Bool {
    get {
      return self.prefs.bool(forKey: "hideOsd-\(self.identifier)")
    }
    set {
      self.prefs.set(newValue, forKey: "hideOsd-\(self.identifier)")
      os_log("Set `hideOsd` to: %{public}@", type: .info, String(newValue))
    }
  }

  var needsLongerDelay: Bool {
    get {
      return self.prefs.object(forKey: "longerDelay-\(self.identifier)") as? Bool ?? false
    }
    set {
      self.prefs.set(newValue, forKey: "longerDelay-\(self.identifier)")
      os_log("Set `needsLongerDisplay` to: %{public}@", type: .info, String(newValue))
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

      // The volume that will be set immediately after setting unmute while the old set volume was 0 is unpredictable
      // Hence, just set it to a single filled chiclet
      if volumeOSDValue == 0 {
        volumeOSDValue = self.stepSize(for: .audioSpeakerVolume, isSmallIncrement: false)
        self.saveValue(volumeOSDValue, for: .audioSpeakerVolume)
      }
    }

    let volumeDDCValue = UInt16(volumeOSDValue)

    if self.enableMuteUnmute {
      guard self.writeDDCValues(command: .audioMuteScreenBlank, value: UInt16(muteValue)) == true else {
        return
      }
    }

    self.saveValue(muteValue, for: .audioMuteScreenBlank)

    if !self.enableMuteUnmute || volumeOSDValue > 0 {
      _ = self.writeDDCValues(command: .audioSpeakerVolume, value: volumeDDCValue)
    }

    if !fromVolumeSlider {
      if !self.hideOsd {
        self.showOsd(command: volumeOSDValue > 0 ? .audioSpeakerVolume : .audioMuteScreenBlank, value: volumeOSDValue, roundChiclet: true)
      }

      if let slider = self.volumeSliderHandler?.slider {
        slider.intValue = Int32(volumeDDCValue)
      }
    }
  }

  func setupCurrentAndMaxValues(command: Command) -> (value: Int, maxValue: Int) {
    var returnIntegerValue: Int
    var returnMaxValue: Int
    var values: (UInt16, UInt16)?
    let delay = self.needsLongerDelay ? UInt64(40 * kMillisecondScale) : nil

    var (currentValue, maxValue) = (UInt16(0), UInt16(0))

    let tries = UInt(self.getPollingCount())

    if self.isSw(), command == Command.brightness {
      (currentValue, maxValue) = (UInt16(self.getSwBrightnessPrefValue()), UInt16(self.getSwMaxBrightness()))
    } else {
      if tries != 0, !(app.safeMode) {
        os_log("Polling %{public}@ times", type: .info, String(tries))
        values = self.readDDCValues(for: command, tries: tries, minReplyDelay: delay)
      }
      (currentValue, maxValue) = values ?? (UInt16(self.getValueExists(for: command) ? self.getValue(for: command) : 75), 100) // We set 100 as max value if we could not read DDC, the previous setting as current value or 75 if not present.
    }
    self.saveMaxValue(Int(maxValue), for: command)
    self.saveValue(min(Int(currentValue), self.getMaxValue(for: command)), for: command) // We won't allow currrent value to be higher than the max. value
    os_log("%{public}@ (%{public}@):", type: .info, self.name, String(reflecting: command))
    os_log(" - current value: %{public}@ - from display? %{public}@", type: .info, String(currentValue), String(values != nil))
    os_log(" - maximum value: %{public}@ - from display? %{public}@", type: .info, String(self.getMaxValue(for: command)), String(values != nil))

    if command == .brightness {
      if !self.isSw(), self.prefs.bool(forKey: Utils.PrefKeys.lowerSwAfterBrightness.rawValue) {
        returnMaxValue = self.getMaxValue(for: command) * 2
        returnIntegerValue = returnMaxValue / 2 + Int(currentValue)
      } else {
        returnIntegerValue = Int(currentValue)
        returnMaxValue = self.getMaxValue(for: command)
      }
    } else if command == .audioSpeakerVolume {
      // If we're looking at the audio speaker volume, also retrieve the values for the mute command
      var muteValues: (current: UInt16, max: UInt16)?

      if self.enableMuteUnmute, tries != 0, !app.safeMode {
        os_log("Polling %{public}@ times", type: .info, String(tries))
        os_log("%{public}@ (%{public}@):", type: .info, self.name, String(reflecting: Command.audioMuteScreenBlank))
        muteValues = self.readDDCValues(for: .audioMuteScreenBlank, tries: tries, minReplyDelay: delay)
      }

      if let muteValues = muteValues {
        os_log(" - current ddc value: %{public}@", type: .info, String(muteValues.current))
        os_log(" - maximum ddc value: %{public}@", type: .info, String(muteValues.max))
        self.saveValue(Int(muteValues.current), for: .audioMuteScreenBlank)
        self.saveMaxValue(Int(muteValues.max), for: .audioMuteScreenBlank)
      } else {
        os_log(" - current ddc value: unknown", type: .info)
        os_log(" - stored maximum ddc value: %{public}@", type: .info, String(self.getMaxValue(for: .audioMuteScreenBlank)))
      }

      // If the system is not currently muted, or doesn't support the mute command, display the current volume as the slider value
      if muteValues == nil || muteValues!.current == 2 {
        returnIntegerValue = Int(currentValue)
      } else {
        returnIntegerValue = 0
      }

      returnMaxValue = self.getMaxValue(for: command)
    } else {
      returnIntegerValue = Int(currentValue)
      returnMaxValue = self.getMaxValue(for: command)
    }
    return (returnIntegerValue, returnMaxValue)
  }

  func stepVolume(isUp: Bool, isSmallIncrement: Bool) {
    let currentValue = self.getValue(for: .audioSpeakerVolume)

    var muteValue: Int?
    let maxValue = self.getMaxValue(for: .audioSpeakerVolume)
    let volumeOSDValue = self.calcNewValue(currentValue: currentValue, maxValue: maxValue, isUp: isUp, isSmallIncrement: isSmallIncrement)
    let volumeDDCValue = UInt16(volumeOSDValue)
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
        _ = self.writeDDCValues(command: .audioSpeakerVolume, value: volumeDDCValue)
      }
    }
    if !self.hideOsd {
      self.showOsd(command: .audioSpeakerVolume, value: volumeOSDValue, roundChiclet: !isSmallIncrement)
    }
    if !isAlreadySet {
      self.saveValue(volumeOSDValue, for: .audioSpeakerVolume)
      if let slider = self.volumeSliderHandler?.slider {
        slider.intValue = Int32(volumeDDCValue)
      }
    }
  }

  func isSwOnly() -> Bool {
    return (!self.arm64ddc && self.ddc == nil && !self.isVirtual)
  }

  func isSw() -> Bool {
    if self.prefs.bool(forKey: "forceSw-\(self.identifier)") || self.isSwOnly() {
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
    if self.isSw(), self.prefs.bool(forKey: Utils.PrefKeys.fallbackSw.rawValue) {
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
    if isAlreadySet, !isUp, !swAfterBirghtnessMode, self.prefs.bool(forKey: Utils.PrefKeys.lowerSwAfterBrightness.rawValue) {
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
    let maxValue = self.isSw() ? Int(self.getSwMaxBrightness()) : self.getMaxValue(for: .brightness)
    let osdValue = self.calcNewValue(currentValue: currentValue, maxValue: maxValue, isUp: isUp, isSmallIncrement: isSmallIncrement)

    if self.stepBrightnessPart(osdValue: osdValue, isSmallIncrement: isSmallIncrement) {
      return
    }

    if self.stepBrightnessswAfterBirghtnessMode(osdValue: osdValue, isUp: isUp, isSmallIncrement: isSmallIncrement) {
      return
    }

    let ddcValue = UInt16(osdValue)
    guard self.writeDDCValues(command: .brightness, value: ddcValue) == true else {
      return
    }
    if let slider = brightnessSliderHandler?.slider {
      if !self.isSw(), self.prefs.bool(forKey: Utils.PrefKeys.lowerSwAfterBrightness.rawValue) {
        slider.intValue = Int32(slider.maxValue / 2) + Int32(ddcValue)
      } else {
        slider.intValue = Int32(ddcValue)
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

  func getValue(for command: Command) -> Int {
    return self.prefs.integer(forKey: "\(command.rawValue)-\(self.identifier)")
  }

  func getValueExists(for command: Command) -> Bool {
    return self.prefs.object(forKey: "\(command.rawValue)-\(self.identifier)") != nil
  }

  func saveValue(_ value: Int, for command: Command) {
    self.prefs.set(value, forKey: "\(command.rawValue)-\(self.identifier)")
  }

  func saveMaxValue(_ maxValue: Int, for command: Command) {
    self.prefs.set(maxValue, forKey: "max-\(command.rawValue)-\(self.identifier)")
  }

  func getMaxValue(for command: Command) -> Int {
    let max = self.prefs.integer(forKey: "max-\(command.rawValue)-\(self.identifier)")
    return min(self.DDC_HARD_MAX_LIMIT, max == 0 ? self.DDC_HARD_MAX_LIMIT : max)
  }

  func getRestoreValue(for command: Command) -> Int {
    return self.prefs.integer(forKey: "restore-\(command.rawValue)-\(self.identifier)")
  }

  func setRestoreValue(_ value: Int?, for command: Command) {
    self.prefs.set(value, forKey: "restore-\(command.rawValue)-\(self.identifier)")
  }

  func setPollingMode(_ value: Int) {
    self.prefs.set(String(value), forKey: "pollingMode-\(self.identifier)")
  }

  /*
   Polling Modes:
   0 -> .none     -> 0 tries
   1 -> .minimal  -> 5 tries
   2 -> .normal   -> 10 tries
   3 -> .heavy    -> 100 tries
   4 -> .custom   -> $pollingCount tries
   */
  func getPollingMode() -> Int {
    // Reading as string so we don't get "0" as the default value
    return Int(self.prefs.string(forKey: "pollingMode-\(self.identifier)") ?? "2") ?? 2
  }

  func getPollingCount() -> Int {
    let selectedMode = self.getPollingMode()
    switch selectedMode {
    case 0:
      return Utils.PollingMode.none.value
    case 1:
      return Utils.PollingMode.minimal.value
    case 2:
      return Utils.PollingMode.normal.value
    case 3:
      return Utils.PollingMode.heavy.value
    case 4:
      let val = self.prefs.integer(forKey: "pollingCount-\(self.identifier)")
      return Utils.PollingMode.custom(value: val).value
    default:
      return 0
    }
  }

  func setPollingCount(_ value: Int) {
    self.prefs.set(value, forKey: "pollingCount-\(self.identifier)")
  }

  private func stepSize(for command: Command, isSmallIncrement: Bool) -> Int {
    return isSmallIncrement ? 1 : Int(floor(Float(self.getMaxValue(for: command)) / OSDUtils.chicletCount))
  }

  override func showOsd(command: Command, value: Int, maxValue _: Int = 100, roundChiclet: Bool = false, lock: Bool = false) {
    super.showOsd(command: command, value: value, maxValue: self.getMaxValue(for: command), roundChiclet: roundChiclet, lock: lock)
  }

  private var audioPlayer: AVAudioPlayer?

  func playVolumeChangedSound() {
    // Check if user has enabled "Play feedback when volume is changed" in Sound Preferences
    guard let preferences = Utils.getSystemPreferences(), let hasSoundEnabled = preferences["com.apple.sound.beep.feedback"] as? Int, hasSoundEnabled == 1
    else {
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
