//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Cocoa
import os.log

struct BrightnessAutomation: Codable, Equatable {
  enum TargetMode: String, Codable {
    case all
    case specific
  }

  var id: String
  var isEnabled: Bool
  var hour: Int
  var minute: Int
  var brightness: Float
  var targetMode: TargetMode
  var targetDisplayPrefsIds: [String]
  var targetDisplayLabels: [String]
  var lastRunDate: Date?

  var minuteOfDay: Int {
    self.hour * 60 + self.minute
  }
}

final class BrightnessAutomationManager {
  private(set) var automations: [BrightnessAutomation] = []
  private var timer: Timer?
  private let calendar = Calendar.current

  init() {
    self.load()
  }

  deinit {
    self.timer?.invalidate()
  }

  func start() {
    self.applyLatestMissedAutomationForToday()
    self.scheduleNextRun()
  }

  func handleWakeOrDisplayChange() {
    self.applyLatestMissedAutomationForToday()
    self.scheduleNextRun()
  }

  func upsert(_ automation: BrightnessAutomation) {
    if let index = self.automations.firstIndex(where: { $0.id == automation.id }) {
      self.automations[index] = automation
    } else {
      self.automations.append(automation)
    }
    self.sortAutomations()
    self.save()
    self.scheduleNextRun()
  }

  func delete(id: String) {
    self.automations.removeAll { $0.id == id }
    self.save()
    self.scheduleNextRun()
  }

  func availableDisplayTargets() -> [(prefsId: String, label: String)] {
    DisplayManager.shared.getAllDisplays()
      .filter { self.canControlBrightness($0) }
      .map { display in
        let friendlyName = display.readPrefAsString(key: .friendlyName)
        return (display.prefsId, friendlyName.isEmpty ? display.name : friendlyName)
      }
  }

  func summary(for automation: BrightnessAutomation) -> String {
    let time = String(format: "%02d:%02d", automation.hour, automation.minute)
    let brightness = String(format: "%.0f%%", Double(automation.brightness) * 100)
    let target: String
    if automation.targetMode == .all {
      target = NSLocalizedString("All displays", comment: "Shown in brightness automation window")
    } else if automation.targetDisplayLabels.isEmpty {
      target = NSLocalizedString("No displays", comment: "Shown in brightness automation window")
    } else {
      target = automation.targetDisplayLabels.joined(separator: ", ")
    }
    return "\(automation.isEnabled ? "" : "Off - ")\(time) - \(brightness) - \(target)"
  }

  private func load() {
    guard let data = prefs.data(forKey: PrefKey.brightnessAutomations.rawValue) else {
      self.automations = []
      return
    }
    do {
      self.automations = try JSONDecoder().decode([BrightnessAutomation].self, from: data)
      self.sortAutomations()
    } catch {
      os_log("Unable to load brightness automations: %{public}@", type: .error, error.localizedDescription)
      self.automations = []
    }
  }

  private func save() {
    do {
      let data = try JSONEncoder().encode(self.automations)
      prefs.set(data, forKey: PrefKey.brightnessAutomations.rawValue)
    } catch {
      os_log("Unable to save brightness automations: %{public}@", type: .error, error.localizedDescription)
    }
  }

  private func sortAutomations() {
    self.automations.sort {
      if $0.minuteOfDay == $1.minuteOfDay {
        return self.summary(for: $0).localizedStandardCompare(self.summary(for: $1)) == .orderedAscending
      }
      return $0.minuteOfDay < $1.minuteOfDay
    }
  }

  private func scheduleNextRun() {
    self.timer?.invalidate()
    self.timer = nil

    let enabledAutomations = self.automations.filter(\.isEnabled)
    guard !enabledAutomations.isEmpty else {
      return
    }

    let now = Date()
    guard let next = enabledAutomations.compactMap({ automation -> (Date, String)? in
      guard let date = self.nextRunDate(for: automation, after: now) else {
        return nil
      }
      return (date, automation.id)
    }).min(by: { $0.0 < $1.0 }) else {
      return
    }

    let timer = Timer(timeInterval: max(0.1, next.0.timeIntervalSince(now)), repeats: false) { [weak self] _ in
      self?.timerFired(automationID: next.1)
    }
    RunLoop.main.add(timer, forMode: .common)
    self.timer = timer
  }

  private func timerFired(automationID: String) {
    defer {
      self.scheduleNextRun()
    }
    guard app.sleepID == 0, app.reconfigureID == 0 else {
      return
    }
    guard let index = self.automations.firstIndex(where: { $0.id == automationID }), self.automations[index].isEnabled else {
      return
    }
    if self.apply(self.automations[index]) {
      self.automations[index].lastRunDate = Date()
      self.save()
    }
  }

  private func applyLatestMissedAutomationForToday() {
    guard app.sleepID == 0, app.reconfigureID == 0 else {
      return
    }
    let now = Date()
    let currentMinuteOfDay = self.minuteOfDay(for: now)
    guard let automation = self.automations
      .filter({ $0.isEnabled && $0.minuteOfDay <= currentMinuteOfDay && !self.hasRun($0, onSameDayAs: now) })
      .max(by: { $0.minuteOfDay < $1.minuteOfDay }) else {
      return
    }
    guard let index = self.automations.firstIndex(where: { $0.id == automation.id }) else {
      return
    }
    if self.apply(automation) {
      self.automations[index].lastRunDate = now
      self.save()
    }
  }

  private func apply(_ automation: BrightnessAutomation) -> Bool {
    let value = max(0, min(1, automation.brightness))
    let targetDisplays = self.targetDisplays(for: automation)
    guard !targetDisplays.isEmpty else {
      os_log("Brightness automation %{public}@ skipped because no target displays are available.", type: .info, automation.id)
      return false
    }
    for display in targetDisplays {
      if display.setBrightness(value) {
        display.sliderHandler[.brightness]?.setValue(value, displayID: display.identifier)
      }
    }
    return true
  }

  private func targetDisplays(for automation: BrightnessAutomation) -> [Display] {
    let displays = DisplayManager.shared.getAllDisplays().filter { self.canControlBrightness($0) }
    if automation.targetMode == .all {
      return displays
    }
    let selected = Set(automation.targetDisplayPrefsIds)
    return displays.filter { selected.contains($0.prefsId) }
  }

  private func canControlBrightness(_ display: Display) -> Bool {
    if display.isDummy {
      return false
    }
    if let otherDisplay = display as? OtherDisplay, otherDisplay.isSw() {
      return true
    }
    return !display.readPrefAsBool(key: .unavailableDDC, for: .brightness)
  }

  private func nextRunDate(for automation: BrightnessAutomation, after date: Date) -> Date? {
    var components = self.calendar.dateComponents([.year, .month, .day], from: date)
    components.hour = automation.hour
    components.minute = automation.minute
    components.second = 0
    guard var runDate = self.calendar.date(from: components) else {
      return nil
    }
    if runDate <= date {
      guard let tomorrow = self.calendar.date(byAdding: .day, value: 1, to: runDate) else {
        return nil
      }
      runDate = tomorrow
    }
    return runDate
  }

  private func minuteOfDay(for date: Date) -> Int {
    let components = self.calendar.dateComponents([.hour, .minute], from: date)
    return (components.hour ?? 0) * 60 + (components.minute ?? 0)
  }

  private func hasRun(_ automation: BrightnessAutomation, onSameDayAs date: Date) -> Bool {
    guard let lastRunDate = automation.lastRunDate else {
      return false
    }
    return self.calendar.isDate(lastRunDate, inSameDayAs: date)
  }
}
