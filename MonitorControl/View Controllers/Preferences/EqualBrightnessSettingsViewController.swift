//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Cocoa

/// Hosts the first functional equal-brightness editor window.
/// 承载第一版可操作的等亮度设置窗口。
final class EqualBrightnessSettingsViewController: NSViewController {
  var onSave: (([EqualBrightnessCalibrationPoint], EqualBrightnessCurveKind) -> Void)?
  var onCancel: (() -> Void)?

  private let graphView = EqualBrightnessGraphView(frame: .zero)
  private let displayPopup = NSPopUpButton(frame: .zero, pullsDown: false)
  private let curvePopup = NSPopUpButton(frame: .zero, pullsDown: false)
  private let pointsSummary = NSTextField(labelWithString: "")
  private let targetDisplayColors: [NSColor] = [
    .systemOrange,
    .systemGreen,
    .systemPurple,
    .systemRed,
    .systemPink,
    .systemTeal,
    .systemYellow,
    .systemIndigo,
    .systemBrown,
    .systemMint,
    .systemCyan
  ]
  private var liveSliderRows: [EqualBrightnessAlignedSliderRow] = []
  private var sliderDisplays: [ObjectIdentifier: Display] = [:]
  private var slidersByDisplayID: [CGDirectDisplayID: NSSlider] = [:]
  private var displayColors: [CGDirectDisplayID: NSColor] = [:]
  private var removePointButton: NSButton?
  private var points: [EqualBrightnessCalibrationPoint] = []
  private var curveKind: EqualBrightnessCurveKind = .monotoneCubic
  private var displayObjects: [Display] = []
  private var referenceDisplay: Display?
  private var selectedPointID: UUID?

  /// Builds the standalone page without inheriting layout from the host preferences window.
  /// 创建独立页面，不继承宿主偏好设置窗口的布局。
  override func loadView() {
    self.configureInteractiveControls()

    let header = self.makeDisplayHeader()
    let controls = self.makeCalibrationControls()
    let footer = self.makeFooter()
    let rootView = EqualBrightnessSettingsPageView(
      displaySelector: header,
      graphView: self.graphView,
      controlsView: controls,
      pointsSummary: self.pointsSummary,
      actionBar: footer
    )

    // Keep graph selection in the view controller so button state follows the selected point.
    // 将图表选中状态交给视图控制器管理，使按钮状态随选中点更新。
    self.graphView.onPointSelected = { [weak self] pointID in
      self?.selectedPointID = pointID
      self?.applySelectedPointToAllDisplays()
      self?.refreshGraph()
      self?.updateRemovePointButtonState()
      self?.graphView.selectedPointID = pointID
    }
    self.view = rootView
    self.loadWorkingCurveForSelectedDisplay()
    self.refreshDisplayControls()
  }

  /// Configures all controls that send editing events to this view controller.
  /// 配置所有向当前视图控制器发送编辑事件的控件。
  private func configureInteractiveControls() {
    let displayNames = self.loadDisplayNames()
    self.displayPopup.removeAllItems()
    self.displayPopup.addItems(withTitles: displayNames)
    self.displayPopup.target = self
    self.displayPopup.action = #selector(self.displayChanged(_:))

    self.curvePopup.removeAllItems()
    self.curvePopup.addItems(withTitles: EqualBrightnessCurveKind.allCases.map { $0.localizedTitle })
    self.curvePopup.selectItem(at: 0)
    self.curvePopup.target = self
    self.curvePopup.action = #selector(self.curveChanged(_:))

    self.pointsSummary.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
    self.pointsSummary.textColor = .secondaryLabelColor
    self.pointsSummary.lineBreakMode = .byWordWrapping
    self.pointsSummary.maximumNumberOfLines = 0
    self.pointsSummary.usesSingleLineMode = false
    self.pointsSummary.cell?.wraps = true
    self.pointsSummary.cell?.isScrollable = false
  }

  /// Creates one aligned live slider per discovered display plus the calibration actions.
  /// 为发现到的每台显示器创建一个对齐的实时滑块，并创建校准操作。
  private func makeCalibrationControls() -> EqualBrightnessCalibrationControlsView {
    let addPointButton = NSButton(title: NSLocalizedString("Add Reference Point", comment: "Equal brightness add point button"), target: self, action: #selector(self.addReferencePoint(_:)))
    let removePointButton = NSButton(title: NSLocalizedString("Delete Selected Point", comment: "Equal brightness delete point button"), target: self, action: #selector(self.removeSelectedPoint(_:)))
    self.removePointButton = removePointButton
    let curveLabel = NSTextField(labelWithString: NSLocalizedString("Curve type", comment: "Equal brightness curve selector label"))
    let curveRow = EqualBrightnessAlignedControlRow(label: curveLabel, control: self.curvePopup)
    let displays = ([self.referenceDisplay] + self.displayObjects).compactMap { $0 }
    self.liveSliderRows = displays.map { display in
      let slider = NSSlider(value: self.currentBrightness(for: display), minValue: 0, maxValue: 1, target: self, action: #selector(self.sliderChanged(_:)))
      slider.isContinuous = true
      let targetIndex = self.displayObjects.firstIndex(where: { $0.identifier == display.identifier }) ?? 0
      let color = display == self.referenceDisplay ? NSColor.systemBlue : self.color(for: display, targetIndex: targetIndex)
      slider.trackFillColor = color
      let label = NSTextField(labelWithString: "")
      self.sliderDisplays[ObjectIdentifier(slider)] = display
      self.slidersByDisplayID[display.identifier] = slider
      return EqualBrightnessAlignedSliderRow(label: label, slider: slider)
    }
    return EqualBrightnessCalibrationControlsView(
      sliderRows: self.liveSliderRows,
      curveRow: curveRow,
      addButton: addPointButton,
      removeButton: removePointButton
    )
  }

  /// Creates the target-display selector using the same fixed label column as the sliders.
  /// 使用与滑块相同的固定标签列创建目标显示器选择器。
  private func makeDisplayHeader() -> EqualBrightnessDisplaySelectorView {
    let label = NSTextField(labelWithString: NSLocalizedString("Target display", comment: "Equal brightness target display label"))
    return EqualBrightnessDisplaySelectorView(label: label, popup: self.displayPopup)
  }

  /// Creates Save and Cancel actions with a stable bottom-right layout.
  /// 创建具有稳定右下角布局的“保存”和“取消”操作。
  private func makeFooter() -> EqualBrightnessActionBar {
    let cancelButton = NSButton(title: NSLocalizedString("Cancel", comment: "Equal brightness cancel button"), target: self, action: #selector(self.cancel(_:)))
    let saveButton = NSButton(title: NSLocalizedString("Save", comment: "Equal brightness save button"), target: self, action: #selector(self.save(_:)))
    saveButton.keyEquivalent = "\r"
    cancelButton.keyEquivalent = "\u{1b}"
    return EqualBrightnessActionBar(cancelButton: cancelButton, saveButton: saveButton)
  }

  /// Refreshes the graph after the view has been loaded.
  /// 视图加载后刷新曲线图。
  override func viewDidLoad() {
    super.viewDidLoad()
    self.refreshGraph()
  }

  /// Loads display names while keeping the editor usable before display discovery completes.
  /// 读取显示器名称，并在显示器发现尚未完成时保持编辑器可用。
  private func loadDisplayNames() -> [String] {
    let allDisplays = DisplayManager.shared.displays.filter { !$0.isDummy }
    self.referenceDisplay = EqualBrightnessDisplaySupport.referenceDisplay(from: allDisplays)
    self.displayObjects = EqualBrightnessDisplaySupport.targetDisplays(from: allDisplays, reference: self.referenceDisplay)
    let names = self.displayObjects.enumerated().map { index, display in
      EqualBrightnessDisplaySupport.userFacingName(for: display, fallbackIndex: index)
    }
    if names.isEmpty {
      return [NSLocalizedString("External Display", comment: "Fallback display name")]
    }
    return names
  }

  /// Handles a change to the selected target display.
  /// 处理目标显示器选择变化。
  @objc private func displayChanged(_: NSPopUpButton) {
    self.loadWorkingCurveForSelectedDisplay()
    self.refreshDisplayControls()
    self.refreshGraph()
  }

  /// Returns the currently selected display object when display discovery supplied one.
  /// 当显示器发现提供了对象时，返回当前选中的显示器对象。
  private func selectedDisplay() -> Display? {
    let index = self.displayPopup.indexOfSelectedItem
    guard index >= 0, index < self.displayObjects.count else {
      return nil
    }
    return self.displayObjects[index]
  }

  /// Returns the reference display followed by every target display in slider order.
  /// 按滑块顺序返回参考显示器和全部目标显示器。
  private func calibrationDisplays() -> [Display] {
    ([self.referenceDisplay] + self.displayObjects).compactMap { $0 }
  }

  /// Finds the live slider associated with one physical display.
  /// 查找与某台实际显示器关联的实时滑块。
  private func slider(for display: Display) -> NSSlider? {
    self.slidersByDisplayID[display.identifier]
  }

  /// Finds the physical display controlled by a slider event.
  /// 根据滑块事件查找对应的实际显示器。
  private func display(for slider: NSSlider) -> Display? {
    self.sliderDisplays[ObjectIdentifier(slider)]
  }

  /// Returns a stable, distinct color for each target display.
  /// 为每台目标显示器返回稳定且彼此区分的颜色。
  private func color(for display: Display, targetIndex: Int) -> NSColor {
    if let existingColor = self.displayColors[display.identifier] {
      return existingColor
    }
    let color: NSColor
    if targetIndex < self.targetDisplayColors.count {
      color = self.targetDisplayColors[targetIndex]
    } else {
      // Golden-ratio hue spacing keeps additional displays visually distinct.
      // 使用黄金比例间隔色相，让更多显示器仍保持视觉区分度。
      let hue = CGFloat((Double(targetIndex) * 0.618_033_988_75).truncatingRemainder(dividingBy: 1))
      color = NSColor(calibratedHue: hue, saturation: 0.72, brightness: 0.92, alpha: 1)
    }
    self.displayColors[display.identifier] = color
    return color
  }

  /// Updates slider labels and initial values using the actual display identities.
  /// 使用实际显示器名称更新滑块标签和初始值。
  private func refreshDisplayControls() {
    let brightnessTitle = NSLocalizedString("Brightness", comment: "Display brightness label")
    for (index, display) in self.calibrationDisplays().enumerated() where index < self.liveSliderRows.count {
      let name = EqualBrightnessDisplaySupport.userFacingName(for: display, fallbackIndex: index)
      let row = self.liveSliderRows[index]
      row.label.stringValue = "\(name) \(brightnessTitle)"
      row.slider.doubleValue = self.currentBrightness(for: display)
    }
    self.displayPopup.isEnabled = !self.displayObjects.isEmpty
    self.updateRemovePointButtonState()
  }

  /// Reads the current normalized brightness without changing the display.
  /// 读取当前归一化亮度，不修改显示器状态。
  private func currentBrightness(for display: Display) -> Double {
    if let appleDisplay = display as? AppleDisplay {
      return Double(appleDisplay.getAppleBrightness())
    }
    return Double(display.getBrightness())
  }

  /// Returns whether a point is one of the protected zero or full brightness endpoints.
  /// 判断参考点是否为受保护的零亮度或满亮度端点。
  private func isFixedEndpoint(_ point: EqualBrightnessCalibrationPoint) -> Bool {
    abs(point.sourceValue) <= 0.000_001 || abs(point.sourceValue - 1) <= 0.000_001
  }

  /// Enables deletion only for a selected editable reference point.
  /// 只有选中了可编辑参考点时才启用删除按钮。
  private func updateRemovePointButtonState() {
    guard let selectedPointID = self.selectedPointID,
          let point = self.points.first(where: { $0.id == selectedPointID }) else {
      self.removePointButton?.isEnabled = false
      return
    }
    self.removePointButton?.isEnabled = !self.isFixedEndpoint(point)
  }

  /// Loads the selected display curve into the editable working state.
  /// 将当前显示器的已保存曲线加载到可编辑工作状态。
  private func loadWorkingCurveForSelectedDisplay() {
    guard let display = self.selectedDisplay(), let curve = EqualBrightnessSettingsStore.shared.curve(for: display) else {
      self.points = EqualBrightnessCurve.pointsWithFixedEndpoints([])
      self.curveKind = .monotoneCubic
      if let index = EqualBrightnessCurveKind.allCases.firstIndex(of: self.curveKind) {
        self.curvePopup.selectItem(at: index)
      }
      self.selectedPointID = nil
      return
    }
    self.points = EqualBrightnessCurve.pointsWithFixedEndpoints(curve.points)
    self.curveKind = curve.kind
    self.selectedPointID = nil
    if let index = EqualBrightnessCurveKind.allCases.firstIndex(of: curve.kind) {
      self.curvePopup.selectItem(at: index)
    }
  }

  /// Updates the working curve type without writing preferences.
  /// 更新工作曲线类型，但不写入持久化偏好。
  @objc private func curveChanged(_ sender: NSPopUpButton) {
    let index = sender.indexOfSelectedItem
    guard index >= 0, index < EqualBrightnessCurveKind.allCases.count else {
      return
    }
    self.curveKind = EqualBrightnessCurveKind.allCases[index]
    self.refreshGraph()
  }

  /// Applies any display slider immediately and redraws the preview.
  /// 立即应用任意显示器滑块的值并刷新预览图。
  @objc private func sliderChanged(_ sender: NSSlider) {
    guard let display = self.display(for: sender) else {
      return
    }
    self.applyBrightness(sender.doubleValue, to: display)
    // Manual changes leave the previously selected point so the next saved point reflects the sliders.
    // 手动调整后取消旧的选中点，确保下一次保存记录当前滑块值。
    self.selectedPointID = nil
    self.refreshGraph()
  }

  /// Applies a calibration slider value to the actual display immediately.
  /// 将校准滑块值立即应用到实际显示器。
  private func applyBrightness(_ value: Double, to display: Display) {
    _ = display.setDirectBrightness(Float(EqualBrightnessCurve.clamp(value)))
  }

  /// Moves every live slider to the selected point and applies each value to its display.
  /// 将所有实时滑块移动到选中参考点，并把对应值写入每台显示器。
  private func applySelectedPointToAllDisplays() {
    guard let selectedPointID = self.selectedPointID,
          let selectedPoint = self.points.first(where: { $0.id == selectedPointID }) else {
      return
    }
    let selectedTarget = self.selectedDisplay()
    let sourceValue = selectedPoint.sourceValue
    for display in self.calibrationDisplays() {
      let value: Double
      if display == self.referenceDisplay {
        value = sourceValue
      } else if display == selectedTarget {
        value = selectedPoint.targetValue
      } else if let savedCurve = EqualBrightnessSettingsStore.shared.curve(for: display) {
        value = savedCurve.value(at: sourceValue)
      } else {
        // An uncalibrated target follows the reference value until it has its own curve.
        // 尚未校准的目标显示器在拥有独立曲线前跟随参考亮度。
        value = sourceValue
      }
      guard let slider = self.slider(for: display) else {
        continue
      }
      slider.doubleValue = EqualBrightnessCurve.clamp(value)
      self.applyBrightness(value, to: display)
    }
  }

  /// Adds a reference point from the current pair of calibration sliders.
  /// 根据当前参考显示器和选中目标显示器的滑块值添加一个参考点。
  @objc private func addReferencePoint(_: NSButton) {
    guard let referenceDisplay = self.referenceDisplay,
          let targetDisplay = self.selectedDisplay(),
          let sourceSlider = self.slider(for: referenceDisplay),
          let targetSlider = self.slider(for: targetDisplay) else {
      return
    }
    let point = EqualBrightnessCalibrationPoint(sourceValue: sourceSlider.doubleValue, targetValue: targetSlider.doubleValue)
    let tolerance = 0.000_001
    if let index = self.points.firstIndex(where: { abs($0.sourceValue - point.sourceValue) <= tolerance }) {
      if self.isFixedEndpoint(self.points[index]) {
        self.selectedPointID = self.points[index].id
      } else {
        self.points[index].targetValue = point.targetValue
        self.selectedPointID = self.points[index].id
      }
    } else {
      self.points.append(point)
      self.selectedPointID = point.id
    }
    self.points = EqualBrightnessCurve.pointsWithFixedEndpoints(self.points)
    self.refreshGraph()
  }

  /// Deletes the selected non-endpoint point without touching saved settings.
  /// 删除选中的非端点参考点，不影响已保存设置。
  @objc private func removeSelectedPoint(_: NSButton) {
    guard let selectedPointID = self.selectedPointID,
          let index = self.points.firstIndex(where: { $0.id == selectedPointID }),
          !self.isFixedEndpoint(self.points[index]) else {
      return
    }
    self.points.remove(at: index)
    self.selectedPointID = nil
    self.points = EqualBrightnessCurve.pointsWithFixedEndpoints(self.points)
    self.refreshGraph()
  }

  /// Sends the working points to the window controller for the save transaction.
  /// 将工作参考点交给窗口控制器执行保存事务。
  @objc private func save(_: NSButton) {
    self.points = EqualBrightnessCurve.pointsWithFixedEndpoints(self.points)
    let curve = EqualBrightnessCurve(kind: self.curveKind, points: self.points)
    if let targetDisplay = self.selectedDisplay(), let referenceDisplay = self.referenceDisplay {
      _ = EqualBrightnessSettingsStore.shared.saveCurve(curve, for: targetDisplay, referenceDisplay: referenceDisplay)
    }
    self.onSave?(self.points, self.curveKind)
    self.view.window?.close()
  }

  /// Closes the editor without persisting the working points.
  /// 关闭编辑器且不保存当前工作参考点。
  @objc private func cancel(_: NSButton) {
    self.onCancel?()
    self.view.window?.close()
  }

  /// Rebuilds the graph curves and the human-readable point summary.
  /// 重建图表曲线和可读的参考点摘要。
  private func refreshGraph() {
    let referenceTitle = self.referenceDisplay.map {
      EqualBrightnessDisplaySupport.userFacingName(for: $0)
    } ?? NSLocalizedString("Mac Reference", comment: "Equal brightness reference curve")
    var curves: [EqualBrightnessGraphCurve] = [
      EqualBrightnessGraphCurve(
        title: referenceTitle,
        color: .systemBlue,
        evaluator: { $0 },
        isReference: true
      )
    ]
    for (index, display) in self.displayObjects.enumerated() {
      let name = EqualBrightnessDisplaySupport.userFacingName(for: display, fallbackIndex: index)
      let displayColor = self.color(for: display, targetIndex: index)
      let curve: EqualBrightnessCurve
      if index == self.displayPopup.indexOfSelectedItem {
        curve = EqualBrightnessCurve(kind: self.curveKind, points: self.points)
      } else if let savedCurve = EqualBrightnessSettingsStore.shared.curve(for: display) {
        curve = savedCurve
      } else {
        curve = EqualBrightnessCurve(kind: .piecewiseLinear, points: [])
      }
      curves.append(
        EqualBrightnessGraphCurve(
          title: name,
          color: displayColor,
          evaluator: { curve.value(at: $0) },
          isReference: false
        )
      )
    }
    self.graphView.curves = curves
    self.graphView.points = self.points
    self.graphView.selectedPointID = self.selectedPointID
    if let selectedDisplay = self.selectedDisplay() {
      self.graphView.pointColor = self.color(for: selectedDisplay, targetIndex: self.displayPopup.indexOfSelectedItem)
    } else {
      self.graphView.pointColor = .systemOrange
    }
    self.updateRemovePointButtonState()
    let pointSummary: String
    if self.points.isEmpty {
      pointSummary = NSLocalizedString("No reference points yet.", comment: "Equal brightness empty point summary")
    } else {
      pointSummary = self.points.map {
        String(format: "%.0f%% → %.0f%%", $0.sourceValue * 100, $0.targetValue * 100)
      }.joined(separator: "   ")
    }

    // Reuse the visible point-summary control so the guidance has exactly the same typography and color.
    // 复用已经可见的参考点摘要控件，确保提示使用完全相同的字体和颜色。
    let instruction = NSLocalizedString("Equal brightness instructions", comment: "Equal brightness usage instructions")
    // Leave one empty line between the point summary and the bilingual usage guide.
    // 在参考点摘要和双语使用说明之间保留一个空行。
    self.pointsSummary.stringValue = "\(pointSummary)\n\n\(instruction)"
  }
}

/// Owns the equal-brightness window and keeps the view controller alive while it is shown.
/// 管理等亮度窗口，并在窗口显示期间保持视图控制器有效。
final class EqualBrightnessSettingsWindowController: NSWindowController, NSWindowDelegate {
  var onSave: (([EqualBrightnessCalibrationPoint], EqualBrightnessCurveKind) -> Void)?
  var onCancel: (() -> Void)?
  private var didFinish = false

  /// Creates a resizable AppKit settings window with the functional editor view.
  /// 创建一个可调整大小、包含功能编辑器视图的 AppKit 设置窗口。
  init() {
    let viewController = EqualBrightnessSettingsViewController()
    let window = NSWindow(
      contentRect: NSRect(origin: .zero, size: EqualBrightnessSettingsLayout.contentSize),
      styleMask: [.titled, .closable, .resizable],
      backing: .buffered,
      defer: false
    )
    window.contentMinSize = EqualBrightnessSettingsLayout.minimumContentSize
    window.contentViewController = viewController
    window.title = NSLocalizedString("Equal Brightness Settings", comment: "Equal brightness window title")
    super.init(window: window)
    window.delegate = self
    viewController.onSave = { [weak self] points, curveKind in
      self?.didFinish = true
      EqualBrightnessSyncCoordinator.shared.endCalibrationSession()
      self?.onSave?(points, curveKind)
    }
    viewController.onCancel = { [weak self] in
      self?.didFinish = true
      EqualBrightnessSyncCoordinator.shared.endCalibrationSession()
      self?.onCancel?()
    }
  }

  /// Required initializer for storyboard and nib compatibility.
  /// 为兼容 storyboard 和 nib 提供必需的初始化方法。
  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }

  /// Presents the window and activates the application for immediate editing.
  /// 显示窗口并激活应用，确保用户可以立即编辑。
  func showSettings() {
    self.didFinish = false
    EqualBrightnessSyncCoordinator.shared.beginCalibrationSession()
    if let pageView = self.window?.contentViewController?.view as? EqualBrightnessSettingsPageView,
       let window = self.window {
      let currentSize = window.contentView?.bounds.size ?? EqualBrightnessSettingsLayout.contentSize
      let requiredHeight = max(EqualBrightnessSettingsLayout.minimumContentSize.height, pageView.requiredContentHeight)
      window.contentMinSize = NSSize(width: EqualBrightnessSettingsLayout.minimumContentSize.width, height: requiredHeight)
      if currentSize.height < requiredHeight {
        window.setContentSize(NSSize(width: max(currentSize.width, EqualBrightnessSettingsLayout.contentSize.width), height: requiredHeight))
      }
    }
    self.window?.center()
    self.showWindow(nil)
    self.window?.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  /// Treats a window-close button click as a cancellation when no explicit action ran.
  /// 如果用户直接关闭窗口且没有点击明确按钮，则按取消处理。
  func windowWillClose(_: Notification) {
    EqualBrightnessSyncCoordinator.shared.endCalibrationSession()
    guard !self.didFinish else {
      return
    }
    self.didFinish = true
    self.onCancel?()
  }
}
