import AVFoundation
import Cocoa
import DDC
import os.log
import IOKit

class ExternalDisplay: Display {
  var brightnessSliderHandler: SliderHandler?
  var volumeSliderHandler: SliderHandler?
  var contrastSliderHandler: SliderHandler?
  var ddc: DDC?
  var m1ddc: Bool = false
  var m1avService: IOAVService?

  private let prefs = UserDefaults.standard
  
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

  private var audioPlayer: AVAudioPlayer?

  override init(_ identifier: CGDirectDisplayID, name: String, vendorNumber: UInt32?, modelNumber: UInt32?) {
    super.init(identifier, name: name, vendorNumber: vendorNumber, modelNumber: modelNumber)

    #if arch(arm64)
    
    // MARK: Implement proper IOAVService matching and DDC detection
  
    self.m1avService = IOAVServiceCreate(kCFAllocatorDefault)?.takeRetainedValue() as IOAVService
    self.m1ddc = true

    #else
    
    self.ddc = DDC(for: identifier)

    #endif
    
  }
  
  // On some displays, the display's OSD overlaps the macOS OSD,
  // calling the OSD command with 1 seems to hide it.
  func hideDisplayOsd() {
    guard self.hideOsd else {
      return
    }

    for _ in 0 ..< 20 {
      _ = writeDDCValues(command: .osd, value: UInt16(1), errorRecoveryWaitTime: 2000)
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

    guard writeDDCValues(command: .audioSpeakerVolume, value: volumeDDCValue) == true else {
      return
    }

    if self.supportsMuteCommand() {
      guard writeDDCValues(command: .audioMuteScreenBlank, value: UInt16(muteValue)) == true else {
        return
      }
    }

    self.saveValue(muteValue, for: .audioMuteScreenBlank)

    if !fromVolumeSlider {
      self.hideDisplayOsd()
      self.showOsd(command: volumeOSDValue > 0 ? .audioSpeakerVolume : .audioMuteScreenBlank, value: volumeOSDValue, roundChiclet: true)

      if volumeOSDValue > 0 {
        self.playVolumeChangedSound()
      }

      if let slider = self.volumeSliderHandler?.slider {
        slider.intValue = Int32(volumeDDCValue)
      }
    }
  }

  func stepVolume(isUp: Bool, isSmallIncrement: Bool) {
    var muteValue: Int?
    let volumeOSDValue = self.calcNewValue(for: .audioSpeakerVolume, isUp: isUp, isSmallIncrement: isSmallIncrement)
    let volumeDDCValue = UInt16(volumeOSDValue)
    if self.isMuted(), volumeOSDValue > 0 {
      muteValue = 2
    } else if !self.isMuted(), volumeOSDValue == 0 {
      muteValue = 1
    }

    let isAlreadySet = volumeOSDValue == self.getValue(for: .audioSpeakerVolume)

    if !isAlreadySet {
      guard writeDDCValues(command: .audioSpeakerVolume, value: volumeDDCValue) == true else {
        return
      }
    }

    if let muteValue = muteValue {
      // If the mute command is supported, set its value accordingly
      if self.supportsMuteCommand() {
        guard writeDDCValues(command: .audioMuteScreenBlank, value: UInt16(muteValue)) == true else {
          return
        }
      }
      self.saveValue(muteValue, for: .audioMuteScreenBlank)
    }

    self.hideDisplayOsd()
    self.showOsd(command: .audioSpeakerVolume, value: volumeOSDValue, roundChiclet: !isSmallIncrement)

    if !isAlreadySet {
      self.saveValue(volumeOSDValue, for: .audioSpeakerVolume)

      if volumeOSDValue > 0 {
        self.playVolumeChangedSound()
      }

      if let slider = self.volumeSliderHandler?.slider {
        slider.intValue = Int32(volumeDDCValue)
      }
    }
  }

  override func stepBrightness(isUp: Bool, isSmallIncrement: Bool) {
    let osdValue = Int(self.calcNewValue(for: .brightness, isUp: isUp, isSmallIncrement: isSmallIncrement))
    let isAlreadySet = osdValue == self.getValue(for: .brightness)
    let ddcValue = UInt16(osdValue)

    // Set the contrast value according to the brightness, if necessary
    if !isAlreadySet {
      self.setContrastValueForBrightness(osdValue)
    }

    if !isAlreadySet {
      guard writeDDCValues(command: .brightness, value: ddcValue) == true else {
        return
      }
    }

    self.showOsd(command: .brightness, value: osdValue, roundChiclet: !isSmallIncrement)

    if !isAlreadySet {
      if let slider = self.brightnessSliderHandler?.slider {
        slider.intValue = Int32(ddcValue)
      }

      self.saveValue(osdValue, for: .brightness)
    }
  }

  func setContrastValueForBrightness(_ brightness: Int) {
    var contrastValue: Int?

    if brightness == 0 {
      contrastValue = 0

      // Save the current DDC value for contrast so it can be restored, even across app restarts
      if self.getRestoreValue(for: .contrast) == 0 {
        self.setRestoreValue(self.getValue(for: .contrast), for: .contrast)
      }
    } else if self.getValue(for: .brightness) == 0, brightness > 0 {
      contrastValue = self.getRestoreValue(for: .contrast)
    }

    // Only write the new contrast value if lowering contrast after brightness is enabled
    if let contrastValue = contrastValue, self.prefs.bool(forKey: Utils.PrefKeys.lowerContrast.rawValue) {
      _ = writeDDCValues(command: .contrast, value: UInt16(contrastValue))
      self.saveValue(contrastValue, for: .contrast)

      if let slider = contrastSliderHandler?.slider {
        slider.intValue = Int32(contrastValue)
      }
    }
  }

  public func writeDDCValues(command: DDC.Command, value: UInt16, errorRecoveryWaitTime: UInt32? = nil) -> Bool? {
    
    #if arch(arm64)

    // MARK: This must be a litle bit more sophisticated, now we just assume everything went fine...
    
    var data = [UInt8](repeating: 0, count: 6)
  
    data[0] = 0x84
    data[1] = 0x03
    data[2] = command.rawValue
    data[3] = UInt8(value >> 8)
    data[4] = UInt8(value & 255)
    data[5] = 0x6E ^ 0x51 ^ data[0] ^ data[1] ^ data[2] ^ data[3] ^ data[4]

    for _ in 1...2 {
      usleep(2000)
      IOAVServiceWriteI2C(self.m1avService, 0x37, 0x51, &data,  6)
    }
        
    return true
    
    #else
    
    return self.ddc?.write(command: command, value: UInt16(1), errorRecoveryWaitTime: 2000)
    
    #endif
    
  }

  func readDDCValues(for command: DDC.Command, tries: UInt, minReplyDelay delay: UInt64?) -> (current: UInt16, max: UInt16)? {
    var values: (UInt16, UInt16)?
    
    #if arch(arm64)

    // MARK: This is rather rudimentary and assumes everything goes well...
    
    var data = [UInt8](repeating: 0, count: 6)
    var read = [UInt8](repeating: 0, count: 12)

    data[0] = 0x82
    data[1] = 0x01
    data[2] = command.rawValue
    data[3] = 0x6e ^ data[0] ^ data[1] ^ data[2] ^ data[3]

    for _ in 1...2 {
      usleep(2000)
      IOAVServiceWriteI2C(self.m1avService, 0x37, 0x51, &data,  6)
    }
        
    usleep(2000)
    IOAVServiceReadI2C(self.m1avService, 0x37, 0x51, &read, 12);
    
    values = (UInt16(read[9]), UInt16(read[7]))

    #else
    
    if self.ddc?.supported(minReplyDelay: delay) == true {
      os_log("Display supports DDC.", type: .debug)
    } else {
      os_log("Display does not support DDC.", type: .debug)
    }

    if self.ddc?.enableAppReport() == true {
      os_log("Display supports enabling DDC application report.", type: .debug)
    } else {
      os_log("Display does not support enabling DDC application report.", type: .debug)
    }

    values = self.ddc?.read(command: command, tries: tries, minReplyDelay: delay)

    #endif
    
    return values
    
  }

  func calcNewValue(for command: DDC.Command, isUp: Bool, isSmallIncrement: Bool) -> Int {
    let currentValue = self.getValue(for: command)
    let nextValue: Int
    let maxValue = Float(self.getMaxValue(for: command))

    if isSmallIncrement {
      nextValue = currentValue + (isUp ? 1 : -1)
    } else {
      let osdChicletFromValue = OSDUtils.chiclet(fromValue: Float(currentValue), maxValue: maxValue)

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

      nextValue = Int(round(OSDUtils.value(fromChiclet: nextFilledChiclet, maxValue: maxValue)))

      os_log("next: .value %{public}@/%{public}@, .osd %{public}@/%{public}@", type: .debug, String(nextValue), String(maxValue), String(nextFilledChiclet), String(OSDUtils.chicletCount))
    }
    return max(0, min(self.getMaxValue(for: command), nextValue))
  }

  func getValue(for command: DDC.Command) -> Int {
    return self.prefs.integer(forKey: "\(command.rawValue)-\(self.identifier)")
  }

  func saveValue(_ value: Int, for command: DDC.Command) {
    self.prefs.set(value, forKey: "\(command.rawValue)-\(self.identifier)")
  }

  func saveMaxValue(_ maxValue: Int, for command: DDC.Command) {
    self.prefs.set(maxValue, forKey: "max-\(command.rawValue)-\(self.identifier)")
  }

  func getMaxValue(for command: DDC.Command) -> Int {
    let max = self.prefs.integer(forKey: "max-\(command.rawValue)-\(self.identifier)")
    return max == 0 ? 100 : max
  }

  func getRestoreValue(for command: DDC.Command) -> Int {
    return self.prefs.integer(forKey: "restore-\(command.rawValue)-\(self.identifier)")
  }

  func setRestoreValue(_ value: Int?, for command: DDC.Command) {
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
      return PollingMode.none.value
    case 1:
      return PollingMode.minimal.value
    case 2:
      return PollingMode.normal.value
    case 3:
      return PollingMode.heavy.value
    case 4:
      let val = self.prefs.integer(forKey: "pollingCount-\(self.identifier)")
      return PollingMode.custom(value: val).value
    default:
      return 0
    }
  }

  func setPollingCount(_ value: Int) {
    self.prefs.set(value, forKey: "pollingCount-\(self.identifier)")
  }

  private func stepSize(for command: DDC.Command, isSmallIncrement: Bool) -> Int {
    return isSmallIncrement ? 1 : Int(floor(Float(self.getMaxValue(for: command)) / OSDUtils.chicletCount))
  }

  override func showOsd(command: DDC.Command, value: Int, maxValue _: Int = 100, roundChiclet: Bool = false) {
    super.showOsd(command: command, value: value, maxValue: self.getMaxValue(for: command), roundChiclet: roundChiclet)
  }

  private func supportsMuteCommand() -> Bool {
    // Monitors which don't support the mute command - e.g. Dell U3419W - will have a maximum value of 100 for the DDC mute command
    return self.getMaxValue(for: .audioMuteScreenBlank) == 2
  }

  private func playVolumeChangedSound() {
    let soundPath = "/System/Library/LoginPlugins/BezelServices.loginPlugin/Contents/Resources/volume.aiff"
    let soundUrl = URL(fileURLWithPath: soundPath)

    // Check if user has enabled "Play feedback when volume is changed" in Sound Preferences
    guard let preferences = Utils.getSystemPreferences(),
          let hasSoundEnabled = preferences["com.apple.sound.beep.feedback"] as? Int,
          hasSoundEnabled == 1
    else {
      os_log("sound not enabled", type: .info)
      return
    }

    do {
      self.audioPlayer = try AVAudioPlayer(contentsOf: soundUrl)
      self.audioPlayer?.volume = 1
      self.audioPlayer?.prepareToPlay()
      self.audioPlayer?.play()
    } catch {
      os_log("%{public}@", type: .error, error.localizedDescription)
    }
  }
}
