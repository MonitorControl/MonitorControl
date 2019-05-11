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

    _ = self.ddc?.write(command: .osd, value: UInt16(1))
    _ = self.ddc?.write(command: .osd, value: UInt16(1))
  }

  func mute() {
    var value = 0
    if self.isMuted {
      value = self.getValue(for: DDC.Command.audioSpeakerVolume)
      self.isMuted = false
    } else {
      self.isMuted = true
    }

    DispatchQueue.global(qos: .userInitiated).async {
      guard self.ddc?.write(command: .audioSpeakerVolume, value: UInt16(value)) == true else {
        return
      }

      self.hideDisplayOsd()
      self.showOsd(command: .audioSpeakerVolume, value: value)
    }

    if let slider = volumeSliderHandler?.slider {
      slider.intValue = Int32(value)
    }
  }

  func setVolume(to value: Int) {
    if value > 0 {
      self.isMuted = false
    }

    DispatchQueue.global(qos: .userInitiated).async {
      guard self.ddc?.write(command: .audioSpeakerVolume, value: UInt16(value)) == true else {
        return
      }

      self.hideDisplayOsd()
      self.showOsd(command: .audioSpeakerVolume, value: value)
    }

    if let slider = volumeSliderHandler?.slider {
      slider.intValue = Int32(value)
    }

    self.saveValue(value, for: .audioSpeakerVolume)
  }

  func setBrightness(to value: Int) {
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

      self.showOsd(command: .brightness, value: value)
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

  private func showOsd(command: DDC.Command, value: Int) {
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

    let step = maxValue / 16

    manager.showImage(osdImage,
                      onDisplayID: self.identifier,
                      priority: 0x1F4,
                      msecUntilFade: 1000,
                      filledChiclets: UInt32(value / step),
                      totalChiclets: UInt32(maxValue / step),
                      locked: false)
  }
}
