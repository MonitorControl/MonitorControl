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

    @objc func sync() {
        // TODO: If value doesn't varies much from external to internal display, don't change brightness.
        let brightness = (DisplayManager.shared.getBuiltInDisplay() as! InternalDisplay).getBrightness()
        for ddcDisplay in DisplayManager.shared.getDdcCapableDisplays() {
            var value = Int(brightness * 100)
            value = max(20, value)
            if abs(ddcDisplay.getValue(for: .brightness) - value) > 5 {
                print("write")
                _ = ddcDisplay.ddc!.write(command: DDC.Command.brightness, value: UInt16(value), errorRecoveryWaitTime: UInt32(3))
                ddcDisplay.saveValue(value, for: .brightness)
            }
        }
    }
}
