import Combine
@testable import SettingsModel
import XCTest

final class SettingsPreferencesTests: XCTestCase {
  private var defaults: UserDefaults!
  private var suite: String!

  override func setUp() {
    super.setUp()
    self.suite = "MonitorControl.SettingsTests.\(UUID().uuidString)"
    self.defaults = UserDefaults(suiteName: self.suite)!
  }

  override func tearDown() {
    self.defaults.removePersistentDomain(forName: self.suite)
    super.tearDown()
  }

  func testExistingValuesAndInvertedPreferencesArePreserved() {
    self.defaults.set(true, forKey: PrefKey.disableCombinedBrightness.rawValue)
    self.defaults.set(false, forKey: PrefKey.showSystemControls.rawValue)
    self.defaults.register(defaults: [PrefKey.showSystemControls.rawValue: true])
    let model = SettingsPreferences(defaults: self.defaults)
    XCTAssertFalse(model.boolean(.disableCombinedBrightness, inverted: true).wrappedValue)
    XCTAssertFalse(model.boolean(.showSystemControls).wrappedValue)
    model.boolean(.disableCombinedBrightness, inverted: true).wrappedValue = true
    XCTAssertFalse(self.defaults.bool(forKey: PrefKey.disableCombinedBrightness.rawValue))
  }

  func testHardwareResetHappensBeforePreferenceChangesAndReconfigureAfter() {
    var events: [String] = []
    let model = SettingsPreferences(defaults: self.defaults, beforeChange: { key in
      events.append("before:\(self.defaults.bool(forKey: key.rawValue))")
    }, afterChange: { key in
      events.append("after:\(self.defaults.bool(forKey: key.rawValue))")
    })
    model.boolean(.disableCombinedBrightness).wrappedValue = true
    model.boolean(.disableCombinedBrightness).wrappedValue = true
    XCTAssertEqual(events, ["before:false", "after:true"])
  }

  func testPickerUsesExistingEnumValuesWithoutRepeatedEffects() {
    var effects: [PrefKey] = []
    let model = SettingsPreferences(defaults: self.defaults, afterChange: { effects.append($0) })
    model.integer(.multiSliders).wrappedValue = MultiSliders.combine.rawValue
    model.integer(.multiSliders).wrappedValue = MultiSliders.combine.rawValue
    XCTAssertEqual(self.defaults.integer(forKey: PrefKey.multiSliders.rawValue), 2)
    XCTAssertEqual(effects, [.multiSliders])
  }

  func testExternalChangesAndResetAreReadFromTheSameStore() {
    let model = SettingsPreferences(defaults: self.defaults)
    let binding = model.boolean(.enableSliderPercent)
    self.defaults.set(true, forKey: PrefKey.enableSliderPercent.rawValue)
    XCTAssertTrue(binding.wrappedValue)
    self.defaults.removePersistentDomain(forName: self.suite)
    XCTAssertFalse(binding.wrappedValue)
  }

  func testExternalPreferenceChangeNotifiesTheVisiblePage() {
    let model = SettingsPreferences(defaults: self.defaults)
    let changed = self.expectation(description: "Settings update after external preference change")
    let observation = model.objectWillChange.sink { changed.fulfill() }
    self.defaults.set(true, forKey: PrefKey.enableSliderPercent.rawValue)
    self.wait(for: [changed], timeout: 2)
    withExtendedLifetime(observation) {}
  }

  func testMenuVisibilityKeepsSavedAppleDisplayChoice() {
    self.defaults.set(false, forKey: PrefKey.hideAppleFromMenu.rawValue)
    let model = SettingsPreferences(defaults: self.defaults)
    model.boolean(.hideBrightness, inverted: true).wrappedValue = false
    XCTAssertFalse(self.defaults.bool(forKey: PrefKey.hideAppleFromMenu.rawValue))
    model.boolean(.hideBrightness, inverted: true).wrappedValue = true
    XCTAssertTrue(model.boolean(.hideAppleFromMenu, inverted: true).wrappedValue)
  }

  func testLoginFailureDoesNotShowEnabledAndPendingApprovalIsRefreshed() {
    var status = SettingsPreferences.LoginStatus.disabled
    var attempts: [Bool] = []
    let model = SettingsPreferences(defaults: self.defaults, readLoginStatus: { status }, changeLoginStatus: { attempts.append($0) })
    model.launchAtLogin.wrappedValue = true
    XCTAssertFalse(model.launchAtLogin.wrappedValue)
    status = .requiresApproval
    model.refreshLoginStatus()
    XCTAssertEqual(model.loginStatus, .requiresApproval)
    XCTAssertFalse(model.launchAtLogin.wrappedValue)
    status = .enabled
    model.refreshLoginStatus()
    XCTAssertTrue(model.launchAtLogin.wrappedValue)
    XCTAssertEqual(attempts, [true])
  }
}
