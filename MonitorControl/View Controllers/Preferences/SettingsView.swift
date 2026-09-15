// Copyright © MonitorControl contributors

import SwiftUI

enum SettingsPage: String, CaseIterable, Identifiable {
  case general, appearance, keyboard, displays, about

  var id: String { self.rawValue }

  var title: String {
    switch self {
    case .general: return NSLocalizedString("General", comment: "Settings sidebar")
    case .appearance: return NSLocalizedString("Appearance", comment: "Settings sidebar")
    case .keyboard: return NSLocalizedString("Keyboard", comment: "Settings sidebar")
    case .displays: return NSLocalizedString("Displays", comment: "Settings sidebar")
    case .about: return NSLocalizedString("About", comment: "Settings sidebar")
    }
  }

  var symbol: String {
    switch self {
    case .general: return "gearshape"
    case .appearance: return "paintpalette"
    case .keyboard: return "keyboard"
    case .displays: return "display.2"
    case .about: return "info.circle"
    }
  }
}

/// Canvas uses the same native split-view container as the settings window.
struct SettingsView: NSViewControllerRepresentable {
  let preferences: SettingsPreferences
  var initialPage: SettingsPage = .general
  let legacyController: (SettingsPage) -> NSViewController?
  let resetSettings: () -> Void
  let quitApplication: () -> Void

  func makeNSViewController(context _: Context) -> SettingsSplitViewController {
    SettingsSplitViewController(
      preferences: self.preferences,
      initialPage: self.initialPage,
      legacyController: self.legacyController,
      resetSettings: self.resetSettings,
      quitApplication: self.quitApplication
    )
  }

  func updateNSViewController(_: SettingsSplitViewController, context _: Context) {}
}

private struct SettingsToggle: View {
  let title: LocalizedStringKey
  let description: LocalizedStringKey
  @Binding var isOn: Bool

  init(_ title: LocalizedStringKey, description: LocalizedStringKey, isOn: Binding<Bool>) {
    self.title = title
    self.description = description
    self._isOn = isOn
  }

  var body: some View {
    Toggle(isOn: self.$isOn) {
      VStack(alignment: .leading, spacing: 4) {
        Text(self.title)
        Text(self.description)
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      .padding(.vertical, 3)
    }
    .toggleStyle(.switch)
  }
}

struct GeneralSettingsView: View {
  @ObservedObject var preferences: SettingsPreferences
  var resetSettings: () -> Void
  @State private var confirmingReset = false

  private var startupDescription: LocalizedStringKey {
    switch self.preferences.integer(.startupAction).wrappedValue {
    case StartupAction.write.rawValue:
      return "Useful when a display resets its settings during sleep."
    case StartupAction.read.rawValue:
      return "Read current values from the display. Some hardware may not support this."
    default:
      return "Use saved values without changing the display when starting or waking."
    }
  }

  var body: some View {
    Form {
      Section("Application") {
        SettingsToggle("Launch at login", description: "Start MonitorControl when you log in to your Mac.", isOn: self.preferences.launchAtLogin)
        if self.preferences.loginStatus == .requiresApproval {
          Text("Allow MonitorControl in System Settings > General > Login Items. Enable the toggle again to open those settings.")
            .font(.callout)
            .foregroundStyle(.secondary)
        }
        SettingsToggle("Automatically check for updates", description: "Check for new versions of MonitorControl.", isOn: self.preferences.boolean(.SUEnableAutomaticChecks))
      }

      Section("Brightness") {
        SettingsToggle("Combine hardware and software dimming", description: "Continue dimming with software below the display's minimum hardware brightness.", isOn: self.preferences.boolean(.disableCombinedBrightness, inverted: true))
        SettingsToggle("Allow zero brightness", description: "Allow software or combined dimming to make the screen completely dark.", isOn: self.preferences.boolean(.allowZeroSwBrightness))
        SettingsToggle("Smooth brightness transitions", description: "Gradually transition between brightness levels.", isOn: self.preferences.boolean(.disableSmoothBrightness, inverted: true))
        SettingsToggle("Sync brightness changes", description: "Sync changes from built-in and Apple displays to other displays.", isOn: self.preferences.boolean(.enableBrightnessSync))
      }

      Section {
        Picker("Upon startup or wake", selection: self.preferences.integer(.startupAction)) {
          Text("Use saved settings").tag(StartupAction.doNothing.rawValue)
          Text("Apply saved values to displays").tag(StartupAction.write.rawValue)
          Text("Read values from displays").tag(StartupAction.read.rawValue)
        }
        Text(self.startupDescription)
          .font(.callout)
          .foregroundStyle(.secondary)
      } header: {
        Text("Startup and wake")
      } footer: {
        Text("Hold Shift while starting MonitorControl to restore defaults in Safe Mode.")
      }

      Section {
        Button("Reset Settings…", role: .destructive) { self.confirmingReset = true }
          .confirmationDialog("Reset all settings?", isPresented: self.$confirmingReset) {
            Button("Reset Settings", role: .destructive, action: self.resetSettings)
            Button("Cancel", role: .cancel) {}
          } message: {
            Text("This restores the default application and display settings.")
          }
      }
    }
    .formStyle(.grouped)
  }
}

struct AppearanceSettingsView: View {
  @ObservedObject var preferences: SettingsPreferences
  var quitApplication: () -> Void

  private var brightnessVisible: Bool {
    self.preferences.boolean(.hideBrightness, inverted: true).wrappedValue
  }

  private var needsQuitButton: Bool {
    self.preferences.integer(.menuIcon).wrappedValue != MenuIcon.show.rawValue
      || self.preferences.integer(.menuItemStyle).wrappedValue == MenuItemStyle.hide.rawValue
  }

  var body: some View {
    Form {
      Section("Menu bar") {
        Picker("Show menu bar icon", selection: self.preferences.integer(.menuIcon)) {
          Text("Always").tag(MenuIcon.show.rawValue)
          Text("When a slider is available").tag(MenuIcon.sliderOnly.rawValue)
          Text("When an external display is connected").tag(MenuIcon.externalOnly.rawValue)
          Text("Never").tag(MenuIcon.hide.rawValue)
        }
        Picker("Menu actions", selection: self.preferences.integer(.menuItemStyle)) {
          Text("Icons").tag(MenuItemStyle.icon.rawValue)
          Text("Text").tag(MenuItemStyle.text.rawValue)
          Text("Hidden").tag(MenuItemStyle.hide.rawValue)
        }
        if self.needsQuitButton {
          Text("Relaunch MonitorControl to access Settings if its menu is hidden.")
            .font(.callout)
            .foregroundStyle(.secondary)
          Button("Quit MonitorControl", action: self.quitApplication)
        }
      }

      Section("Display controls") {
        SettingsToggle("Show brightness slider", description: "Control hardware and software brightness from the menu.", isOn: self.preferences.boolean(.hideBrightness, inverted: true))
        SettingsToggle("Include built-in and Apple displays", description: "Also show their brightness sliders in MonitorControl.", isOn: Binding(
          get: { self.brightnessVisible && self.preferences.boolean(.hideAppleFromMenu, inverted: true).wrappedValue },
          set: { self.preferences.boolean(.hideAppleFromMenu, inverted: true).wrappedValue = $0 }
        ))
        .disabled(!self.brightnessVisible)
        SettingsToggle("Show volume slider", description: "Available for supported hardware (DDC) displays.", isOn: self.preferences.boolean(.hideVolume, inverted: true))
        SettingsToggle("Show contrast slider", description: "Available for supported hardware (DDC) displays.", isOn: self.preferences.boolean(.showContrast))
        Picker("Multiple displays", selection: self.preferences.integer(.multiSliders)) {
          Text("Separate controls for each display").tag(MultiSliders.separate.rawValue)
          Text("Only the display showing the menu").tag(MultiSliders.relevant.rawValue)
          Text("Combined controls for all displays").tag(MultiSliders.combine.rawValue)
        }
        if self.preferences.integer(.multiSliders).wrappedValue == MultiSliders.combine.rawValue {
          Text("Works best with brightness sync and keyboard controls set to all displays.")
            .font(.callout)
            .foregroundStyle(.secondary)
        }
      }

      Section("Slider behavior") {
        SettingsToggle("Enable slider snapping", description: "Snap to 0%, 25%, 50%, 75% and 100% when nearby.", isOn: self.preferences.boolean(.enableSliderSnap))
        SettingsToggle("Show slider tick marks", description: "Mark 0%, 25%, 50%, 75% and 100%.", isOn: self.preferences.boolean(.showTickMarks))
        SettingsToggle("Show percentages", description: "Show values above sliders, including Night Shift temperature.", isOn: self.preferences.boolean(.enableSliderPercent))
      }

      Section("Menu appearance") {
        SettingsToggle("Show display resolution", description: "Show the resolution below each display name.", isOn: self.preferences.boolean(.showDisplayResolution))
        SettingsToggle("Show system appearance controls", description: "Show Dark Mode, Night Shift and True Tone together.", isOn: self.preferences.boolean(.showSystemControls))
        SettingsToggle("Show Night Shift temperature", description: "Adjust the system Night Shift warmth from the menu.", isOn: self.preferences.boolean(.showNightShiftTemperature))
      }
    }
    .formStyle(.grouped)
  }
}

/// Keep existing shortcut recorders and per-display controls in the responder chain
/// while their settings pages are migrated.
final class LegacySettingsContainer: NSViewController {
  let content: NSViewController

  init(content: NSViewController) {
    self.content = content
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder _: NSCoder) { nil }

  override func loadView() {
    let scrollView = NSScrollView()
    scrollView.hasVerticalScroller = true
    scrollView.hasHorizontalScroller = true
    scrollView.autohidesScrollers = true
    scrollView.drawsBackground = false
    scrollView.automaticallyAdjustsContentInsets = false
    let document = FlippedSettingsDocument()
    document.translatesAutoresizingMaskIntoConstraints = false
    scrollView.documentView = document
    self.addChild(self.content)
    let contentView = self.content.view
    for constraint in contentView.constraints
      where constraint.firstItem === contentView && constraint.secondItem == nil
      && constraint.firstAttribute == .width
    {
      constraint.isActive = false
    }
    contentView.translatesAutoresizingMaskIntoConstraints = false
    document.addSubview(contentView)
    let preferredWidth = document.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor)
    // A legacy pane's fixed internal widths must never resize the enclosing window.
    preferredWidth.priority = .fittingSizeCompression
    NSLayoutConstraint.activate([
      document.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
      document.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
      document.widthAnchor.constraint(greaterThanOrEqualToConstant: 730),
      preferredWidth,
      contentView.leadingAnchor.constraint(equalTo: document.leadingAnchor),
      contentView.trailingAnchor.constraint(equalTo: document.trailingAnchor),
      contentView.topAnchor.constraint(equalTo: document.topAnchor),
      contentView.bottomAnchor.constraint(equalTo: document.bottomAnchor),
    ])
    self.view = scrollView
  }

  func detachContent() {
    self.content.view.removeFromSuperview()
    self.content.removeFromParent()
  }
}

private final class FlippedSettingsDocument: NSView {
  override var isFlipped: Bool { true }
}

#if DEBUG
  private func previewPreferences() -> SettingsPreferences {
    let defaults = UserDefaults(suiteName: "MonitorControl.SettingsPreview.\(UUID().uuidString)")!
    defaults.register(defaults: [
      PrefKey.showDisplayResolution.rawValue: true,
      PrefKey.showSystemControls.rawValue: true,
      PrefKey.showNightShiftTemperature.rawValue: true,
      PrefKey.enableSliderPercent.rawValue: true,
      PrefKey.SUEnableAutomaticChecks.rawValue: true,
    ])
    return SettingsPreferences(defaults: defaults)
  }

  #Preview("General") {
    SettingsView(preferences: previewPreferences(), legacyController: { _ in nil }, resetSettings: {}, quitApplication: {})
      .frame(width: 960, height: 700)
  }

  #Preview("Appearance") {
    SettingsView(preferences: previewPreferences(), initialPage: .appearance, legacyController: { _ in nil }, resetSettings: {}, quitApplication: {})
      .frame(width: 960, height: 700)
  }
#endif
