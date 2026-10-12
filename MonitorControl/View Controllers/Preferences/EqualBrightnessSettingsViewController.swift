//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Cocoa

/// Equal-brightness graph, editor layout, and window controller.
/// 等亮度曲线图、编辑器布局和窗口控制器。

// MARK: - Graph / 曲线图

/// A sampled curve used by the graph view without coupling the graph to display hardware.
/// 图表使用的采样曲线，避免图表直接依赖显示器硬件。
struct EqualBrightnessGraphCurve {
  let title: String
  let color: NSColor
  let evaluator: (Double) -> Double
  let isReference: Bool
}

/// A colored calibration marker belonging to one target-display curve.
/// 属于某条目标显示器曲线的彩色校准点。
struct EqualBrightnessGraphPoint {
  let point: EqualBrightnessCalibrationPoint
  let color: NSColor
}

/// Draws the normalized brightness grid, reference line, target curves, and calibration points.
/// 绘制归一化亮度网格、参考直线、目标曲线和校准点。
final class EqualBrightnessGraphView: NSView {
  var curves: [EqualBrightnessGraphCurve] = [] {
    didSet {
      self.needsDisplay = true
    }
  }

  var points: [EqualBrightnessGraphPoint] = [] {
    didSet {
      self.needsDisplay = true
    }
  }

  var selectedPointID: UUID? {
    didSet {
      self.needsDisplay = true
    }
  }

  var selectedSourceValue: Double? {
    didSet {
      self.needsDisplay = true
    }
  }

  var onPointSelected: ((UUID?, Double?) -> Void)?

  /// Keeps graph coordinates readable in both light and dark appearances.
  /// 让图表坐标在浅色和深色外观下都保持可读。
  override var isFlipped: Bool {
    true
  }

  /// Draws the grid and all current curve samples.
  /// 绘制网格以及当前的所有曲线采样点。
  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)
    NSColor.windowBackgroundColor.setFill()
    dirtyRect.fill()
    let rect = self.plotRect()
    self.drawGrid(in: rect)
    self.drawReferenceGuides(in: rect)
    for curve in self.curves {
      self.drawCurve(curve, in: rect)
    }
    self.drawLegend(in: rect)
    for point in self.points {
      self.drawPoint(point, in: rect)
    }
  }

  /// Selects the closest reference point guide when the graph is clicked.
  /// 点击图表时选中距离最近的参考点纵向引导线。
  override func mouseDown(with event: NSEvent) {
    let location = self.convert(event.locationInWindow, from: nil)
    let rect = self.plotRect()
    guard rect.insetBy(dx: -12, dy: 0).contains(location) else {
      return
    }
    var seenSources: [Double] = []
    let candidates: [(marker: EqualBrightnessGraphPoint, distance: CGFloat)] = self.points.compactMap { marker in
      let source = marker.point.sourceValue
      guard !seenSources.contains(where: { abs($0 - source) <= 0.000_001 }) else {
        return nil
      }
      seenSources.append(source)
      let pointX = self.graphPoint(source: source, target: marker.point.targetValue, in: rect).x
      return (marker: marker, distance: abs(pointX - location.x))
    }
    let nearest = candidates
      .filter { candidate in candidate.distance <= 12 }
      .min { left, right in left.distance < right.distance }
    self.selectedPointID = nearest?.marker.point.id
    self.onPointSelected?(self.selectedPointID, nearest?.marker.point.sourceValue)
  }

  /// Calculates the inset plotting rectangle used by the graph.
  /// 计算图表实际绘图区的内边距矩形。
  private func plotRect() -> NSRect {
    self.bounds.insetBy(dx: 36, dy: 24)
  }

  /// Draws five-by-five grid divisions and the two coordinate axes.
  /// 绘制五乘五网格以及两条坐标轴。
  private func drawGrid(in rect: NSRect) {
    let gridColor = NSColor.separatorColor.withAlphaComponent(0.55)
    gridColor.setStroke()
    let path = NSBezierPath()
    path.lineWidth = 0.5
    for index in 0...4 {
      let ratio = CGFloat(index) / 4
      let x = rect.minX + rect.width * ratio
      let y = rect.minY + rect.height * ratio
      path.move(to: NSPoint(x: x, y: rect.minY))
      path.line(to: NSPoint(x: x, y: rect.maxY))
      path.move(to: NSPoint(x: rect.minX, y: y))
      path.line(to: NSPoint(x: rect.maxX, y: y))
    }
    path.stroke()

    NSColor.secondaryLabelColor.setStroke()
    let axes = NSBezierPath()
    axes.lineWidth = 1
    axes.move(to: NSPoint(x: rect.minX, y: rect.minY))
    axes.line(to: NSPoint(x: rect.maxX, y: rect.minY))
    axes.move(to: NSPoint(x: rect.minX, y: rect.minY))
    axes.line(to: NSPoint(x: rect.minX, y: rect.maxY))
    axes.stroke()
  }

  /// Draws one gray vertical guide for every reference point.
  /// 为每个参考点绘制一条灰色纵向引导线。
  private func drawReferenceGuides(in rect: NSRect) {
    let guideColor = NSColor.systemGray.withAlphaComponent(0.6)
    guideColor.setStroke()
    var drawnSources: [Double] = []
    for marker in self.points {
      let point = marker.point
      guard !drawnSources.contains(where: { abs($0 - point.sourceValue) <= 0.000_001 }) else {
        continue
      }
      drawnSources.append(point.sourceValue)
      let x = self.graphPoint(source: point.sourceValue, target: point.targetValue, in: rect).x
      let guide = NSBezierPath()
      let isSelected = self.selectedSourceValue.map { abs($0 - point.sourceValue) <= 0.000_001 } ?? false
      guide.lineWidth = isSelected ? 1.5 : 1
      guide.setLineDash([3, 3], count: 2, phase: 0)
      guide.move(to: NSPoint(x: x, y: rect.minY))
      guide.line(to: NSPoint(x: x, y: rect.maxY))
      guide.stroke()
    }
  }

  /// Samples one normalized curve and renders it as a smooth polyline.
  /// 对一条归一化曲线采样，并绘制为连续折线。
  private func drawCurve(_ curve: EqualBrightnessGraphCurve, in rect: NSRect) {
    let path = NSBezierPath()
    path.lineWidth = curve.isReference ? 1 : 2
    curve.color.withAlphaComponent(curve.isReference ? 0.65 : 0.9).setStroke()
    for index in 0...60 {
      let source = Double(index) / 60
      let target = EqualBrightnessCurve.clamp(curve.evaluator(source))
      let point = self.graphPoint(source: source, target: target, in: rect)
      if index == 0 {
        path.move(to: point)
      } else {
        path.line(to: point)
      }
    }
    if curve.isReference {
      path.setLineDash([4, 3], count: 2, phase: 0)
    }
    path.stroke()
  }

  /// Renders one calibration point as a colored marker.
  /// 将一个校准点绘制为彩色标记。
  private func drawPoint(_ marker: EqualBrightnessGraphPoint, in rect: NSRect) {
    let point = marker.point
    let center = self.graphPoint(source: point.sourceValue, target: point.targetValue, in: rect)
    let isSelected = self.selectedSourceValue.map { abs($0 - point.sourceValue) <= 0.000_001 } ?? false
    if isSelected {
      let selection = NSBezierPath(ovalIn: NSRect(x: center.x - 8, y: center.y - 8, width: 16, height: 16))
      NSColor.controlAccentColor.setStroke()
      selection.lineWidth = 2
      selection.stroke()
    }
    let markerPath = NSBezierPath(ovalIn: NSRect(x: center.x - 4, y: center.y - 4, width: 8, height: 8))
    marker.color.setFill()
    markerPath.fill()
    NSColor.labelColor.setStroke()
    markerPath.lineWidth = 1
    markerPath.stroke()
  }

  /// Draws a compact legend using the actual display names for every curve.
  /// 使用每台显示器的实际名称绘制紧凑图例。
  private func drawLegend(in rect: NSRect) {
    var origin = NSPoint(x: rect.minX + 8, y: rect.minY + 8)
    let attributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
      .foregroundColor: NSColor.labelColor
    ]
    for curve in self.curves {
      let title = NSString(string: curve.title)
      let size = title.size(withAttributes: attributes)
      let swatch = NSBezierPath(roundedRect: NSRect(x: origin.x, y: origin.y + 4, width: 12, height: 3), xRadius: 1.5, yRadius: 1.5)
      curve.color.setStroke()
      swatch.lineWidth = 2
      swatch.stroke()
      title.draw(at: NSPoint(x: origin.x + 16, y: origin.y), withAttributes: attributes)
      origin.x += 16 + size.width + 18
      if origin.x > rect.maxX - 100 {
        origin.x = rect.minX + 8
        origin.y += 18
      }
    }
  }

  /// Converts normalized values into the flipped view coordinate system.
  /// 将归一化数值转换为翻转坐标系中的绘图位置。
  private func graphPoint(source: Double, target: Double, in rect: NSRect) -> NSPoint {
    let x = rect.minX + rect.width * CGFloat(EqualBrightnessCurve.clamp(source))
    let y = rect.maxY - rect.height * CGFloat(EqualBrightnessCurve.clamp(target))
    return NSPoint(x: x, y: y)
  }
}

// MARK: - Editor / 编辑器

/// Hosts the functional equal-brightness editor window.
/// 承载可操作的等亮度设置窗口。
final class EqualBrightnessSettingsViewController: NSViewController {
  private struct SliderRow {
    let label: NSTextField
    let slider: NSSlider
  }

  var onSave: (() -> Void)?
  var onCancel: (() -> Void)?

  private let graphView = EqualBrightnessGraphView(frame: .zero)
  private let curvePopup = NSPopUpButton(frame: .zero, pullsDown: false)
  private let pointsSummary = NSTextField(labelWithString: "")
  private let targetDisplayColors: [NSColor] = EqualBrightnessSettingsViewController.makeTargetDisplayColors()
  private var liveSliderRows: [SliderRow] = []
  private var sliderDisplays: [ObjectIdentifier: Display] = [:]
  private var slidersByDisplayID: [CGDirectDisplayID: NSSlider] = [:]
  private var displayColors: [CGDirectDisplayID: NSColor] = [:]
  private var removePointButton: NSButton?
  private var workingCurves: [String: EqualBrightnessCurve] = [:]
  private var curveKind: EqualBrightnessCurveKind = .monotoneCubic
  private var displayObjects: [Display] = []
  private var referenceDisplay: Display?
  private var selectedPointID: UUID?
  private var selectedSourceValue: Double?
  private var labelColumnWidth: CGFloat = 0

  /// Keeps the palette available on the project's macOS 10.14 deployment target.
  /// 让调色板兼容项目的 macOS 10.14 最低部署版本。
  private static func makeTargetDisplayColors() -> [NSColor] {
    var colors: [NSColor] = [
      .systemOrange,
      .systemGreen,
      .systemPurple,
      .systemRed,
      .systemPink,
      .systemTeal,
      .systemYellow,
      .systemBrown,
      .systemMint
    ]

    if #available(macOS 10.15, *) {
      colors.insert(.systemIndigo, at: 7)
    } else {
      colors.insert(NSColor(calibratedRed: 0.35, green: 0.25, blue: 0.85, alpha: 1), at: 7)
    }

    if #available(macOS 12.0, *) {
      colors.append(.systemCyan)
    } else {
      colors.append(NSColor(calibratedRed: 0.05, green: 0.65, blue: 0.85, alpha: 1))
    }

    return colors
  }

  /// Builds the standalone page without a target-display selector.
  /// 创建不再包含目标显示器选择器的独立页面。
  override func loadView() {
    self.configureInteractiveControls()
    self.updateLabelColumnWidth()

    let controls = self.makeCalibrationControls()
    let footer = self.makeFooter()
    let rootView = EqualBrightnessSettingsPageView(
      graphView: self.graphView,
      controlsView: controls,
      pointsSummary: self.pointsSummary,
      actionBar: footer
    )

    // Keep graph selection in the view controller so every curve follows one reference level.
    // 将图表选中状态交给视图控制器，使所有曲线跟随同一个参考亮度。
    self.graphView.onPointSelected = { [weak self] pointID, sourceValue in
      guard let self else { return }
      self.selectedPointID = pointID
      self.selectedSourceValue = sourceValue
      self.applySelectedPointToAllDisplays()
      self.refreshGraph()
      self.updateRemovePointButtonState()
    }

    self.view = rootView
    self.refreshDisplayControls()
  }

  /// Configures every control and loads all connected target curves into memory.
  /// 配置全部控件，并将所有已连接目标显示器的曲线加载到内存。
  private func configureInteractiveControls() {
    self.loadDisplays()
    self.loadWorkingCurves()

    self.curvePopup.removeAllItems()
    self.curvePopup.addItems(withTitles: EqualBrightnessCurveKind.allCases.map { $0.localizedTitle })
    if let index = EqualBrightnessCurveKind.allCases.firstIndex(of: self.curveKind) {
      self.curvePopup.selectItem(at: index)
    }
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

  /// Creates rows for the reference display and every external display.
  /// 创建参考显示器以及每台外接显示器的滑块行。
  private func makeCalibrationControls() -> NSGridView {
    let addPointButton = NSButton(
      title: NSLocalizedString("Add Reference Point", comment: "Equal brightness add point button"),
      target: self,
      action: #selector(self.addReferencePoint(_:))
    )
    let removePointButton = NSButton(
      title: NSLocalizedString("Delete Selected Point", comment: "Equal brightness delete point button"),
      target: self,
      action: #selector(self.removeSelectedPoint(_:))
    )
    self.removePointButton = removePointButton

    let displays = self.calibrationDisplays()
    self.liveSliderRows = displays.map { display in
      let slider = NSSlider(
        value: self.currentBrightness(for: display),
        minValue: 0,
        maxValue: 1,
        target: self,
        action: #selector(self.sliderChanged(_:))
      )
      slider.isContinuous = true
      let targetIndex = self.displayObjects.firstIndex(where: { $0.identifier == display.identifier }) ?? 0
      let color = display == self.referenceDisplay ? NSColor.systemBlue : self.color(for: display, targetIndex: targetIndex)
      slider.trackFillColor = color
      let brightnessTitle = NSLocalizedString("Brightness", comment: "Display brightness label")
      let name = EqualBrightnessDisplaySupport.userFacingName(for: display, fallbackIndex: targetIndex)
      let label = self.makeAlignedLabel("\(name) \(brightnessTitle)")
      self.sliderDisplays[ObjectIdentifier(slider)] = display
      self.slidersByDisplayID[display.identifier] = slider
      return SliderRow(label: label, slider: slider)
    }

    var rows: [[NSView]] = self.liveSliderRows.map { [$0.label, $0.slider] }
    let curveLabel = self.makeAlignedLabel(NSLocalizedString("Curve type", comment: "Equal brightness curve selector label"))
    rows.append([curveLabel, self.curvePopup])

    let actions = NSStackView(views: [addPointButton, removePointButton])
    actions.orientation = .horizontal
    actions.alignment = .centerY
    actions.spacing = 8
    actions.distribution = .fillProportionally
    rows.append([NSGridCell.emptyContentView, actions])

    let grid = NSGridView(views: rows)
    self.configureAlignedGrid(grid)
    grid.rowSpacing = 8
    grid.row(at: grid.numberOfRows - 1).topPadding = 4
    return grid
  }

  /// Creates Save and Cancel actions in a standard AppKit stack view.
  /// 使用标准 AppKit 堆叠视图创建“保存”和“取消”操作。
  private func makeFooter() -> NSStackView {
    let cancelButton = NSButton(
      title: NSLocalizedString("Cancel", comment: "Equal brightness cancel button"),
      target: self,
      action: #selector(self.cancel(_:))
    )
    let saveButton = NSButton(
      title: NSLocalizedString("Save", comment: "Equal brightness save button"),
      target: self,
      action: #selector(self.save(_:))
    )
    saveButton.keyEquivalent = "\r"
    cancelButton.keyEquivalent = "\u{1b}"

    // Keep both actions wide enough for every localized title and center them as one group.
    // 为所有本地化标题保留足够按钮宽度，并将两个按钮作为整体居中。
    for button in [cancelButton, saveButton] {
      button.widthAnchor.constraint(equalToConstant: EqualBrightnessSettingsLayout.actionButtonWidth).isActive = true
    }
    let leadingSpacer = NSView(frame: .zero)
    let trailingSpacer = NSView(frame: .zero)
    for spacer in [leadingSpacer, trailingSpacer] {
      spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
      spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }
    let stack = NSStackView(views: [leadingSpacer, cancelButton, saveButton, trailingSpacer])
    stack.orientation = .horizontal
    stack.alignment = .centerY
    stack.spacing = 12
    stack.distribution = .fill
    return stack
  }

  /// Creates one label that fills the calculated column and uses justified alignment.
  /// 创建填满计算列宽并使用两端对齐的标签。
  private func makeAlignedLabel(_ title: String) -> NSTextField {
    let label = NSTextField(labelWithString: title)
    label.alignment = .justified
    label.lineBreakMode = .byClipping
    label.maximumNumberOfLines = 1
    label.setContentHuggingPriority(.defaultLow, for: .horizontal)
    label.setContentCompressionResistancePriority(.required, for: .horizontal)
    return label
  }

  /// Calculates the label column from the widest localized display row title.
  /// 根据本地化后最宽的显示器行标题计算标签列宽度。
  private func updateLabelColumnWidth() {
    let brightnessTitle = NSLocalizedString("Brightness", comment: "Display brightness label")
    let displayTitles = self.calibrationDisplays().enumerated().map { index, display in
      EqualBrightnessDisplaySupport.userFacingName(for: display, fallbackIndex: index) + " " + brightnessTitle
    }
    let titles = displayTitles + [
      NSLocalizedString("Curve type", comment: "Equal brightness curve selector label")
    ]
    let font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
    let widestTitle = titles.map { title in
      NSString(string: title).size(withAttributes: [.font: font]).width
    }.max() ?? 0
    self.labelColumnWidth = ceil(widestTitle) + EqualBrightnessSettingsLayout.labelColumnPadding
  }

  /// Applies the existing preferences page's label column and system control spacing.
  /// 复用原有设置页的标签列宽度和控件间距。
  private func configureAlignedGrid(_ grid: NSGridView) {
    grid.columnSpacing = 12
    grid.column(at: 0).width = self.labelColumnWidth
    grid.column(at: 0).xPlacement = .fill
    grid.column(at: 1).xPlacement = .fill
    grid.column(at: 1).leadingPadding = 4
    grid.rowAlignment = .firstBaseline
  }

  /// Refreshes the graph after the view has been loaded.
  /// 视图加载后刷新曲线图。
  override func viewDidLoad() {
    super.viewDidLoad()
    self.refreshGraph()
  }

  /// Discovers the current displays and removes the reference display from the target list.
  /// 发现当前显示器，并将参考显示器从目标列表中移除。
  private func loadDisplays() {
    let allDisplays = DisplayManager.shared.displays.filter { !$0.isDummy }
    self.referenceDisplay = EqualBrightnessDisplaySupport.referenceDisplay(from: allDisplays)
    self.displayObjects = EqualBrightnessDisplaySupport.targetDisplays(from: allDisplays, reference: self.referenceDisplay)
  }

  /// Builds one readable identity key for a display.
  /// 为显示器生成一个可读的身份键。
  private func displayKey(_ display: Display) -> String {
    EqualBrightnessDisplayIdentity(display: display).key
  }

  /// Loads every target curve independently so reconnecting one display restores all its points.
  /// 独立加载每台目标显示器的曲线，确保只重连一台显示器时也能恢复全部参考点。
  private func loadWorkingCurves() {
    self.workingCurves.removeAll()
    var loadedKind: EqualBrightnessCurveKind?
    for display in self.displayObjects {
      var curve = EqualBrightnessSettingsStore.shared.curve(for: display)
        ?? EqualBrightnessCurve(kind: .monotoneCubic, points: [])
      curve.points = EqualBrightnessCurve.pointsWithFixedEndpoints(curve.points)
      self.workingCurves[self.displayKey(display)] = curve
      loadedKind = loadedKind ?? curve.kind
    }
    self.curveKind = loadedKind ?? .monotoneCubic
    for key in self.workingCurves.keys {
      self.workingCurves[key]?.kind = self.curveKind
    }
    self.selectedPointID = nil
    self.selectedSourceValue = nil
  }

  /// Returns the reference display followed by every target display in slider order.
  /// 按滑块顺序返回参考显示器和全部目标显示器。
  private func calibrationDisplays() -> [Display] {
    ([self.referenceDisplay] + self.displayObjects).compactMap { $0 }
  }

  /// Returns a working curve, creating a fixed-endpoint default when needed.
  /// 返回工作曲线；没有持久化曲线时创建包含固定端点的默认曲线。
  private func workingCurve(for display: Display) -> EqualBrightnessCurve {
    let key = self.displayKey(display)
    if let curve = self.workingCurves[key] {
      return curve
    }
    let curve = EqualBrightnessCurve(
      kind: self.curveKind,
      points: EqualBrightnessCurve.pointsWithFixedEndpoints([])
    )
    self.workingCurves[key] = curve
    return curve
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

  /// Returns whether a source value is one of the protected zero or full brightness endpoints.
  /// 判断参考亮度是否为受保护的零亮度或满亮度端点。
  private func isFixedSource(_ sourceValue: Double) -> Bool {
    abs(sourceValue) <= 0.000_001 || abs(sourceValue - 1) <= 0.000_001
  }

  /// Returns whether a point is one of the protected endpoints.
  /// 判断参考点是否为受保护的端点。
  private func isFixedEndpoint(_ point: EqualBrightnessCalibrationPoint) -> Bool {
    self.isFixedSource(point.sourceValue)
  }

  /// Enables deletion only when a selected interior source exists in at least one curve.
  /// 只有选中了至少一条曲线中的内部参考亮度时才启用删除按钮。
  private func updateRemovePointButtonState() {
    guard let source = self.selectedSourceValue, !self.isFixedSource(source) else {
      self.removePointButton?.isEnabled = false
      return
    }
    let hasPoint = self.displayObjects.contains { display in
      self.workingCurve(for: display).points.contains {
        abs($0.sourceValue - source) <= 0.000_001 && !self.isFixedEndpoint($0)
      }
    }
    self.removePointButton?.isEnabled = hasPoint
  }

  /// Updates the working curve type without writing preferences.
  /// 更新所有工作曲线的类型，但不写入持久化偏好。
  @objc private func curveChanged(_ sender: NSPopUpButton) {
    let index = sender.indexOfSelectedItem
    guard index >= 0, index < EqualBrightnessCurveKind.allCases.count else {
      return
    }
    self.curveKind = EqualBrightnessCurveKind.allCases[index]
    for key in self.workingCurves.keys {
      self.workingCurves[key]?.kind = self.curveKind
    }
    self.refreshGraph()
  }

  /// Applies any display slider immediately and redraws the preview.
  /// 立即应用任意显示器滑块的值并刷新预览图。
  @objc private func sliderChanged(_ sender: NSSlider) {
    guard let display = self.display(for: sender) else {
      return
    }
    self.applyBrightness(sender.doubleValue, to: display)
    self.selectedPointID = nil
    self.selectedSourceValue = nil
    self.refreshGraph()
  }

  /// Applies a calibration slider value to the actual display immediately.
  /// 将校准滑块值立即应用到实际显示器。
  private func applyBrightness(_ value: Double, to display: Display) {
    _ = display.setDirectBrightness(Float(EqualBrightnessCurve.clamp(value)))
  }

  /// Moves every live slider to the selected source level and applies each display's mapping.
  /// 将所有实时滑块移动到选中的参考亮度，并应用每台显示器自己的映射。
  private func applySelectedPointToAllDisplays() {
    guard let sourceValue = self.selectedSourceValue else {
      return
    }
    for display in self.calibrationDisplays() {
      let value: Double
      if display == self.referenceDisplay {
        value = sourceValue
      } else {
        value = self.workingCurve(for: display).value(at: sourceValue)
      }
      guard let slider = self.slider(for: display) else {
        continue
      }
      slider.doubleValue = EqualBrightnessCurve.clamp(value)
      self.applyBrightness(value, to: display)
    }
  }

  /// Adds the current reference level to every target curve with one shared point ID.
  /// 将当前参考亮度同时写入所有目标曲线，并使用同一个点 ID 表示这组关系。
  @objc private func addReferencePoint(_: NSButton) {
    guard let referenceDisplay = self.referenceDisplay,
          !self.displayObjects.isEmpty,
          let sourceSlider = self.slider(for: referenceDisplay) else {
      return
    }

    let sourceValue = EqualBrightnessCurve.clamp(sourceSlider.doubleValue)
    let pointID = UUID()
    let tolerance = 0.000_001
    for display in self.displayObjects {
      guard let targetSlider = self.slider(for: display) else {
        continue
      }
      var curve = self.workingCurve(for: display)
      curve.kind = self.curveKind
      let point = EqualBrightnessCalibrationPoint(
        id: pointID,
        sourceValue: sourceValue,
        targetValue: targetSlider.doubleValue
      )
      if let index = curve.points.firstIndex(where: { abs($0.sourceValue - sourceValue) <= tolerance }) {
        if !self.isFixedSource(sourceValue) {
          curve.points[index] = point
        }
      } else {
        curve.points.append(point)
      }
      curve.points = EqualBrightnessCurve.pointsWithFixedEndpoints(curve.points)
      self.workingCurves[self.displayKey(display)] = curve
    }
    self.selectedPointID = pointID
    self.selectedSourceValue = sourceValue
    self.refreshGraph()
  }

  /// Deletes the selected interior source from every target curve without touching saved settings.
  /// 从所有目标曲线删除选中的内部参考亮度，不影响已保存设置。
  @objc private func removeSelectedPoint(_: NSButton) {
    guard let source = self.selectedSourceValue, !self.isFixedSource(source) else {
      return
    }
    let tolerance = 0.000_001
    for display in self.displayObjects {
      var curve = self.workingCurve(for: display)
      curve.points.removeAll {
        abs($0.sourceValue - source) <= tolerance && !self.isFixedEndpoint($0)
      }
      curve.points = EqualBrightnessCurve.pointsWithFixedEndpoints(curve.points)
      self.workingCurves[self.displayKey(display)] = curve
    }
    self.selectedPointID = nil
    self.selectedSourceValue = nil
    self.refreshGraph()
  }

  /// Saves every target curve under that display's explicit hardware identity.
  /// 按每台显示器明确的硬件身份保存全部目标曲线。
  @objc private func save(_: NSButton) {
    guard let referenceDisplay = self.referenceDisplay else {
      self.onSave?()
      self.view.window?.close()
      return
    }
    let mappings = self.displayObjects.map { display in
      var curve = self.workingCurve(for: display)
      curve.kind = self.curveKind
      curve.points = EqualBrightnessCurve.pointsWithFixedEndpoints(curve.points)
      return (display: display, curve: curve)
    }
    _ = EqualBrightnessSettingsStore.shared.saveCurves(mappings, referenceDisplay: referenceDisplay)
    self.onSave?()
    self.view.window?.close()
  }

  /// Closes the editor without persisting the working points.
  /// 关闭编辑器且不保存当前工作参考点。
  @objc private func cancel(_: NSButton) {
    self.onCancel?()
    self.view.window?.close()
  }

  /// Returns a readable mapping summary for one target curve.
  /// 返回一条目标曲线的可读映射摘要。
  private func pointSummary(for curve: EqualBrightnessCurve) -> String {
    let points = EqualBrightnessCurve.pointsWithFixedEndpoints(curve.points)
    guard !points.isEmpty else {
      return NSLocalizedString("No reference points yet.", comment: "Equal brightness empty point summary")
    }
    return points.map {
      String(format: "%.0f%% → %.0f%%", $0.sourceValue * 100, $0.targetValue * 100)
    }.joined(separator: "   ")
  }

  /// Prefixes each mapping with a display pair when multiple external displays are present.
  /// 连接多台外接显示器时，为每条映射加上显示器配对名称。
  private func mappingSummary() -> String {
    guard !self.displayObjects.isEmpty else {
      return NSLocalizedString("No reference points yet.", comment: "Equal brightness empty point summary")
    }
    let referenceName = self.referenceDisplay.map {
      EqualBrightnessDisplaySupport.userFacingName(for: $0)
    } ?? NSLocalizedString("Mac Reference", comment: "Equal brightness reference curve")
    let includePairNames = self.displayObjects.count > 1
    return self.displayObjects.enumerated().map { index, display in
      let targetName = EqualBrightnessDisplaySupport.userFacingName(for: display, fallbackIndex: index)
      let prefix = includePairNames ? "\(referenceName) → \(targetName): " : ""
      return prefix + self.pointSummary(for: self.workingCurve(for: display))
    }.joined(separator: "\n")
  }

  /// Rebuilds every graph curve, marker, and the human-readable point summary.
  /// 重建全部图表曲线、参考点以及可读的映射摘要。
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
    var markers: [EqualBrightnessGraphPoint] = []
    for (index, display) in self.displayObjects.enumerated() {
      let displayName = EqualBrightnessDisplaySupport.userFacingName(for: display, fallbackIndex: index)
      let displayColor = self.color(for: display, targetIndex: index)
      let curve = self.workingCurve(for: display)
      curves.append(
        EqualBrightnessGraphCurve(
          title: displayName,
          color: displayColor,
          evaluator: { curve.value(at: $0) },
          isReference: false
        )
      )
      markers.append(contentsOf: curve.points.map {
        EqualBrightnessGraphPoint(point: $0, color: displayColor)
      })
    }

    self.graphView.curves = curves
    self.graphView.points = markers
    self.graphView.selectedPointID = self.selectedPointID
    self.graphView.selectedSourceValue = self.selectedSourceValue
    self.updateRemovePointButtonState()

    let instruction = NSLocalizedString("Equal brightness instructions", comment: "Equal brightness usage instructions")
    self.pointsSummary.stringValue = "\(self.mappingSummary())\n\n\(instruction)"
  }
}

/// Keeps the editor dimensions aligned with the existing preferences grid.
/// 集中管理编辑器尺寸，使其与原有设置页网格保持一致。
private enum EqualBrightnessSettingsLayout {
  static let contentSize = NSSize(width: 760, height: 800)
  static let minimumContentSize = NSSize(width: 680, height: 760)
  static let contentInset: CGFloat = 24
  static let sectionSpacing: CGFloat = 16
  static let graphHeight: CGFloat = 300
  static let summaryHeight: CGFloat = 128
  static let footerHeight: CGFloat = 32
  static let labelColumnPadding: CGFloat = 4
  static let actionButtonWidth: CGFloat = 120
}

/// Provides the standalone page while reusing NSGridView and NSStackView conventions from the preferences UI.
/// 使用与偏好设置页相同的 NSGridView 和 NSStackView 规范提供独立页面。
private final class EqualBrightnessSettingsPageView: NSView {
  private let graphView: EqualBrightnessGraphView
  private let controlsView: NSGridView
  private let pointsSummary: NSTextField
  private let actionBar: NSStackView

  init(graphView: EqualBrightnessGraphView, controlsView: NSGridView, pointsSummary: NSTextField, actionBar: NSStackView) {
    self.graphView = graphView
    self.controlsView = controlsView
    self.pointsSummary = pointsSummary
    self.actionBar = actionBar
    super.init(frame: NSRect(origin: .zero, size: EqualBrightnessSettingsLayout.contentSize))
    self.autoresizingMask = [.width, .height]
    self.addSubview(graphView)
    self.addSubview(controlsView)
    self.addSubview(pointsSummary)
    self.addSubview(actionBar)
  }

  required init?(coder: NSCoder) {
    fatalError("EqualBrightnessSettingsPageView does not support storyboard decoding")
  }

  override var isFlipped: Bool {
    true
  }

  /// Calculates the minimum content height required by the discovered display rows.
  /// 根据当前显示器行数计算页面所需的最小高度。
  var requiredContentHeight: CGFloat {
    let gridHeight = self.controlsView.fittingSize.height
    return EqualBrightnessSettingsLayout.contentInset * 2
      + EqualBrightnessSettingsLayout.graphHeight
      + gridHeight
      + EqualBrightnessSettingsLayout.summaryHeight
      + EqualBrightnessSettingsLayout.footerHeight
      + EqualBrightnessSettingsLayout.sectionSpacing * 3
  }

  override func layout() {
    super.layout()
    let inset = EqualBrightnessSettingsLayout.contentInset
    let spacing = EqualBrightnessSettingsLayout.sectionSpacing
    let width = max(0, self.bounds.width - inset * 2)
    var y = inset

    self.graphView.frame = NSRect(x: inset, y: y, width: width, height: EqualBrightnessSettingsLayout.graphHeight)
    y += EqualBrightnessSettingsLayout.graphHeight + spacing

    let controlsHeight = self.controlsView.fittingSize.height
    self.controlsView.frame = NSRect(x: inset, y: y, width: width, height: controlsHeight)
    y += controlsHeight + spacing

    let footerY = max(y + EqualBrightnessSettingsLayout.summaryHeight + spacing, self.bounds.height - inset - EqualBrightnessSettingsLayout.footerHeight)
    let summaryY = footerY - spacing - EqualBrightnessSettingsLayout.summaryHeight
    self.pointsSummary.frame = NSRect(x: inset, y: summaryY, width: width, height: EqualBrightnessSettingsLayout.summaryHeight)
    self.pointsSummary.preferredMaxLayoutWidth = width
    self.actionBar.frame = NSRect(x: inset, y: footerY, width: width, height: EqualBrightnessSettingsLayout.footerHeight)
  }
}

/// Owns the equal-brightness window and keeps the view controller alive while it is shown.
/// 管理等亮度窗口，并在窗口显示期间保持视图控制器有效。
final class EqualBrightnessSettingsWindowController: NSWindowController, NSWindowDelegate {
  var onSave: (() -> Void)?
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
    viewController.onSave = { [weak self] in
      self?.didFinish = true
      EqualBrightnessSyncCoordinator.shared.endCalibrationSession()
      self?.onSave?()
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
