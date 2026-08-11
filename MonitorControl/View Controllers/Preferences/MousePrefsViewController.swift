//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Cocoa
import Settings

private final class MousePrefsRootView: NSView {
  override var intrinsicContentSize: NSSize {
    NSSize(width: 480, height: 220)
  }
}

class MousePrefsViewController: NSViewController, SettingsPane {
  let paneIdentifier = Settings.PaneIdentifier.mouse
  let paneTitle: String = NSLocalizedString("Mouse", comment: "Shown in the main prefs window")

  var toolbarItemIcon: NSImage {
    if !DEBUG_MACOS10, #available(macOS 11.0, *) {
      return NSImage(systemSymbolName: "computermouse", accessibilityDescription: "Mouse") ?? NSImage(named: NSImage.infoName)!
    } else {
      return NSImage(named: NSImage.infoName)!
    }
  }

  private let leftEdgeAction = NSPopUpButton()
  private let rightEdgeAction = NSPopUpButton()
  private let scrollPrecision = NSPopUpButton()
  private let volumeSoundFeedback = NSButton(checkboxWithTitle: "", target: nil, action: nil)

  override func loadView() {
    self.view = MousePrefsRootView(frame: NSRect(x: 0, y: 0, width: 480, height: 220))
    self.view.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      self.view.widthAnchor.constraint(equalToConstant: 480),
      self.view.heightAnchor.constraint(equalToConstant: 220),
    ])
    self.buildView()
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    self.populateSettings()
  }

  func populateSettings() {
    self.leftEdgeAction.selectItem(withTag: prefs.integer(forKey: PrefKey.edgeScrollLeftAction.rawValue))
    self.rightEdgeAction.selectItem(withTag: prefs.integer(forKey: PrefKey.edgeScrollRightAction.rawValue))
    self.scrollPrecision.selectItem(withTag: prefs.integer(forKey: PrefKey.edgeScrollPrecision.rawValue))
    self.volumeSoundFeedback.state = prefs.bool(forKey: PrefKey.edgeScrollVolumeSoundFeedback.rawValue) ? .on : .off
  }

  private func buildView() {
    self.configureActionPopUp(self.leftEdgeAction)
    self.configureActionPopUp(self.rightEdgeAction)
    self.configurePrecisionPopUp(self.scrollPrecision)

    self.leftEdgeAction.target = self
    self.leftEdgeAction.action = #selector(self.leftEdgeActionChanged(_:))
    self.rightEdgeAction.target = self
    self.rightEdgeAction.action = #selector(self.rightEdgeActionChanged(_:))
    self.scrollPrecision.target = self
    self.scrollPrecision.action = #selector(self.scrollPrecisionChanged(_:))
    self.volumeSoundFeedback.target = self
    self.volumeSoundFeedback.action = #selector(self.volumeSoundFeedbackChanged(_:))
    self.volumeSoundFeedback.setAccessibilityLabel(NSLocalizedString("Volume feedback sound", comment: "Shown in Mouse Settings"))

    let stack = NSStackView()
    stack.orientation = .vertical
    stack.alignment = .leading
    stack.spacing = 14
    stack.edgeInsets = NSEdgeInsets(top: 24, left: 28, bottom: 24, right: 28)
    stack.translatesAutoresizingMaskIntoConstraints = false
    self.view.addSubview(stack)

    stack.addArrangedSubview(self.makeRow(title: NSLocalizedString("Left screen edge", comment: "Shown in Mouse Settings"), control: self.leftEdgeAction))
    stack.addArrangedSubview(self.makeRow(title: NSLocalizedString("Right screen edge", comment: "Shown in Mouse Settings"), control: self.rightEdgeAction))
    stack.addArrangedSubview(self.makeRow(title: NSLocalizedString("Scroll wheel precision", comment: "Shown in Mouse Settings"), control: self.scrollPrecision))
    stack.addArrangedSubview(self.makeRow(title: NSLocalizedString("Volume feedback sound", comment: "Shown in Mouse Settings"), control: self.volumeSoundFeedback))

    let infoLabel = NSTextField(labelWithString: NSLocalizedString("Move the pointer to a screen edge and use the scroll wheel to control the selected value on that screen.", comment: "Shown in Mouse Settings"))
    infoLabel.textColor = .secondaryLabelColor
    infoLabel.maximumNumberOfLines = 2
    infoLabel.lineBreakMode = .byWordWrapping
    infoLabel.translatesAutoresizingMaskIntoConstraints = false
    stack.addArrangedSubview(infoLabel)
    NSLayoutConstraint.activate([
      stack.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
      stack.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
      stack.topAnchor.constraint(equalTo: self.view.topAnchor),
      stack.bottomAnchor.constraint(lessThanOrEqualTo: self.view.bottomAnchor),
      infoLabel.widthAnchor.constraint(equalToConstant: 420),
    ])
  }

  private func makeRow(title: String, control: NSView) -> NSStackView {
    let label = NSTextField(labelWithString: title)
    label.alignment = .right
    label.translatesAutoresizingMaskIntoConstraints = false
    control.translatesAutoresizingMaskIntoConstraints = false
    let row = NSStackView(views: [label, control])
    row.orientation = .horizontal
    row.alignment = .centerY
    row.spacing = 12
    NSLayoutConstraint.activate([
      label.widthAnchor.constraint(equalToConstant: 160),
      control.widthAnchor.constraint(equalToConstant: 190),
    ])
    return row
  }

  private func configureActionPopUp(_ popUpButton: NSPopUpButton) {
    popUpButton.removeAllItems()
    self.addItem(to: popUpButton, title: NSLocalizedString("Disabled", comment: "Shown in Mouse Settings"), tag: EdgeScrollAction.disabled.rawValue)
    self.addItem(to: popUpButton, title: NSLocalizedString("Brightness", comment: "Shown in Mouse Settings"), tag: EdgeScrollAction.brightness.rawValue)
    self.addItem(to: popUpButton, title: NSLocalizedString("Volume", comment: "Shown in Mouse Settings"), tag: EdgeScrollAction.volume.rawValue)
  }

  private func configurePrecisionPopUp(_ popUpButton: NSPopUpButton) {
    popUpButton.removeAllItems()
    self.addItem(to: popUpButton, title: NSLocalizedString("Standard (2%)", comment: "Shown in Mouse Settings"), tag: EdgeScrollPrecision.standard.rawValue)
    self.addItem(to: popUpButton, title: NSLocalizedString("Fine (1%)", comment: "Shown in Mouse Settings"), tag: EdgeScrollPrecision.fine.rawValue)
    self.addItem(to: popUpButton, title: NSLocalizedString("Very fine (0.5%)", comment: "Shown in Mouse Settings"), tag: EdgeScrollPrecision.veryFine.rawValue)
    self.addItem(to: popUpButton, title: NSLocalizedString("Coarse (5%)", comment: "Shown in Mouse Settings"), tag: EdgeScrollPrecision.coarse.rawValue)
  }

  private func addItem(to popUpButton: NSPopUpButton, title: String, tag: Int) {
    popUpButton.addItem(withTitle: title)
    popUpButton.lastItem?.tag = tag
  }

  @objc private func leftEdgeActionChanged(_ sender: NSPopUpButton) {
    prefs.set(sender.selectedTag(), forKey: PrefKey.edgeScrollLeftAction.rawValue)
    self.edgeScrollSettingsChanged()
  }

  @objc private func rightEdgeActionChanged(_ sender: NSPopUpButton) {
    prefs.set(sender.selectedTag(), forKey: PrefKey.edgeScrollRightAction.rawValue)
    self.edgeScrollSettingsChanged()
  }

  @objc private func scrollPrecisionChanged(_ sender: NSPopUpButton) {
    prefs.set(sender.selectedTag(), forKey: PrefKey.edgeScrollPrecision.rawValue)
    self.edgeScrollSettingsChanged()
  }

  @objc private func volumeSoundFeedbackChanged(_ sender: NSButton) {
    prefs.set(sender.state == .on, forKey: PrefKey.edgeScrollVolumeSoundFeedback.rawValue)
  }

  private func edgeScrollSettingsChanged() {
    app.checkPermissions()
    app.edgeScrollManager.update()
  }
}
