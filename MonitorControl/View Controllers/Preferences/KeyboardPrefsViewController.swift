//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Cocoa
import KeyboardShortcuts
import ServiceManagement
import Settings

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

  private var presetPercentageFields: [NSTextField] = []

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

    self.addPresetRows()
    self.populateSettings()
  }

  /// Builds the brightness preset rows and adds them to the grid.
  ///
  /// This is written in code on purpose. Every label placed in the storyboard
  /// needs an entry in 19 Main.strings files, keyed by object identifier. Built
  /// here, the new text lives in Localizable.strings only.
  private func addPresetRows() {
    guard let grid = self.rowCustomBrightnessShortcuts?.gridView else {
      return
    }

    let separator = NSBox()
    separator.boxType = .separator
    let separatorRow = grid.addRow(with: [separator])
    separatorRow.mergeCells(in: NSRange(location: 0, length: grid.numberOfColumns))
    separatorRow.topPadding = 10
    separatorRow.bottomPadding = 10

    for preset in BrightnessPreset.allCases {
      let formatter = NumberFormatter()
      formatter.allowsFloats = false
      formatter.minimum = 0
      formatter.maximum = 100

      let percentage = NSTextField()
      percentage.formatter = formatter
      percentage.alignment = .right
      percentage.tag = preset.rawValue
      percentage.target = self
      percentage.action = #selector(self.presetPercentageChanged(_:))
      // The action alone fires only on Return. Without the delegate a level
      // typed and left uncommitted would never reach the settings.
      percentage.delegate = self
      percentage.translatesAutoresizingMaskIntoConstraints = false
      percentage.widthAnchor.constraint(equalToConstant: 48).isActive = true
      self.presetPercentageFields.append(percentage)

      let recorder = KeyboardShortcuts.RecorderCocoa(for: preset.shortcutName)
      recorder.placeholderString = NSLocalizedString("Record Shortcut", comment: "Shown in record shortcut box")
      recorder.translatesAutoresizingMaskIntoConstraints = false
      recorder.widthAnchor.constraint(equalToConstant: 170).isActive = true

      let controls = NSStackView(views: [percentage, NSTextField(labelWithString: "%"), recorder])
      controls.orientation = .horizontal
      controls.spacing = 6

      // Every row is built the same way, and only the first one carries the
      // caption. Giving the other rows a shared empty placeholder instead left
      // their controls unable to take a click.
      let isFirst = preset == BrightnessPreset.allCases.first
      let caption = NSTextField(labelWithString: isFirst ? NSLocalizedString("Brightness presets:", comment: "Shown in the keyboard prefs window") : "")
      caption.alignment = .right

      let row = grid.addRow(with: self.gridCells(in: grid, leading: caption, trailing: controls))
      row.cell(at: 0).xPlacement = .trailing
    }

    let hint = NSTextField(wrappingLabelWithString: NSLocalizedString("A preset sets every display to a fixed brightness. Presets work whichever way the brightness keys above are set.", comment: "Shown in the keyboard prefs window"))
    hint.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
    hint.textColor = .secondaryLabelColor
    grid.addRow(with: self.gridCells(in: grid, leading: nil, trailing: hint))
  }

  /// Returns one view per grid column, with the labels on the left and the
  /// controls in the last column, the way the rows above are arranged.
  private func gridCells(in grid: NSGridView, leading: NSView?, trailing: NSView?) -> [NSView] {
    var cells: [NSView] = (0 ..< max(1, grid.numberOfColumns)).map { _ in NSGridCell.emptyContentView }
    if let leading = leading {
      cells[0] = leading
    }
    if let trailing = trailing {
      cells[cells.count - 1] = trailing
    }
    return cells
  }

  @objc func presetPercentageChanged(_ sender: NSTextField) {
    self.storePresetPercentage(from: sender)
    self.presetOf(sender).map { sender.integerValue = $0.percentage }
  }

  /// Returns the preset a percentage box belongs to.
  ///
  /// The box has to be one of ours. Other text fields in this tab carry tag 0,
  /// which would otherwise look like the first preset.
  private func presetOf(_ field: NSTextField) -> BrightnessPreset? {
    guard self.presetPercentageFields.contains(where: { $0 === field }) else {
      return nil
    }
    return BrightnessPreset(rawValue: field.tag)
  }

  private func storePresetPercentage(from field: NSTextField) {
    guard let preset = self.presetOf(field), !field.stringValue.isEmpty else {
      return
    }
    preset.percentage = field.integerValue
  }
}

extension KeyboardPrefsViewController: NSTextFieldDelegate {
  /// Saves the level while it is typed, so a preset works even when the box
  /// was never committed with Return.
  func controlTextDidChange(_ notification: Notification) {
    guard let field = notification.object as? NSTextField else {
      return
    }
    self.storePresetPercentage(from: field)
  }

  /// Puts the stored level back in the box, which also shows the user the
  /// clamped value after an entry outside 0 to 100.
  func controlTextDidEndEditing(_ notification: Notification) {
    guard let field = notification.object as? NSTextField, let preset = self.presetOf(field) else {
      return
    }
    self.storePresetPercentage(from: field)
    field.integerValue = preset.percentage
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
    for field in self.presetPercentageFields {
      if let preset = BrightnessPreset(rawValue: field.tag) {
        field.integerValue = preset.percentage
      }
    }
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
