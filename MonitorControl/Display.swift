import Cocoa

class Display {
  let identifier: CGDirectDisplayID
  let name: String
  let serial: String
  var isEnabled: Bool
  var isMuted: Bool = false
  var brightnessSliderHandler: SliderHandler?
  var volumeSliderHandler: SliderHandler?
  var contrastSliderHandler: SliderHandler?

  private let prefs = UserDefaults.standard

  init(_ identifier: CGDirectDisplayID, name: String, serial: String, isEnabled: Bool = true) {
    self.identifier = identifier
    self.name = name
    self.serial = serial
    self.isEnabled = isEnabled
  }

  func mute() {
    var value = 0
    if self.isMuted {
      value = self.prefs.integer(forKey: "\(AUDIO_SPEAKER_VOLUME)-\(self.identifier)")
      self.isMuted = false
    } else {
      self.isMuted = true
    }

    Utils.sendCommand(AUDIO_SPEAKER_VOLUME, toMonitor: self.identifier, withValue: value)
    if let slider = volumeSliderHandler?.slider {
      slider.intValue = Int32(value)
    }
    self.showOsd(command: AUDIO_SPEAKER_VOLUME, value: value)
  }

  func setVolume(to value: Int) {
    if value > 0 {
      self.isMuted = false
    }

    Utils.sendCommand(AUDIO_SPEAKER_VOLUME, toMonitor: self.identifier, withValue: value)
    if let slider = volumeSliderHandler?.slider {
      slider.intValue = Int32(value)
    }
    self.showOsd(command: AUDIO_SPEAKER_VOLUME, value: value)
    self.saveValue(value, for: AUDIO_SPEAKER_VOLUME)
  }

  func setBrightness(to value: Int) {
    if self.prefs.bool(forKey: Utils.PrefKeys.lowerContrast.rawValue) {
      if value == 0 {
        Utils.sendCommand(CONTRAST, toMonitor: self.identifier, withValue: value)
        if let slider = contrastSliderHandler?.slider {
          slider.intValue = Int32(value)
        }
      } else if self.prefs.integer(forKey: "\(BRIGHTNESS)-\(self.identifier)") == 0 {
        let contrastValue = self.prefs.integer(forKey: "\(CONTRAST)-\(self.identifier)")
        Utils.sendCommand(CONTRAST, toMonitor: self.identifier, withValue: contrastValue)
      }
    }

    Utils.sendCommand(BRIGHTNESS, toMonitor: self.identifier, withValue: value)
    if let slider = brightnessSliderHandler?.slider {
      slider.intValue = Int32(value)
    }
    self.showOsd(command: BRIGHTNESS, value: value)
    self.saveValue(value, for: BRIGHTNESS)
  }

  func calcNewValue(for command: Int32, withRel rel: Int) -> Int {
    let currentValue = self.prefs.integer(forKey: "\(command)-\(self.identifier)")
    return max(0, min(100, currentValue + rel))
  }

  func saveValue(_ value: Int, for command: Int32) {
    self.prefs.set(value, forKey: "\(command)-\(self.identifier)")
  }

  private func showOsd(command: Int32, value: Int) {
    if let manager = OSDManager.sharedManager() as? OSDManager {
      var osdImage: Int64 = 1 // Brightness Image
      if command == AUDIO_SPEAKER_VOLUME {
        osdImage = 3 // Speaker image
        if self.isMuted {
          osdImage = 4 // Mute speaker
        }
      }
      let step = 100 / 16
      manager.showImage(osdImage,
                        onDisplayID: self.identifier,
                        priority: 0x1F4,
                        msecUntilFade: 2000,
                        filledChiclets: UInt32(value / step),
                        totalChiclets: UInt32(100 / step),
                        locked: false)
    }
  }
}
