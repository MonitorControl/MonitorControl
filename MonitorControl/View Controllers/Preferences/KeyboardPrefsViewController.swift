//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Cocoa
import KeyboardShortcuts
import ServiceManagement
import Settings
import os.log

class KeyboardPrefsViewController: NSViewController, SettingsPane {
  let paneIdentifier = Settings.PaneIdentifier.keyboard
  let paneTitle: String = NSLocalizedString("Keyboard", comment: "Shown in the main prefs window")

  var toolbarItemIcon: NSImage {
    if !DEBUG_MACOS10, #available(macOS 11.0, *) {
      return NSImage(systemSymbolName: "keyboard", accessibilityDescription: "Keyboard")!
    } else {
      return NSImage(named: NSImage.infoName)!
    }
  }

  @IBOutlet var customBrightnessUp: NSView!
  @IBOutlet var customBrightnessDown: NSView!
  @IBOutlet var customContrastUp: NSView!
  @IBOutlet var customContrastDown: NSView!
  @IBOutlet var customVolumeUp: NSView!
  @IBOutlet var customVolumeDown: NSView!
  @IBOutlet var customMute: NSView!

  @IBOutlet var keyboardBrightness: NSPopUpButton!
  @IBOutlet var keyboardVolume: NSPopUpButton!
  @IBOutlet var disableAltBrightnessKeys: NSButton!

  @IBOutlet var multiKeyboardBrightness: NSPopUpButton!
  @IBOutlet var multiKeyboardVolume: NSPopUpButton!
  @IBOutlet var useFineScale: NSButton!
  @IBOutlet var useFineScaleVolume: NSButton!
  @IBOutlet var separateCombinedScale: NSButton!

  @IBOutlet var rowKeyboardBrightnessPopUp: NSGridRow!
  @IBOutlet var rowKeyboardBrightnessText: NSGridRow!
  @IBOutlet var rowDisableAltBrightnessKeysCheck: NSGridRow!
  @IBOutlet var rowDisableAltBrightnessKeysText: NSGridRow!
  @IBOutlet var rowCustomBrightnessShortcuts: NSGridRow!
  @IBOutlet var rowMultiKeyboardBrightness: NSGridRow!
  @IBOutlet var rowUseFocusText: NSGridRow!
  @IBOutlet var rowCustomAudioShortcuts: NSGridRow!
  @IBOutlet var rowUseAudioMouseText: NSGridRow!
  @IBOutlet var rowUseAudioNameText: NSGridRow!

  // Accessibility troubleshooting UI
  var accessibilityHelpButton: NSButton?
  var resetAccessibilityButton: NSButton?

  func updateGridLayout() {
    if self.keyboardBrightness.selectedTag() == KeyboardBrightness.media.rawValue {
      self.rowKeyboardBrightnessPopUp.bottomPadding = -13
      self.rowKeyboardBrightnessText.isHidden = false
      self.rowDisableAltBrightnessKeysCheck.isHidden = false
      self.rowDisableAltBrightnessKeysText.isHidden = false
      self.rowCustomBrightnessShortcuts.isHidden = true
    } else if self.keyboardBrightness.selectedTag() == KeyboardBrightness.custom.rawValue {
      self.rowKeyboardBrightnessPopUp.bottomPadding = -6
      self.rowKeyboardBrightnessText.isHidden = true
      self.rowDisableAltBrightnessKeysCheck.isHidden = true
      self.rowDisableAltBrightnessKeysText.isHidden = true
      self.rowCustomBrightnessShortcuts.isHidden = false
    } else if self.keyboardBrightness.selectedTag() == KeyboardBrightness.both.rawValue {
      self.rowKeyboardBrightnessPopUp.bottomPadding = -6
      self.rowKeyboardBrightnessText.isHidden = true
      self.rowDisableAltBrightnessKeysCheck.isHidden = false
      self.rowDisableAltBrightnessKeysText.isHidden = false
      self.rowCustomBrightnessShortcuts.isHidden = false
    } else {
      self.rowKeyboardBrightnessPopUp.bottomPadding = -6
      self.rowKeyboardBrightnessText.isHidden = true
      self.rowDisableAltBrightnessKeysCheck.isHidden = true
      self.rowDisableAltBrightnessKeysText.isHidden = true
      self.rowCustomBrightnessShortcuts.isHidden = true
    }

    if self.keyboardBrightness.selectedTag() == KeyboardBrightness.disabled.rawValue {
      self.multiKeyboardBrightness.isEnabled = false
      self.useFineScale.isEnabled = false
      self.separateCombinedScale.isEnabled = false
    } else {
      self.multiKeyboardBrightness.isEnabled = true
      self.useFineScale.isEnabled = true
      self.separateCombinedScale.isEnabled = true
    }

    if [KeyboardVolume.custom.rawValue, KeyboardVolume.both.rawValue].contains(self.keyboardVolume.selectedTag()) {
      self.rowCustomAudioShortcuts.isHidden = false
    } else {
      self.rowCustomAudioShortcuts.isHidden = true
    }

    if self.keyboardVolume.selectedTag() == KeyboardVolume.disabled.rawValue {
      self.multiKeyboardVolume.isEnabled = false
      self.useFineScaleVolume.isEnabled = false
    } else {
      self.multiKeyboardVolume.isEnabled = true
      self.useFineScaleVolume.isEnabled = true
    }

    if self.multiKeyboardBrightness.selectedTag() == MultiKeyboardBrightness.focusInsteadOfMouse.rawValue {
      self.rowMultiKeyboardBrightness.bottomPadding = -10
      self.rowUseFocusText.isHidden = false
    } else {
      self.rowMultiKeyboardBrightness.bottomPadding = -6
      self.rowUseFocusText.isHidden = true
    }

    if self.multiKeyboardVolume.selectedTag() == MultiKeyboardVolume.audioDeviceNameMatching.rawValue {
      self.rowUseAudioNameText.isHidden = false
      self.rowUseAudioMouseText.isHidden = true
    } else {
      self.rowUseAudioNameText.isHidden = true
      self.rowUseAudioMouseText.isHidden = false
    }
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    let customBrightnessUpRecorder = KeyboardShortcuts.RecorderCocoa(for: .brightnessUp)
    let customBrightnessDownRecorder = KeyboardShortcuts.RecorderCocoa(for: .brightnessDown)
    let customContrastUpRecorder = KeyboardShortcuts.RecorderCocoa(for: .contrastUp)
    let customContrastDownRecorder = KeyboardShortcuts.RecorderCocoa(for: .contrastDown)
    let customVolumeUpRecorder = KeyboardShortcuts.RecorderCocoa(for: .volumeUp)
    let customVolumeDownRecorder = KeyboardShortcuts.RecorderCocoa(for: .volumeDown)
    let customMuteRecorder = KeyboardShortcuts.RecorderCocoa(for: .mute)

    customBrightnessUpRecorder.placeholderString = NSLocalizedString("Increase", comment: "Shown in record shortcut box")
    customContrastUpRecorder.placeholderString = customBrightnessUpRecorder.placeholderString
    customVolumeUpRecorder.placeholderString = customBrightnessUpRecorder.placeholderString
    customBrightnessDownRecorder.placeholderString = NSLocalizedString("Decrease", comment: "Shown in record shortcut box")
    customContrastDownRecorder.placeholderString = customBrightnessDownRecorder.placeholderString
    customVolumeDownRecorder.placeholderString = customBrightnessDownRecorder.placeholderString
    customMuteRecorder.placeholderString = NSLocalizedString("Mute", comment: "Shown in record shortcut box")

    self.customBrightnessUp.addSubview(customBrightnessUpRecorder)
    self.customBrightnessDown.addSubview(customBrightnessDownRecorder)
    self.customContrastUp.addSubview(customContrastUpRecorder)
    self.customContrastDown.addSubview(customContrastDownRecorder)
    self.customVolumeUp.addSubview(customVolumeUpRecorder)
    self.customVolumeDown.addSubview(customVolumeDownRecorder)
    self.customMute.addSubview(customMuteRecorder)

    self.setupAccessibilityTroubleshootingUI()
    self.populateSettings()
  }

  // MARK: - Accessibility Troubleshooting UI

  private func setupAccessibilityTroubleshootingUI() {
    // Create container view - height matches other grid rows
    let containerHeight: CGFloat = 25
    let containerView = NSView()
    containerView.translatesAutoresizingMaskIntoConstraints = false

    // Create "Troubleshooting:" label to match the existing UI style
    let label = NSTextField(labelWithString: NSLocalizedString("Troubleshooting:", comment: "Label for troubleshooting section"))
    label.font = NSFont.systemFont(ofSize: 13)
    label.textColor = NSColor.labelColor
    label.alignment = .right
    label.translatesAutoresizingMaskIntoConstraints = false

    // Create help button with system help style
    let helpButton = NSButton()
    helpButton.bezelStyle = .helpButton
    helpButton.title = ""
    helpButton.toolTip = NSLocalizedString("Keyboard shortcuts troubleshooting", comment: "Tooltip for help button")
    helpButton.target = self
    helpButton.action = #selector(showAccessibilityHelp(_:))
    helpButton.translatesAutoresizingMaskIntoConstraints = false
    self.accessibilityHelpButton = helpButton

    // Create Reset Accessibility button
    let resetButton = NSButton()
    resetButton.title = NSLocalizedString("Reset Accessibility Permission", comment: "Button to reset accessibility")
    resetButton.bezelStyle = .rounded
    resetButton.toolTip = NSLocalizedString("Reset and re-request accessibility permission (fixes keyboard shortcuts on macOS Tahoe)", comment: "Tooltip for reset button")
    resetButton.target = self
    resetButton.action = #selector(resetAccessibilityPermission(_:))
    resetButton.translatesAutoresizingMaskIntoConstraints = false
    self.resetAccessibilityButton = resetButton

    // Add all elements to container
    containerView.addSubview(label)
    containerView.addSubview(helpButton)
    containerView.addSubview(resetButton)

    // Add container to the main view
    self.view.addSubview(containerView)

    // Layout constraints - positioning to match grid spacing (10px from grid bottom)
    NSLayoutConstraint.activate([
      // Container positioning - bottom of view with grid-like padding
      containerView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 20),
      containerView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -20),
      containerView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor, constant: -18),
      containerView.heightAnchor.constraint(equalToConstant: containerHeight),

      // Label - right aligned at 212 points width to match storyboard column
      label.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
      label.widthAnchor.constraint(equalToConstant: 210),
      label.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),

      // Help button - after label
      helpButton.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 8),
      helpButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),

      // Reset button - after help button
      resetButton.leadingAnchor.constraint(equalTo: helpButton.trailingAnchor, constant: 8),
      resetButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
    ])
  }

  @objc func showAccessibilityHelp(_ sender: NSButton) {
    let alert = NSAlert()
    alert.messageText = NSLocalizedString("Keyboard Shortcuts Not Working?", comment: "Alert title")
    alert.informativeText = NSLocalizedString("""
On macOS Tahoe (26+), you may need to reset accessibility permissions for keyboard shortcuts to work.

To fix this:
1. Click "Reset Accessibility Permission" below
2. When prompted, click "Open System Settings"
3. Enable MonitorControl in the Accessibility list
4. Restart MonitorControl if needed

Alternatively, go to:
System Settings → Privacy & Security → Accessibility
Remove MonitorControl, then add it back.
""", comment: "Accessibility troubleshooting guide")
    alert.alertStyle = .informational
    if #available(macOS 11.0, *) {
      alert.icon = NSImage(systemSymbolName: "keyboard", accessibilityDescription: nil)
    }
    alert.addButton(withTitle: NSLocalizedString("OK", comment: "OK button"))
    alert.addButton(withTitle: NSLocalizedString("Open Accessibility Settings", comment: "Button to open settings"))

    let response = alert.runModal()
    if response == .alertSecondButtonReturn {
      self.openAccessibilitySettings()
    }
  }

  @objc func resetAccessibilityPermission(_ sender: NSButton) {
    let alert = NSAlert()
    alert.messageText = NSLocalizedString("Reset Accessibility Permission?", comment: "Confirmation alert title")
    alert.informativeText = NSLocalizedString("This will reset MonitorControl's accessibility permission. You will need to grant permission again for keyboard shortcuts to work.", comment: "Confirmation message")
    alert.alertStyle = .warning
    alert.addButton(withTitle: NSLocalizedString("Reset & Re-request", comment: "Reset button"))
    alert.addButton(withTitle: NSLocalizedString("Cancel", comment: "Cancel button"))

    let response = alert.runModal()
    guard response == .alertFirstButtonReturn else { return }

    // Run tccutil to reset accessibility for this app
    let bundleId = Bundle.main.bundleIdentifier ?? "me.guillaumeb.MonitorControl"
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
    process.arguments = ["reset", "Accessibility", bundleId]

    do {
      try process.run()
      process.waitUntilExit()
      os_log("Reset accessibility permission for %{public}@, exit code: %{public}d", type: .info, bundleId, process.terminationStatus)
    } catch {
      os_log("Failed to reset accessibility: %{public}@", type: .error, error.localizedDescription)
    }

    // Re-prompt for accessibility permission
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      MediaKeyTapManager.acquirePrivileges()
    }
  }

  private func openAccessibilitySettings() {
    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
      NSWorkspace.shared.open(url)
    }
  }

  func populateSettings() {
    self.keyboardBrightness.selectItem(withTag: prefs.integer(forKey: PrefKey.keyboardBrightness.rawValue))
    self.keyboardVolume.selectItem(withTag: prefs.integer(forKey: PrefKey.keyboardVolume.rawValue))
    self.disableAltBrightnessKeys.state = prefs.bool(forKey: PrefKey.disableAltBrightnessKeys.rawValue) ? .on : .off
    self.multiKeyboardBrightness.selectItem(withTag: prefs.integer(forKey: PrefKey.multiKeyboardBrightness.rawValue))
    self.multiKeyboardVolume.selectItem(withTag: prefs.integer(forKey: PrefKey.multiKeyboardVolume.rawValue))
    self.useFineScale.state = prefs.bool(forKey: PrefKey.useFineScaleBrightness.rawValue) ? .on : .off
    self.useFineScaleVolume.state = prefs.bool(forKey: PrefKey.useFineScaleVolume.rawValue) ? .on : .off
    self.separateCombinedScale.state = prefs.bool(forKey: PrefKey.separateCombinedScale.rawValue) ? .on : .off
    self.updateGridLayout()
  }

  @IBAction func multiKeyboardBrightness(_ sender: NSPopUpButton) {
    prefs.set(sender.selectedTag(), forKey: PrefKey.multiKeyboardBrightness.rawValue)
    app.updateMediaKeyTap()
    self.updateGridLayout()
  }

  @IBAction func multiKeyboardVolume(_ sender: NSPopUpButton) {
    prefs.set(sender.selectedTag(), forKey: PrefKey.multiKeyboardVolume.rawValue)
    app.updateMediaKeyTap()
    self.updateGridLayout()
  }

  @IBAction func useFineScaleClicked(_ sender: NSButton) {
    switch sender.state {
    case .on:
      prefs.set(true, forKey: PrefKey.useFineScaleBrightness.rawValue)
    case .off:
      prefs.set(false, forKey: PrefKey.useFineScaleBrightness.rawValue)
    default: break
    }
    self.updateGridLayout()
  }

  @IBAction func useFineScaleVolumeClicked(_ sender: NSButton) {
    switch sender.state {
    case .on:
      prefs.set(true, forKey: PrefKey.useFineScaleVolume.rawValue)
    case .off:
      prefs.set(false, forKey: PrefKey.useFineScaleVolume.rawValue)
    default: break
    }
  }

  @IBAction func separateCombinedScale(_ sender: NSButton) {
    switch sender.state {
    case .on:
      prefs.set(true, forKey: PrefKey.separateCombinedScale.rawValue)
    case .off:
      prefs.set(false, forKey: PrefKey.separateCombinedScale.rawValue)
    default: break
    }
    self.updateGridLayout()
  }

  @IBAction func disableAltBrightnessKeys(_ sender: NSButton) {
    switch sender.state {
    case .on:
      prefs.set(true, forKey: PrefKey.disableAltBrightnessKeys.rawValue)
    case .off:
      prefs.set(false, forKey: PrefKey.disableAltBrightnessKeys.rawValue)
    default: break
    }
    self.updateGridLayout()
    app.updateMediaKeyTap()
  }

  @IBAction func keyboardBrightness(_ sender: NSPopUpButton) {
    prefs.set(sender.selectedTag(), forKey: PrefKey.keyboardBrightness.rawValue)
    app.updateMenusAndKeys()
    self.updateGridLayout()
  }

  @IBAction func keyboardVolume(_ sender: NSPopUpButton) {
    prefs.set(sender.selectedTag(), forKey: PrefKey.keyboardVolume.rawValue)
    app.updateMenusAndKeys()
    self.updateGridLayout()
  }
}

