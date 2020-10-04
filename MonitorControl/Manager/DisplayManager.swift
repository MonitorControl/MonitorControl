import Cocoa
import DDC

class DisplayManager {
    public static let shared = DisplayManager()
    var timer = Timer()

    private var displays: [Display] {
        didSet {
            NotificationCenter.default.post(name: Notification.Name(Utils.PrefKeys.displayListUpdate.rawValue), object: nil)
        }
    }

    init() {
        displays = []
    }

    func updateDisplays(displays: [Display]) {
        self.displays = displays
    }

    func getAllDisplays() -> [Display] {
        return displays
    }

    func getDdcCapableDisplays() -> [ExternalDisplay] {
        return displays.compactMap { (display) -> ExternalDisplay? in
            if let externalDisplay = display as? ExternalDisplay, externalDisplay.ddc != nil {
                return externalDisplay
            } else { return nil }
        }
    }

    func getBuiltInDisplay() -> Display? {
        return displays.first { $0 is InternalDisplay }
    }

    func getCurrentDisplay() -> Display? {
        guard let mainDisplayID = NSScreen.main?.displayID else {
            return nil
        }
        return displays.first { $0.identifier == mainDisplayID }
    }

    func addDisplay(display: Display) {
        displays.append(display)
    }

    func updateDisplay(display updatedDisplay: Display) {
        if let indexToUpdate = displays.firstIndex(of: updatedDisplay) {
            displays[indexToUpdate] = updatedDisplay
        }
    }

    func clearDisplays() {
        displays = []
    }
}

extension DisplayManager {
    func startSync() {
        timer.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.sync()
        }
    }

    func stopSync() {
        timer.invalidate()
    }

    private func clampBrightness(_ value: Int) -> Int {
        var minBrightness = prefs.integer(forKey: Utils.PrefKeys.minSyncBrightness.rawValue)
        var maxBrightness = prefs.integer(forKey: Utils.PrefKeys.maxSyncBrightness.rawValue)
        if maxBrightness == 0 && minBrightness == 0 {
            minBrightness = 0
            maxBrightness = 100
        }

        if maxBrightness <= minBrightness {
            maxBrightness = 100
        }

        return min(max(value, minBrightness), maxBrightness)
    }

    @objc func sync() {
        let brightness = (DisplayManager.shared.getBuiltInDisplay() as! InternalDisplay).getBrightness()
        var value = Int(brightness * 100)
        for ddcDisplay in DisplayManager.shared.getDdcCapableDisplays() {
            value = clampBrightness(value)
            if abs(ddcDisplay.getValue(for: .brightness) - value) > 2 {
                print("write", value)
                _ = ddcDisplay.ddc!.write(command: DDC.Command.brightness, value: UInt16(value), errorRecoveryWaitTime: UInt32(3))
                ddcDisplay.saveValue(value, for: .brightness)
            }
            ddcDisplay.brightnessSliderHandler?.slider?.intValue = Int32(value)
        }
    }
}
