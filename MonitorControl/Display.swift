import Cocoa
import DDC

class Display {
  let identifier: CGDirectDisplayID
  let name: String
  var isEnabled: Bool
  var isMuted: Bool = false
  var brightnessSliderHandler: SliderHandler?
  var volumeSliderHandler: SliderHandler?
  var contrastSliderHandler: SliderHandler?
  var ddc: DDC?

  private let prefs = UserDefaults.standard

  init(_ identifier: CGDirectDisplayID, name: String, isEnabled: Bool = true) {
    self.identifier = identifier
    self.name = name
    self.isEnabled = isEnabled
    self.ddc = DDC(for: identifier)
  }

  // On some displays, the display's OSD overlaps the macOS OSD,
  // calling the OSD command with 1 seems to hide it.
  func hideDisplayOsd() {
    guard self.hideOsd else {
      return
    }

    _ = self.ddc?.write(command: .onScreenDisplay, value: 1)

    DispatchQueue.global(qos: .background).asyncAfter(deadline: DispatchTime.now() + 0.000001) {
      _ = self.ddc?.write(command: .onScreenDisplay, value: 1)
    }

    DispatchQueue.global(qos: .background).asyncAfter(deadline: DispatchTime.now() + 0.00001) {
      _ = self.ddc?.write(command: .onScreenDisplay, value: 1)
    }

    DispatchQueue.global(qos: .background).asyncAfter(deadline: DispatchTime.now() + 0.0001) {
      _ = self.ddc?.write(command: .onScreenDisplay, value: 1)
    }
  }

  func mute() {
    var value = 0
    if self.isMuted {
      value = self.prefs.integer(forKey: "\(DDC.Command.audioSpeakerVolume.value)-\(self.identifier)")
      self.isMuted = false
    } else {
      self.isMuted = true
    }

    _ = self.ddc?.write(command: .audioSpeakerVolume, value: UInt8(value))
    self.hideDisplayOsd()

    if let slider = volumeSliderHandler?.slider {
      slider.intValue = Int32(value)
    }

    self.showOsd(command: .audioSpeakerVolume, value: value)
  }

  func setVolume(to value: Int) {
    if value > 0 {
      self.isMuted = false
    }

    _ = self.ddc?.write(command: .audioSpeakerVolume, value: UInt8(value))
    self.hideDisplayOsd()

    if let slider = volumeSliderHandler?.slider {
      slider.intValue = Int32(value)
    }

    self.showOsd(command: .audioSpeakerVolume, value: value)
    self.saveValue(value, for: .audioSpeakerVolume)
  }

  func setBrightness(to value: Int) {
    if self.prefs.bool(forKey: Utils.PrefKeys.lowerContrast.rawValue) {
      if value == 0 {
        _ = self.ddc?.write(command: .contrast, value: UInt8(value))

        if let slider = contrastSliderHandler?.slider {
          slider.intValue = Int32(value)
        }
      } else if self.prefs.integer(forKey: "\(DDC.Command.brightness.value)-\(self.identifier)") == 0 {
        let contrastValue = self.prefs.integer(forKey: "\(DDC.Command.contrast.value)-\(self.identifier)")
        _ = self.ddc?.write(command: .contrast, value: UInt8(contrastValue))
      }
    }

    _ = self.ddc?.write(command: .brightness, value: UInt8(value))

    if let slider = brightnessSliderHandler?.slider {
      slider.intValue = Int32(value)
    }

    self.showOsd(command: .brightness, value: value)
    self.saveValue(value, for: .brightness)
  }

  func calcNewValue(for command: DDC.Command, withRel rel: Int) -> Int {
    let currentValue = self.prefs.integer(forKey: "\(command)-\(self.identifier)")
    return max(0, min(100, currentValue + rel))
  }

  func saveValue(_ value: Int, for command: DDC.Command) {
    self.prefs.set(value, forKey: "\(command)-\(self.identifier)")
  }

  private func showOsd(command: DDC.Command, value: Int) {
    if let manager = OSDManager.sharedManager() as? OSDManager {
      var osdImage: Int64 = 1 // Brightness Image
      if command == .audioSpeakerVolume {
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
