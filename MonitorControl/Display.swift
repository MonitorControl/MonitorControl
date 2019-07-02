import AVFoundation
import Cocoa
import DDC
import os.log

class Display: Equatable {
  static func == (lhs: Display, rhs: Display) -> Bool {
    return lhs.identifier == rhs.identifier
  }

  let identifier: CGDirectDisplayID
  let name: String
  let isBuiltin: Bool
  var isEnabled: Bool
  var isMuted: Bool = false
  var brightnessSliderHandler: SliderHandler?
  var volumeSliderHandler: SliderHandler?
  var contrastSliderHandler: SliderHandler?
  var ddc: DDC?

  private let prefs = UserDefaults.standard
  private var audioPlayer: AVAudioPlayer?

  init(_ identifier: CGDirectDisplayID, name: String, isBuiltin: Bool, isEnabled: Bool = true) {
    self.identifier = identifier
    self.name = name
    self.isEnabled = isBuiltin ? false : isEnabled
    self.ddc = DDC(for: identifier)
    self.isBuiltin = isBuiltin
    self.isMuted = self.getValue(for: .audioMuteScreenBlank) == 1
  }

  // On some displays, the display's OSD overlaps the macOS OSD,
  // calling the OSD command with 1 seems to hide it.
  func hideDisplayOsd() {
    guard self.hideOsd else {
      return
    }

    for _ in 0..<20 {
      _ = self.ddc?.write(command: .osd, value: UInt16(1), errorRecoveryWaitTime: 2000)
    }
  }

  func mute(forceVolume: Int? = nil) {
    var value = 0

    if self.isMuted, forceVolume == nil || forceVolume! > 0 {
      value = forceVolume ?? self.getValue(for: .audioSpeakerVolume)
      self.saveValue(value, for: .audioSpeakerVolume)

      self.isMuted = false
    } else if !self.isMuted, forceVolume == nil || forceVolume == 0 {
      self.isMuted = true
    }

    DispatchQueue.global(qos: .userInitiated).async {
      let muteValue = self.isMuted ? 1 : 2
      guard self.ddc?.write(command: .audioMuteScreenBlank, value: UInt16(muteValue), errorRecoveryWaitTime: self.hideOsd ? 0 : nil) == true else {
        self.setVolume(to: value)
        return
      }

      if forceVolume == nil || forceVolume == 0 {
        self.hideDisplayOsd()
        self.showOsd(command: .audioSpeakerVolume, value: value)
        self.playVolumeChangedSound()
      }

      self.saveValue(muteValue, for: .audioMuteScreenBlank)
    }

    if let slider = volumeSliderHandler?.slider {
      slider.intValue = Int32(value)
    }
  }

  func setVolume(to value: Int, isSmallIncrement: Bool = false) {
    if value > 0, self.isMuted {
      self.mute(forceVolume: value)
    } else if value == 0 {
      self.mute(forceVolume: 0)
      return
    }

    DispatchQueue.global(qos: .userInitiated).async {
      guard self.ddc?.write(command: .audioSpeakerVolume, value: UInt16(value), errorRecoveryWaitTime: self.hideOsd ? 0 : nil) == true else {
        return
      }

      self.hideDisplayOsd()
      self.showOsd(command: .audioSpeakerVolume, value: value, isSmallIncrement: isSmallIncrement)
      self.playVolumeChangedSound()
    }

    if let slider = volumeSliderHandler?.slider {
      slider.intValue = Int32(value)
    }

    self.saveValue(value, for: .audioSpeakerVolume)
  }

  func setBrightness(to value: Int, isSmallIncrement: Bool = false) {
    if self.prefs.bool(forKey: Utils.PrefKeys.lowerContrast.rawValue) {
      if value == 0 {
        DispatchQueue.global(qos: .userInitiated).async {
          _ = self.ddc?.write(command: .contrast, value: UInt16(value))
        }

        if let slider = contrastSliderHandler?.slider {
          slider.intValue = Int32(value)
        }
      } else if self.getValue(for: DDC.Command.brightness) == 0 {
        let contrastValue = self.getValue(for: DDC.Command.contrast)

        DispatchQueue.global(qos: .userInitiated).async {
          _ = self.ddc?.write(command: .contrast, value: UInt16(contrastValue))
        }
      }
    }

    DispatchQueue.global(qos: .userInitiated).async {
      guard self.ddc?.write(command: .brightness, value: UInt16(value)) == true else {
        return
      }

      self.showOsd(command: .brightness, value: value, isSmallIncrement: isSmallIncrement)
    }

    if let slider = brightnessSliderHandler?.slider {
      slider.intValue = Int32(value)
    }

    self.saveValue(value, for: .brightness)
  }

  func calcNewValue(for command: DDC.Command, withRel rel: Int) -> Int {
    let currentValue = self.getValue(for: command)
    return max(0, min(self.getMaxValue(for: command), currentValue + rel))
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

  func setFriendlyName(_ value: String) {
    self.prefs.set(value, forKey: "friendlyName-\(self.identifier)")
  }

  func getFriendlyName() -> String {
    return self.prefs.string(forKey: "friendlyName-\(self.identifier)") ?? self.name
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

  private func showOsd(command: DDC.Command, value: Int, isSmallIncrement: Bool = false) {
    guard let manager = OSDManager.sharedManager() as? OSDManager else {
      return
    }

    let maxValue = self.getMaxValue(for: command)

    var osdImage: Int64 = 1 // Brightness Image
    if command == .audioSpeakerVolume {
      osdImage = 3 // Speaker image
      if self.isMuted {
        osdImage = 4 // Mute speaker
      }
    }

    let step = isSmallIncrement ? maxValue / maxValue : maxValue / 16

    manager.showImage(osdImage,
                      onDisplayID: self.identifier,
                      priority: 0x1F4,
                      msecUntilFade: 1000,
                      filledChiclets: UInt32(value / step),
                      totalChiclets: UInt32(maxValue / step),
                      locked: false)
  }

  private func playVolumeChangedSound() {
    let soundPath = "/System/Library/LoginPlugins/BezelServices.loginPlugin/Contents/Resources/volume.aiff"
    let soundUrl = URL(fileURLWithPath: soundPath)

    // Check if user has enabled "Play feedback when volume is changed" in Sound Preferences
    guard let preferences = Utils.getSystemPreferences(),
      let hasSoundEnabled = preferences["com.apple.sound.beep.feedback"] as? Int,
      hasSoundEnabled == 1 else {
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
