//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Cocoa

final class BrightnessAutomationWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
  private let manager: BrightnessAutomationManager
  private let tableView = NSTableView()
  private let enabledButton = NSButton(checkboxWithTitle: NSLocalizedString("Enabled", comment: "Shown in brightness automation window"), target: nil, action: nil)
  private let timePicker = NSDatePicker()
  private let brightnessSlider = NSSlider(value: 0.5, minValue: 0, maxValue: 1, target: nil, action: nil)
  private let brightnessPercentLabel = NSTextField(labelWithString: "50%")
  private let targetPopup = NSPopUpButton()
  private let monitorStack = NSStackView()
  private let addButton = NSButton(title: NSLocalizedString("Add", comment: "Shown in brightness automation window"), target: nil, action: nil)
  private let saveButton = NSButton(title: NSLocalizedString("Save", comment: "Shown in brightness automation window"), target: nil, action: nil)
  private let deleteButton = NSButton(title: NSLocalizedString("Delete", comment: "Shown in brightness automation window"), target: nil, action: nil)
  private let saveFeedbackLabel = NSTextField(labelWithString: "")
  private var monitorButtons: [NSButton] = []
  private var selectedAutomationID: String?

  init(manager: BrightnessAutomationManager) {
    self.manager = manager
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 720, height: 430),
      styleMask: [.titled, .closable, .miniaturizable, .resizable],
      backing: .buffered,
      defer: false
    )
    window.title = NSLocalizedString("Brightness Automations", comment: "Shown in brightness automation window")
    window.minSize = NSSize(width: 620, height: 360)
    super.init(window: window)
    self.buildInterface()
    self.reloadData()
  }

  required init?(coder _: NSCoder) {
    nil
  }

  override func showWindow(_ sender: Any?) {
    self.reloadData()
    super.showWindow(sender)
    self.window?.center()
    NSApp.activate(ignoringOtherApps: true)
  }

  func reloadData() {
    self.tableView.reloadData()
    self.reloadMonitorButtons()
    if let selectedAutomationID = self.selectedAutomationID, let automation = self.manager.automations.first(where: { $0.id == selectedAutomationID }) {
      self.load(automation)
    } else if let firstAutomation = self.manager.automations.first {
      self.select(automationID: firstAutomation.id)
    } else {
      self.selectedAutomationID = nil
      self.loadDefaultForm()
    }
    self.updateButtonState()
  }

  private func buildInterface() {
    guard let contentView = self.window?.contentView else {
      return
    }

    let rootStack = NSStackView()
    rootStack.orientation = .horizontal
    rootStack.spacing = 18
    rootStack.edgeInsets = NSEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)
    rootStack.translatesAutoresizingMaskIntoConstraints = false
    contentView.addSubview(rootStack)
    NSLayoutConstraint.activate([
      rootStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
      rootStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
      rootStack.topAnchor.constraint(equalTo: contentView.topAnchor),
      rootStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
    ])

    let scrollView = NSScrollView()
    scrollView.hasVerticalScroller = true
    scrollView.borderType = .bezelBorder
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    self.tableView.headerView = nil
    self.tableView.usesAlternatingRowBackgroundColors = true
    self.tableView.rowHeight = 34
    self.tableView.delegate = self
    self.tableView.dataSource = self
    let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("automation"))
    column.title = NSLocalizedString("Automations", comment: "Shown in brightness automation window")
    column.resizingMask = .autoresizingMask
    self.tableView.addTableColumn(column)
    scrollView.documentView = self.tableView
    rootStack.addArrangedSubview(scrollView)
    scrollView.widthAnchor.constraint(equalToConstant: 300).isActive = true

    let formStack = NSStackView()
    formStack.orientation = .vertical
    formStack.alignment = .leading
    formStack.spacing = 12
    formStack.translatesAutoresizingMaskIntoConstraints = false
    rootStack.addArrangedSubview(formStack)
    formStack.widthAnchor.constraint(greaterThanOrEqualToConstant: 330).isActive = true

    self.enabledButton.target = self
    self.enabledButton.action = #selector(self.formChanged)
    formStack.addArrangedSubview(self.enabledButton)

    self.timePicker.datePickerElements = [.hourMinute]
    self.timePicker.datePickerStyle = .textFieldAndStepper
    self.timePicker.target = self
    self.timePicker.action = #selector(self.formChanged)
    self.addFormRow(title: NSLocalizedString("Time", comment: "Shown in brightness automation window"), control: self.timePicker, to: formStack)

    let brightnessStack = NSStackView()
    brightnessStack.orientation = .horizontal
    brightnessStack.spacing = 8
    brightnessStack.translatesAutoresizingMaskIntoConstraints = false
    self.brightnessSlider.target = self
    self.brightnessSlider.action = #selector(self.brightnessChanged)
    self.brightnessSlider.widthAnchor.constraint(equalToConstant: 190).isActive = true
    self.brightnessPercentLabel.alignment = .right
    self.brightnessPercentLabel.widthAnchor.constraint(equalToConstant: 44).isActive = true
    brightnessStack.addArrangedSubview(self.brightnessSlider)
    brightnessStack.addArrangedSubview(self.brightnessPercentLabel)
    self.addFormRow(title: NSLocalizedString("Brightness", comment: "Shown in brightness automation window"), control: brightnessStack, to: formStack)

    self.targetPopup.addItem(withTitle: NSLocalizedString("All displays", comment: "Shown in brightness automation window"))
    self.targetPopup.lastItem?.tag = 0
    self.targetPopup.addItem(withTitle: NSLocalizedString("Specific displays", comment: "Shown in brightness automation window"))
    self.targetPopup.lastItem?.tag = 1
    self.targetPopup.target = self
    self.targetPopup.action = #selector(self.targetChanged)
    self.addFormRow(title: NSLocalizedString("Targets", comment: "Shown in brightness automation window"), control: self.targetPopup, to: formStack)

    self.monitorStack.orientation = .vertical
    self.monitorStack.alignment = .leading
    self.monitorStack.spacing = 6
    self.monitorStack.translatesAutoresizingMaskIntoConstraints = false
    formStack.addArrangedSubview(self.monitorStack)

    let spacer = NSView()
    spacer.translatesAutoresizingMaskIntoConstraints = false
    formStack.addArrangedSubview(spacer)
    spacer.heightAnchor.constraint(greaterThanOrEqualToConstant: 20).isActive = true

    let buttonStack = NSStackView()
    buttonStack.orientation = .horizontal
    buttonStack.spacing = 8
    buttonStack.alignment = .centerY
    self.addButton.target = self
    self.addButton.action = #selector(self.addAutomation)
    self.saveButton.target = self
    self.saveButton.action = #selector(self.saveAutomation)
    self.deleteButton.target = self
    self.deleteButton.action = #selector(self.deleteAutomation)
    self.saveFeedbackLabel.textColor = .secondaryLabelColor
    buttonStack.addArrangedSubview(self.addButton)
    buttonStack.addArrangedSubview(self.saveButton)
    buttonStack.addArrangedSubview(self.deleteButton)
    buttonStack.addArrangedSubview(self.saveFeedbackLabel)
    formStack.addArrangedSubview(buttonStack)
  }

  private func addFormRow(title: String, control: NSView, to stack: NSStackView) {
    let row = NSStackView()
    row.orientation = .horizontal
    row.alignment = .centerY
    row.spacing = 12
    let label = NSTextField(labelWithString: title)
    label.alignment = .right
    label.widthAnchor.constraint(equalToConstant: 82).isActive = true
    row.addArrangedSubview(label)
    row.addArrangedSubview(control)
    stack.addArrangedSubview(row)
  }

  private func reloadMonitorButtons() {
    for view in self.monitorStack.arrangedSubviews {
      self.monitorStack.removeArrangedSubview(view)
      view.removeFromSuperview()
    }
    self.monitorButtons = self.manager.availableDisplayTargets().map { target in
      let button = NSButton(checkboxWithTitle: target.label, target: self, action: #selector(self.formChanged))
      button.identifier = NSUserInterfaceItemIdentifier(target.prefsId)
      self.monitorStack.addArrangedSubview(button)
      return button
    }
    if self.monitorButtons.isEmpty {
      let label = NSTextField(labelWithString: NSLocalizedString("No controllable displays are currently available.", comment: "Shown in brightness automation window"))
      label.textColor = .secondaryLabelColor
      self.monitorStack.addArrangedSubview(label)
    }
  }

  private func loadDefaultForm() {
    let components = Calendar.current.dateComponents([.hour, .minute], from: Date())
    self.enabledButton.state = .on
    self.timePicker.dateValue = self.dateForTime(hour: components.hour ?? 0, minute: components.minute ?? 0)
    self.brightnessSlider.floatValue = 0.5
    self.targetPopup.selectItem(withTag: 0)
    for button in self.monitorButtons {
      button.state = .off
    }
    self.brightnessChanged(self.brightnessSlider)
    self.updateMonitorButtonState()
  }

  private func load(_ automation: BrightnessAutomation) {
    self.enabledButton.state = automation.isEnabled ? .on : .off
    self.timePicker.dateValue = self.dateForTime(hour: automation.hour, minute: automation.minute)
    self.brightnessSlider.floatValue = automation.brightness
    self.targetPopup.selectItem(withTag: automation.targetMode == .all ? 0 : 1)
    let selectedDisplayIds = Set(automation.targetDisplayPrefsIds)
    for button in self.monitorButtons {
      button.state = selectedDisplayIds.contains(button.identifier?.rawValue ?? "") ? .on : .off
    }
    self.brightnessChanged(self.brightnessSlider)
    self.updateMonitorButtonState()
  }

  private func select(automationID: String) {
    self.selectedAutomationID = automationID
    if let row = self.manager.automations.firstIndex(where: { $0.id == automationID }) {
      self.tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
    }
    if let automation = self.manager.automations.first(where: { $0.id == automationID }) {
      self.load(automation)
    }
    self.updateButtonState()
  }

  private func automationFromForm(existingID: String?) -> BrightnessAutomation? {
    let specificTargets = self.monitorButtons.filter { $0.state == .on }.compactMap { button -> (String, String)? in
      guard let prefsId = button.identifier?.rawValue else {
        return nil
      }
      return (prefsId, button.title)
    }
    if self.targetPopup.selectedTag() == 1, specificTargets.isEmpty {
      self.showAlert(message: NSLocalizedString("Select at least one display.", comment: "Shown in brightness automation window"))
      return nil
    }
    let timeComponents = Calendar.current.dateComponents([.hour, .minute], from: self.timePicker.dateValue)
    let existing = existingID.flatMap { id in self.manager.automations.first { $0.id == id } }
    return BrightnessAutomation(
      id: existingID ?? UUID().uuidString,
      isEnabled: self.enabledButton.state == .on,
      hour: timeComponents.hour ?? 0,
      minute: timeComponents.minute ?? 0,
      brightness: self.brightnessSlider.floatValue,
      targetMode: self.targetPopup.selectedTag() == 0 ? .all : .specific,
      targetDisplayPrefsIds: specificTargets.map(\.0),
      targetDisplayLabels: specificTargets.map(\.1),
      lastRunDate: existing?.lastRunDate
    )
  }

  private func updateButtonState() {
    let hasSelection = self.selectedAutomationID != nil
    self.saveButton.isEnabled = hasSelection
    self.deleteButton.isEnabled = hasSelection
  }

  private func updateMonitorButtonState() {
    let isSpecific = self.targetPopup.selectedTag() == 1
    self.monitorStack.isHidden = !isSpecific
    for button in self.monitorButtons {
      button.isEnabled = isSpecific
    }
  }

  private func dateForTime(hour: Int, minute: Int) -> Date {
    var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
    components.hour = hour
    components.minute = minute
    components.second = 0
    return Calendar.current.date(from: components) ?? Date()
  }

  private func showAlert(message: String) {
    let alert = NSAlert()
    alert.messageText = message
    alert.addButton(withTitle: NSLocalizedString("OK", comment: "Shown in alert dialog"))
    if let window = self.window {
      alert.beginSheetModal(for: window)
    } else {
      alert.runModal()
    }
  }

  @objc private func addAutomation() {
    guard let automation = self.automationFromForm(existingID: nil) else {
      return
    }
    self.manager.upsert(automation)
    self.reloadData()
    self.select(automationID: automation.id)
    self.showSaveFeedback()
  }

  @objc private func saveAutomation() {
    guard let selectedAutomationID = self.selectedAutomationID, let automation = self.automationFromForm(existingID: selectedAutomationID) else {
      return
    }
    self.manager.upsert(automation)
    self.reloadData()
    self.select(automationID: automation.id)
  }

  @objc private func deleteAutomation() {
    guard let selectedAutomationID = self.selectedAutomationID else {
      return
    }
    self.manager.delete(id: selectedAutomationID)
    self.selectedAutomationID = nil
    self.reloadData()
  }

  @objc private func brightnessChanged(_: Any) {
    self.brightnessPercentLabel.stringValue = String(format: "%.0f%%", Double(self.brightnessSlider.floatValue) * 100)
  }

  @objc private func targetChanged(_: Any) {
    self.updateMonitorButtonState()
  }

  @objc private func formChanged(_: Any) {}

  private func showSaveFeedback() {
    self.saveFeedbackLabel.stringValue = NSLocalizedString("Saved", comment: "Shown in brightness automation window")
    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
      self?.saveFeedbackLabel.stringValue = ""
    }
  }

  func numberOfRows(in _: NSTableView) -> Int {
    self.manager.automations.count
  }

  func tableView(_: NSTableView, viewFor _: NSTableColumn?, row: Int) -> NSView? {
    let identifier = NSUserInterfaceItemIdentifier("automationCell")
    let cell = self.tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView ?? NSTableCellView()
    cell.identifier = identifier
    let textField: NSTextField
    if let existingTextField = cell.textField {
      textField = existingTextField
    } else {
      textField = NSTextField(labelWithString: "")
      textField.lineBreakMode = .byTruncatingTail
      textField.translatesAutoresizingMaskIntoConstraints = false
      cell.addSubview(textField)
      cell.textField = textField
      NSLayoutConstraint.activate([
        textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
        textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
        textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
      ])
    }
    textField.stringValue = self.manager.summary(for: self.manager.automations[row])
    textField.textColor = self.manager.automations[row].isEnabled ? .labelColor : .secondaryLabelColor
    return cell
  }

  func tableViewSelectionDidChange(_: Notification) {
    let row = self.tableView.selectedRow
    guard row >= 0, row < self.manager.automations.count else {
      self.selectedAutomationID = nil
      self.updateButtonState()
      return
    }
    self.selectedAutomationID = self.manager.automations[row].id
    self.load(self.manager.automations[row])
    self.updateButtonState()
  }
}
