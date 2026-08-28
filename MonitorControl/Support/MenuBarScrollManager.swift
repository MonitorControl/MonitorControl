//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Cocoa
import Foundation
import os.log

class MenuBarScrollManager {
  private let preciseDeltaPerStep: Float = 8 // Accumulated scroll distance (in points) needed for a step on precise devices
  private let maxStepsPerEvent = 3 // Safety limit so a fast wheel spin does not flood the displays with commands

  private let osd = MenuBarScrollOsd()
  private var eventMonitor: Any?
  private var accumulatedDelta: Float = 0

  init() {
    self.updateRegistration()
  }

  deinit {
    self.stop()
  }

  func updateRegistration() {
    if prefs.bool(forKey: PrefKey.disableMenuBarScroll.rawValue) {
      self.stop()
    } else {
      self.start()
    }
  }

  private func start() {
    guard self.eventMonitor == nil else {
      return
    }
    os_log("Starting menu bar icon scroll monitoring", type: .info)
    self.eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
      guard let self = self, self.isEventOverStatusItem(event) else {
        return event
      }
      self.handle(event)
      return nil
    }
  }

  private func stop() {
    if let eventMonitor = self.eventMonitor {
      os_log("Stopping menu bar icon scroll monitoring", type: .info)
      NSEvent.removeMonitor(eventMonitor)
      self.eventMonitor = nil
    }
    self.accumulatedDelta = 0
  }

  private func isEventOverStatusItem(_ event: NSEvent) -> Bool {
    guard let button = app.statusItem.button, let buttonWindow = button.window, event.window === buttonWindow else {
      return false
    }
    return button.bounds.contains(button.convert(event.locationInWindow, from: nil))
  }

  private func handle(_ event: NSEvent) {
    guard app.sleepID == 0, app.reconfigureID == 0 else {
      self.accumulatedDelta = 0
      return
    }
    let steps = self.stepCount(for: event)
    guard steps != 0 else {
      return
    }
    for _ in 0 ..< abs(steps) {
      self.stepBrightness(isUp: steps > 0)
    }
  }

  // Positive return value means brighter, negative means dimmer. Scrolling up (away from the user) always brightens,
  // irrespective of the natural scrolling setting of the pointing device.
  private func stepCount(for event: NSEvent) -> Int {
    var delta = Float(event.scrollingDeltaY)
    guard delta != 0 else {
      return 0
    }
    if event.isDirectionInvertedFromDevice {
      delta = -delta
    }
    guard event.hasPreciseScrollingDeltas else {
      self.accumulatedDelta = 0
      return min(self.maxStepsPerEvent, max(1, Int(abs(delta).rounded()))) * (delta > 0 ? 1 : -1)
    }
    if self.accumulatedDelta != 0, (self.accumulatedDelta > 0) != (delta > 0) {
      self.accumulatedDelta = 0 // Direction changed, start over to avoid a lingering opposite direction step
    }
    self.accumulatedDelta += delta
    let steps = Int(self.accumulatedDelta / self.preciseDeltaPerStep)
    guard steps != 0 else {
      return 0
    }
    self.accumulatedDelta -= Float(steps) * self.preciseDeltaPerStep
    return min(self.maxStepsPerEvent, abs(steps)) * (steps > 0 ? 1 : -1)
  }

  private func stepBrightness(isUp: Bool) {
    guard let affectedDisplays = DisplayManager.shared.getAffectedDisplays(isBrightness: true, isVolume: false) else {
      return
    }
    var displayForOsd: Display?
    for display in affectedDisplays where !display.readPrefAsBool(key: .isDisabled) {
      var isAnyDisplayInSwAfterBrightnessMode = false
      for display in affectedDisplays where ((display as? OtherDisplay)?.isSwBrightnessNotDefault() ?? false) && !((display as? OtherDisplay)?.isSw() ?? false) && prefs.bool(forKey: PrefKey.separateCombinedScale.rawValue) {
        isAnyDisplayInSwAfterBrightnessMode = true
      }
      if !(isAnyDisplayInSwAfterBrightnessMode && !(((display as? OtherDisplay)?.isSwBrightnessNotDefault() ?? false) && !((display as? OtherDisplay)?.isSw() ?? false))) {
        self.stepBrightnessByOnePercent(display, isUp: isUp)
        if displayForOsd == nil || display.identifier == DisplayManager.shared.getCurrentDisplay(byFocus: false)?.identifier {
          displayForOsd = display
        }
      }
    }
    if let displayForOsd = displayForOsd {
      self.osd.show(value: displayForOsd.getBrightness())
    }
  }

  // Scrolling gives exact one percentage point steps, snapped to whole percents so repeated steps stay on round values.
  // The system OSD is skipped, the custom HUD is shown instead.
  private func stepBrightnessByOnePercent(_ display: Display, isUp: Bool) {
    guard !display.readPrefAsBool(key: .unavailableDDC, for: .brightness) else {
      return
    }
    let currentPercent = (display.getBrightness() * 100).rounded()
    let value = min(1, max(0, (currentPercent + (isUp ? 1 : -1)) / 100))
    guard display.setBrightness(value) else {
      return
    }
    if let slider = display.sliderHandler[.brightness] {
      slider.setValue(value, displayID: display.identifier)
      display.brightnessSyncSourceValue = value
    }
  }
}
