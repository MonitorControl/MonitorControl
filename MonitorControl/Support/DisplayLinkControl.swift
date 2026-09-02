//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import CoreGraphics
import Foundation
import os.log

struct DisplayLinkDisplay {
  let cgID: CGDirectDisplayID
  let persistentDisplayId: String
  let name: String
  let isEnabled: Bool
  let supportsBrightness: Bool
  let brightness: Float?
  let brightnessRequiresRestore: Bool
  let supportsContrast: Bool
  let contrast: Float?
  let contrastRequiresRestore: Bool
}

final class DisplayLinkControl {
  static let shared = DisplayLinkControl()
  static let displayDidUpdateNotification = Notification.Name("MonitorControl.DisplayLinkDisplayDidUpdate")
  static let userInfoDisplayIDKey = "displayID"
  static let userInfoBrightnessKey = "brightness"
  static let userInfoContrastKey = "contrast"

  private enum ControlKind: Hashable {
    case brightness
    case contrast

    var requestName: String {
      switch self {
      case .brightness: return "com.displaylink.SetBrightness"
      case .contrast: return "com.displaylink.SetContrast"
      }
    }

    var updateName: String {
      switch self {
      case .brightness: return "com.displaylink.BrightnessUpdated"
      case .contrast: return "com.displaylink.ContrastUpdated"
      }
    }

    var payloadKey: String {
      switch self {
      case .brightness: return "brightness"
      case .contrast: return "contrast"
      }
    }
  }

  private struct DisplayPayload: Decodable {
    let persistentDisplayId: String
    let isEnabled: Bool?
    let brightness: Float?
    let contrast: Float?
    let CGID: UInt32?
    let name: String?
  }

  private struct UpdatePayload: Decodable {
    let persistentDisplayId: String?
    let statusCode: Int?
    let brightness: Float?
    let contrast: Float?
  }

  private struct DisplayWriteKey: Hashable {
    let displayID: CGDirectDisplayID
    let kind: ControlKind
  }

  private struct LocalWriteTarget {
    let value: Float
    let createdAt: Date
  }

  private final class NotificationWaitState {
    private let lock = NSLock()
    private var notification: Notification?

    func store(_ notification: Notification) {
      self.lock.lock()
      defer { self.lock.unlock() }
      if self.notification == nil {
        self.notification = notification
      }
    }

    func value() -> Notification? {
      self.lock.lock()
      defer { self.lock.unlock() }
      return self.notification
    }
  }

  private let notificationCenter = DistributedNotificationCenter.default()
  private let timeout: TimeInterval = 1.5
  private let writeCoalescingDelay: TimeInterval = 0.08
  private let localWriteIgnoreInterval: TimeInterval = 3
  private let stateQueue = DispatchQueue(label: "MonitorControl DisplayLink state queue")
  private let writeQueue = DispatchQueue(label: "MonitorControl DisplayLink write queue")
  private var observerTokens: [NSObjectProtocol] = []
  private var displaysByID: [CGDirectDisplayID: DisplayLinkDisplay] = [:]
  private var displayIDsByPersistentID: [String: CGDirectDisplayID] = [:]
  private var lastKnownDisplaysByPersistentID: [String: DisplayLinkDisplay] = [:]
  private var pendingWrites: [DisplayWriteKey: Float] = [:]
  private var scheduledWrites: Set<DisplayWriteKey> = []
  private var localWriteTargets: [DisplayWriteKey: LocalWriteTarget] = [:]

  private init() {
    self.startObserving()
  }

  @discardableResult
  func refreshDisplays() -> [DisplayLinkDisplay] {
    guard !Thread.isMainThread else {
      os_log("DisplayLink display query skipped on the main thread.", type: .error)
      return self.stateQueue.sync {
        Array(self.displaysByID.values)
      }
    }
    let note = self.waitForNotification(name: "com.displaylink.DisplayListUpdated", timeout: self.timeout) {
      self.notificationCenter.postNotificationName(Notification.Name("com.displaylink.GetDisplays"), object: nil, userInfo: nil, deliverImmediately: true)
    }
    guard let raw = Self.objectString(note) else {
      os_log("DisplayLink display query timed out or returned no data.", type: .info)
      self.replaceDisplays([], notify: false)
      return []
    }
    guard let displays = Self.decodeDisplays(from: raw) else {
      os_log("DisplayLink display query returned unparseable payload: %{public}@", type: .error, raw)
      self.replaceDisplays([], notify: false)
      return []
    }
    let resolvedDisplays = self.replaceDisplays(displays, notify: false)
    os_log("DisplayLink display query found %{public}@ display(s).", type: .info, String(displays.count))
    return resolvedDisplays
  }

  func display(for displayID: CGDirectDisplayID) -> DisplayLinkDisplay? {
    self.stateQueue.sync {
      self.displaysByID[displayID]
    }
  }

  func setBrightness(for displayID: CGDirectDisplayID, value: Float) -> Bool {
    self.enqueueValue(kind: .brightness, for: displayID, value: value)
  }

  func setContrast(for displayID: CGDirectDisplayID, value: Float) -> Bool {
    self.enqueueValue(kind: .contrast, for: displayID, value: value)
  }

  private func startObserving() {
    self.observerTokens.append(self.notificationCenter.addObserver(forName: Notification.Name("com.displaylink.DisplayListUpdated"), object: nil, queue: .main) { [weak self] note in
      self?.handleDisplayListNotification(note)
    })
    self.observerTokens.append(self.notificationCenter.addObserver(forName: Notification.Name("com.displaylink.BrightnessUpdated"), object: nil, queue: .main) { [weak self] note in
      self?.handleUpdateNotification(note, kind: .brightness)
    })
    self.observerTokens.append(self.notificationCenter.addObserver(forName: Notification.Name("com.displaylink.ContrastUpdated"), object: nil, queue: .main) { [weak self] note in
      self?.handleUpdateNotification(note, kind: .contrast)
    })
  }

  private func enqueueValue(kind: ControlKind, for displayID: CGDirectDisplayID, value: Float) -> Bool {
    guard let display = self.display(for: displayID), display.isEnabled else {
      return false
    }
    let normalizedValue = max(min(value, 1), 0)
    let key = DisplayWriteKey(displayID: displayID, kind: kind)
    self.setLocalWriteTarget(key, value: normalizedValue)
    self.writeQueue.async {
      self.pendingWrites[key] = normalizedValue
      guard !self.scheduledWrites.contains(key) else {
        return
      }
      self.scheduledWrites.insert(key)
      self.writeQueue.asyncAfter(deadline: .now() + self.writeCoalescingDelay) {
        self.flushQueuedValue(for: key)
      }
    }
    return true
  }

  private func flushQueuedValue(for key: DisplayWriteKey) {
    guard let value = self.pendingWrites.removeValue(forKey: key) else {
      self.scheduledWrites.remove(key)
      return
    }
    let logValue = String(format: "%.3f", Double(value))
    if value <= 0.001 {
      os_log("DisplayLink %{public}@ sending zero value to display %{public}@.", type: .default, key.kind.payloadKey, String(key.displayID))
    } else {
      os_log("DisplayLink %{public}@ sending to display %{public}@ value %{public}@.", type: .info, key.kind.payloadKey, String(key.displayID), logValue)
    }
    if !self.writeValueSynchronously(kind: key.kind, for: key.displayID, value: value) {
      self.clearLocalWriteTarget(key, force: true)
    }
    if self.pendingWrites[key] != nil {
      self.writeQueue.asyncAfter(deadline: .now() + self.writeCoalescingDelay) {
        self.flushQueuedValue(for: key)
      }
    } else {
      self.scheduledWrites.remove(key)
    }
  }

  private func writeValueSynchronously(kind: ControlKind, for displayID: CGDirectDisplayID, value: Float) -> Bool {
    guard let display = self.display(for: displayID), display.isEnabled else {
      return false
    }
    guard let payload = Self.jsonString([
      "persistentDisplayId": display.persistentDisplayId,
      kind.payloadKey: Double(value),
    ]) else {
      return false
    }
    let note = self.waitForNotification(name: kind.updateName, timeout: self.timeout) {
      self.notificationCenter.postNotificationName(Notification.Name(kind.requestName), object: payload, userInfo: nil, deliverImmediately: true)
    } filter: { note in
      guard let raw = Self.objectString(note),
            let update = try? JSONDecoder().decode(UpdatePayload.self, from: Data(raw.utf8)) else {
        return false
      }
      return update.persistentDisplayId == display.persistentDisplayId
    }
    var acknowledgedValue: Float?
    if let raw = Self.objectString(note),
       let update = try? JSONDecoder().decode(UpdatePayload.self, from: Data(raw.utf8)),
       update.statusCode == 0 {
      acknowledgedValue = self.updatedValue(kind: kind, fallback: value, update: update)
    }
    if acknowledgedValue == nil {
      let refreshedDisplay = self.refreshDisplays().first { $0.persistentDisplayId == display.persistentDisplayId }
      let refreshedValue = refreshedDisplay.flatMap { refreshedDisplay -> Float? in
        switch kind {
        case .brightness:
          return refreshedDisplay.brightnessRequiresRestore ? nil : refreshedDisplay.brightness
        case .contrast:
          return refreshedDisplay.contrastRequiresRestore ? nil : refreshedDisplay.contrast
        }
      }
      if let refreshedValue, abs(refreshedValue - value) <= 0.011 {
        acknowledgedValue = refreshedValue
        os_log("DisplayLink %{public}@ write confirmed by refresh after notification timeout.", type: .info, kind.payloadKey)
      }
    }
    guard let acknowledgedValue else {
      os_log("DisplayLink %{public}@ write failed for display %{public}@.", type: .info, kind.payloadKey, display.persistentDisplayId)
      return false
    }
    let logValue = String(format: "%.3f", Double(acknowledgedValue))
    if acknowledgedValue <= 0.001 {
      os_log("DisplayLink %{public}@ wrote zero value for display %{public}@.", type: .default, kind.payloadKey, display.persistentDisplayId)
    } else {
      os_log("DisplayLink %{public}@ write succeeded for display %{public}@ value %{public}@.", type: .info, kind.payloadKey, display.persistentDisplayId, logValue)
    }
    self.updateCache(displayID: displayID, kind: kind, value: acknowledgedValue, notify: !self.hasActiveLocalWriteTarget(key: DisplayWriteKey(displayID: displayID, kind: kind)))
    self.clearLocalWriteTarget(DisplayWriteKey(displayID: displayID, kind: kind), acknowledgedValue: acknowledgedValue)
    return true
  }

  private func handleDisplayListNotification(_ note: Notification) {
    guard let raw = Self.objectString(note), let displays = Self.decodeDisplays(from: raw) else {
      return
    }
    self.replaceDisplays(displays, notify: true)
  }

  private func handleUpdateNotification(_ note: Notification, kind: ControlKind) {
    guard let raw = Self.objectString(note),
          let update = try? JSONDecoder().decode(UpdatePayload.self, from: Data(raw.utf8)),
          (update.statusCode ?? 0) == 0,
          let persistentDisplayId = update.persistentDisplayId else {
      return
    }
    let value = self.updatedValue(kind: kind, fallback: nil, update: update)
    guard let value else {
      return
    }
    guard let displayID = self.displayID(forPersistentDisplayId: persistentDisplayId) else {
      return
    }
    let key = DisplayWriteKey(displayID: displayID, kind: kind)
    let hasActiveLocalWrite = self.hasActiveLocalWriteTarget(key: key)
    if !hasActiveLocalWrite, self.requiresRestore(for: key) {
      os_log("Ignoring transient DisplayLink %{public}@ update while display %{public}@ requires restoration.", type: .default, kind.payloadKey, persistentDisplayId)
      return
    }
    self.updateCache(displayID: displayID, kind: kind, value: value, notify: !hasActiveLocalWrite)
    self.clearLocalWriteTarget(key, acknowledgedValue: value)
  }

  private func displayID(forPersistentDisplayId persistentDisplayId: String) -> CGDirectDisplayID? {
    self.stateQueue.sync {
      self.displayIDsByPersistentID[persistentDisplayId]
    }
  }

  @discardableResult
  private func updateCache(displayID: CGDirectDisplayID, kind: ControlKind, value: Float, notify: Bool) -> DisplayLinkDisplay? {
    var updatedDisplay: DisplayLinkDisplay?
    self.stateQueue.sync {
      guard let current = self.displaysByID[displayID] else {
        return
      }
      let brightness = kind == .brightness ? value : current.brightness
      let contrast = kind == .contrast ? value : current.contrast
      let updated = DisplayLinkDisplay(
        cgID: current.cgID,
        persistentDisplayId: current.persistentDisplayId,
        name: current.name,
        isEnabled: current.isEnabled,
        supportsBrightness: current.supportsBrightness,
        brightness: brightness,
        brightnessRequiresRestore: kind == .brightness ? false : current.brightnessRequiresRestore,
        supportsContrast: current.supportsContrast,
        contrast: contrast,
        contrastRequiresRestore: kind == .contrast ? false : current.contrastRequiresRestore
      )
      self.displaysByID[displayID] = updated
      self.displayIDsByPersistentID[updated.persistentDisplayId] = displayID
      self.lastKnownDisplaysByPersistentID[updated.persistentDisplayId] = updated
      updatedDisplay = updated
    }
    if notify, let updatedDisplay {
      self.postDisplayUpdate(updatedDisplay)
    }
    return updatedDisplay
  }

  @discardableResult
  private func replaceDisplays(_ displays: [DisplayLinkDisplay], notify: Bool) -> [DisplayLinkDisplay] {
    var resolvedDisplays: [DisplayLinkDisplay] = []
    self.stateQueue.sync {
      var displaysByID: [CGDirectDisplayID: DisplayLinkDisplay] = [:]
      var displayIDsByPersistentID: [String: CGDirectDisplayID] = [:]
      for display in displays {
        let previous = self.lastKnownDisplaysByPersistentID[display.persistentDisplayId]
        let resolved = DisplayLinkDisplay(
          cgID: display.cgID,
          persistentDisplayId: display.persistentDisplayId,
          name: display.name,
          isEnabled: display.isEnabled,
          supportsBrightness: display.supportsBrightness || previous?.supportsBrightness == true,
          brightness: display.brightness ?? previous?.brightness,
          brightnessRequiresRestore: display.brightnessRequiresRestore,
          supportsContrast: display.supportsContrast || previous?.supportsContrast == true,
          contrast: display.contrast ?? previous?.contrast,
          contrastRequiresRestore: display.contrastRequiresRestore
        )
        displaysByID[resolved.cgID] = resolved
        displayIDsByPersistentID[resolved.persistentDisplayId] = resolved.cgID
        self.lastKnownDisplaysByPersistentID[resolved.persistentDisplayId] = resolved
        resolvedDisplays.append(resolved)
      }
      self.displaysByID = displaysByID
      self.displayIDsByPersistentID = displayIDsByPersistentID
    }
    if notify {
      for display in resolvedDisplays {
        if self.shouldNotifyUpdate(for: display.cgID) {
          self.postDisplayUpdate(display)
        }
      }
    }
    return resolvedDisplays
  }

  private func postDisplayUpdate(_ display: DisplayLinkDisplay) {
    var userInfo: [String: Any] = [Self.userInfoDisplayIDKey: display.cgID]
    if !display.brightnessRequiresRestore, let brightness = display.brightness {
      userInfo[Self.userInfoBrightnessKey] = brightness
    }
    if !display.contrastRequiresRestore, let contrast = display.contrast {
      userInfo[Self.userInfoContrastKey] = contrast
    }
    DispatchQueue.main.async {
      NotificationCenter.default.post(name: Self.displayDidUpdateNotification, object: self, userInfo: userInfo)
    }
  }

  private func setLocalWriteTarget(_ key: DisplayWriteKey, value: Float) {
    self.stateQueue.sync {
      self.localWriteTargets[key] = LocalWriteTarget(value: value, createdAt: Date())
    }
  }

  private func hasActiveLocalWriteTarget(key: DisplayWriteKey) -> Bool {
    self.stateQueue.sync {
      guard let target = self.localWriteTargets[key] else {
        return false
      }
      if Date().timeIntervalSince(target.createdAt) > self.localWriteIgnoreInterval {
        self.localWriteTargets.removeValue(forKey: key)
        return false
      }
      return true
    }
  }

  private func clearLocalWriteTarget(_ key: DisplayWriteKey, acknowledgedValue: Float? = nil, force: Bool = false) {
    self.stateQueue.sync {
      guard force || acknowledgedValue != nil else {
        return
      }
      if force {
        self.localWriteTargets.removeValue(forKey: key)
        return
      }
      if let target = self.localWriteTargets[key], let acknowledgedValue, abs(target.value - acknowledgedValue) < 0.002 {
        self.localWriteTargets.removeValue(forKey: key)
      }
    }
  }

  private func shouldNotifyUpdate(for displayID: CGDirectDisplayID) -> Bool {
    !self.hasActiveLocalWriteTarget(key: DisplayWriteKey(displayID: displayID, kind: .brightness)) && !self.hasActiveLocalWriteTarget(key: DisplayWriteKey(displayID: displayID, kind: .contrast))
  }

  private func requiresRestore(for key: DisplayWriteKey) -> Bool {
    self.stateQueue.sync {
      guard let display = self.displaysByID[key.displayID] else {
        return false
      }
      switch key.kind {
      case .brightness:
        return display.brightnessRequiresRestore
      case .contrast:
        return display.contrastRequiresRestore
      }
    }
  }

  private func updatedValue(kind: ControlKind, fallback: Float?, update: UpdatePayload) -> Float? {
    switch kind {
    case .brightness:
      return Self.normalizedControlValue(update.brightness) ?? fallback
    case .contrast:
      return Self.normalizedControlValue(update.contrast) ?? fallback
    }
  }

  private func waitForNotification(name: String, timeout: TimeInterval, trigger: () -> Void, filter: ((Notification) -> Bool)? = nil) -> Notification? {
    let state = NotificationWaitState()
    let token = self.notificationCenter.addObserver(forName: Notification.Name(name), object: nil, queue: nil) { note in
      if filter?(note) ?? true {
        state.store(note)
      }
    }
    trigger()
    let until = Date().addingTimeInterval(timeout)
    while state.value() == nil, Date() < until {
      RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
    }
    self.notificationCenter.removeObserver(token)
    return state.value()
  }

  private static func objectString(_ note: Notification?) -> String? {
    if let string = note?.object as? String {
      return string
    }
    if let string = note?.object as? NSString {
      return string as String
    }
    return nil
  }

  private static func decodeDisplays(from raw: String) -> [DisplayLinkDisplay]? {
    guard let payloads = try? JSONDecoder().decode([DisplayPayload].self, from: Data(raw.utf8)) else {
      return nil
    }
    return payloads.compactMap { payload -> DisplayLinkDisplay? in
      guard let cgID = payload.CGID else {
        return nil
      }
      let brightness = self.normalizedControlValue(payload.brightness)
      let contrast = self.normalizedControlValue(payload.contrast)
      return DisplayLinkDisplay(
        cgID: CGDirectDisplayID(cgID),
        persistentDisplayId: payload.persistentDisplayId,
        name: payload.name ?? payload.persistentDisplayId,
        isEnabled: payload.isEnabled ?? true,
        supportsBrightness: payload.brightness != nil,
        brightness: brightness,
        brightnessRequiresRestore: payload.brightness != nil && brightness == nil,
        supportsContrast: payload.contrast != nil,
        contrast: contrast,
        contrastRequiresRestore: payload.contrast != nil && contrast == nil
      )
    }
  }

  static func normalizedControlValue(_ value: Float?) -> Float? {
    guard let value, value.isFinite, (0 ... 1).contains(value) else {
      return nil
    }
    return value
  }

  private static func jsonString(_ object: [String: Any]) -> String? {
    guard let data = try? JSONSerialization.data(withJSONObject: object, options: []) else {
      return nil
    }
    return String(data: data, encoding: .utf8)
  }
}
