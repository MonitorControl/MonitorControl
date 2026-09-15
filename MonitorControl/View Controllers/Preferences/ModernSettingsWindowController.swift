// Copyright © MonitorControl contributors

import ServiceManagement
import SwiftUI

final class ModernSettingsWindowController: NSWindowController {
  private let preferences: SettingsPreferences
  private var activationObserver: NSObjectProtocol?

  init() {
    let preferences = SettingsPreferences(
      defaults: prefs,
      beforeChange: { key in
        if key == .disableCombinedBrightness {
          for display in DisplayManager.shared.getDdcCapableDisplays() where !display.isSw() {
            _ = display.setDirectBrightness(1)
          }
          DisplayManager.shared.resetSwBrightnessForAllDisplays(async: false)
        }
      },
      afterChange: { key in
        switch key {
        case .disableCombinedBrightness:
          app.configure()
        case .allowZeroSwBrightness:
          for display in DisplayManager.shared.getOtherDisplays() {
            _ = display.setDirectBrightness(1)
            _ = display.setSwBrightness(1)
          }
          app.configure()
        case .SUEnableAutomaticChecks, .disableSmoothBrightness, .enableBrightnessSync, .startupAction:
          break
        default:
          app.updateMenusAndKeys()
        }
      },
      readLoginStatus: {
        switch SMAppService.mainApp.status {
        case .enabled: return .enabled
        case .requiresApproval: return .requiresApproval
        default: return .disabled
        }
      },
      changeLoginStatus: { app.setStartAtLogin(enabled: $0) }
    )
    self.preferences = preferences
    let root = SettingsSplitViewController(
      preferences: preferences,
      legacyController: { page in
        switch page {
        case .keyboard: return keyboardPrefsVc
        case .displays: return displaysPrefsVc
        case .about: return aboutPrefsVc
        default: return nil
        }
      },
      resetSettings: {
        app.settingsReset()
        preferences.objectWillChange.send()
        preferences.refreshLoginStatus()
        if keyboardPrefsVc?.isViewLoaded == true { keyboardPrefsVc?.populateSettings() }
        if displaysPrefsVc?.isViewLoaded == true { displaysPrefsVc?.populateSettings() }
      },
      quitApplication: { NSApp.terminate(nil) }
    )
    let window = SettingsWindow(content: root)
    super.init(window: window)
    self.activationObserver = NotificationCenter.default.addObserver(
      forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
    ) { [weak self] _ in
      self?.preferences.refreshLoginStatus()
    }
  }

  required init?(coder _: NSCoder) { nil }

  deinit {
    if let activationObserver = self.activationObserver {
      NotificationCenter.default.removeObserver(activationObserver)
    }
  }

  override func keyDown(with event: NSEvent) {
    if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
       event.charactersIgnoringModifiers == "w"
    {
      self.close()
    } else {
      super.keyDown(with: event)
    }
  }

  func show() {
    self.preferences.refreshLoginStatus()
    (self.window as? SettingsWindow)?.validateSize()
    self.showWindow(nil)
  }
}
