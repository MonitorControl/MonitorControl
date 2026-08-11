//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Cocoa
import CoreGraphics
import os.log
import SimplyCoreAudio

private enum EdgeScrollSide {
  case left
  case right
}

private func edgeScrollEventTapCallback(proxy _: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
  guard let refcon = refcon else {
    return Unmanaged.passUnretained(event)
  }
  let manager = Unmanaged<EdgeScrollManager>.fromOpaque(refcon).takeUnretainedValue()
  return manager.handleEventTap(type: type, event: event)
}

class EdgeScrollManager {
  private let edgeActivationWidth: CGFloat = 6
  private var eventTap: CFMachPort?
  private var runLoopSource: CFRunLoopSource?
  private var globalScrollMonitor: Any?
  private var localScrollMonitor: Any?
  private var preciseScrollRemainder: CGFloat = 0
  private let volumeSoundFeedbackInterval: TimeInterval = 0.12
  private var lastVolumeSoundFeedbackTime: TimeInterval = 0

  func update() {
    self.stop()
    guard self.isEnabled else {
      return
    }
    self.startEventTap()
    if self.eventTap == nil {
      self.startEventMonitors()
    }
  }

  private var isEnabled: Bool {
    self.action(for: .left) != .disabled || self.action(for: .right) != .disabled
  }

  private func stop() {
    if let eventTap = eventTap {
      CGEvent.tapEnable(tap: eventTap, enable: false)
    }
    if let runLoopSource = runLoopSource {
      CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
    }
    if let globalScrollMonitor = globalScrollMonitor {
      NSEvent.removeMonitor(globalScrollMonitor)
    }
    if let localScrollMonitor = localScrollMonitor {
      NSEvent.removeMonitor(localScrollMonitor)
    }
    self.eventTap = nil
    self.runLoopSource = nil
    self.globalScrollMonitor = nil
    self.localScrollMonitor = nil
    self.preciseScrollRemainder = 0
  }

  private func startEventTap() {
    let eventMask = CGEventMask(1 << CGEventType.scrollWheel.rawValue)
    guard let eventTap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: eventMask, callback: edgeScrollEventTapCallback, userInfo: Unmanaged.passUnretained(self).toOpaque()) else {
      os_log("Edge scroll event tap unavailable. Falling back to event monitors.", type: .info)
      return
    }
    self.eventTap = eventTap
    let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
    self.runLoopSource = runLoopSource
    CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
    CGEvent.tapEnable(tap: eventTap, enable: true)
  }

  private func startEventMonitors() {
    self.globalScrollMonitor = NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
      _ = self?.handleScroll(event)
    }
    self.localScrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
      if self?.handleScroll(event) == true {
        return nil
      }
      return event
    }
  }

  fileprivate func handleEventTap(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
      if let eventTap = self.eventTap {
        CGEvent.tapEnable(tap: eventTap, enable: true)
      }
      return Unmanaged.passUnretained(event)
    }
    guard type == .scrollWheel, let nsEvent = NSEvent(cgEvent: event) else {
      return Unmanaged.passUnretained(event)
    }
    return self.handleScroll(nsEvent) ? nil : Unmanaged.passUnretained(event)
  }

  private func handleScroll(_ event: NSEvent) -> Bool {
    guard app.sleepID == 0, app.reconfigureID == 0, let target = self.targetForMouseLocation(), target.display.readPrefAsBool(key: .isDisabled) == false else {
      return false
    }
    let selectedAction = self.action(for: target.side)
    guard selectedAction != .disabled else {
      return false
    }
    let stepCount = self.stepCount(from: event)
    guard stepCount != 0 else {
      return true
    }
    let delta = self.precision.step * Float(stepCount)
    switch selectedAction {
    case .brightness:
      target.display.adjustBrightness(by: delta)
    case .volume:
      if !self.adjustSystemVolume(by: delta, displayID: target.display.identifier) {
        return false
      }
    case .disabled:
      break
    }
    return true
  }

  private func adjustSystemVolume(by delta: Float, displayID: CGDirectDisplayID) -> Bool {
    guard let defaultDevice = app.coreAudio.defaultOutputDevice,
          defaultDevice.canSetVirtualMainVolume(scope: .output),
          let currentVolume = defaultDevice.virtualMainVolume(scope: .output) else {
      OSDUtils.showOsdVolumeDisabled(displayID: displayID)
      return false
    }
    let nextVolume = max(0, min(1, currentVolume + Float32(delta)))
    guard defaultDevice.setVirtualMainVolume(nextVolume, scope: .output) else {
      OSDUtils.showOsdVolumeDisabled(displayID: displayID)
      return false
    }
    OSDUtils.showOsdProgress(displayID: displayID, command: .audioSpeakerVolume, value: Float(nextVolume))
    self.playVolumeChangedSoundIfNeeded()
    return true
  }

  private func playVolumeChangedSoundIfNeeded() {
    guard prefs.bool(forKey: PrefKey.edgeScrollVolumeSoundFeedback.rawValue) else {
      return
    }
    let now = Date.timeIntervalSinceReferenceDate
    guard now - self.lastVolumeSoundFeedbackTime >= self.volumeSoundFeedbackInterval else {
      return
    }
    self.lastVolumeSoundFeedbackTime = now
    DispatchQueue.main.async {
      app.playVolumeChangedSound()
    }
  }

  private func action(for side: EdgeScrollSide) -> EdgeScrollAction {
    let prefKey = side == .left ? PrefKey.edgeScrollLeftAction : PrefKey.edgeScrollRightAction
    return EdgeScrollAction(rawValue: prefs.integer(forKey: prefKey.rawValue)) ?? .disabled
  }

  private var precision: EdgeScrollPrecision {
    EdgeScrollPrecision(rawValue: prefs.integer(forKey: PrefKey.edgeScrollPrecision.rawValue)) ?? .standard
  }

  private func stepCount(from event: NSEvent) -> Int {
    let scrollDelta = event.scrollingDeltaY
    guard abs(scrollDelta) > 0.01 else {
      return 0
    }
    if event.hasPreciseScrollingDeltas {
      self.preciseScrollRemainder += scrollDelta / 12
      guard abs(self.preciseScrollRemainder) >= 1 else {
        return 0
      }
      let steps = max(-3, min(3, Int(self.preciseScrollRemainder.rounded(.towardZero))))
      self.preciseScrollRemainder -= CGFloat(steps)
      return steps
    }
    let steps = max(1, min(3, Int(abs(scrollDelta).rounded(.towardZero))))
    return scrollDelta > 0 ? steps : -steps
  }

  private func targetForMouseLocation() -> (side: EdgeScrollSide, display: Display)? {
    let mouseLocation = NSEvent.mouseLocation
    guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }),
          let display = DisplayManager.shared.displays.first(where: { $0.identifier == screen.displayID }) else {
      return nil
    }
    if mouseLocation.x <= screen.frame.minX + self.edgeActivationWidth {
      return (.left, display)
    }
    if mouseLocation.x >= screen.frame.maxX - self.edgeActivationWidth {
      return (.right, display)
    }
    return nil
  }
}
