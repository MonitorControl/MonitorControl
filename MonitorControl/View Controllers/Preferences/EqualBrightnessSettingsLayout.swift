//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Cocoa

// MARK: - Settings editor / 设置编辑器

/// Keeps the editor's content dimensions in one place so the view and window stay in sync.
/// 集中管理编辑器内容尺寸，确保视图和窗口尺寸保持一致。
enum EqualBrightnessSettingsLayout {
  static let contentSize = NSSize(width: 760, height: 800)
  static let minimumContentSize = NSSize(width: 680, height: 760)
  static let contentInset: CGFloat = 24
  static let sectionSpacing: CGFloat = 16
  static let headerHeight: CGFloat = 32
  static let graphHeight: CGFloat = 300
  static let summaryHeight: CGFloat = 128
  static let footerHeight: CGFloat = 32
}

/// Lays out one slider row with a shared label column and track origin.
/// 使用统一的标签列和滑块起点布局一行亮度滑块。
final class EqualBrightnessAlignedSliderRow: NSView {
  static let labelColumnWidth: CGFloat = 190

  let label: NSTextField
  let slider: NSSlider

  init(label: NSTextField, slider: NSSlider) {
    self.label = label
    self.slider = slider
    super.init(frame: .zero)
    self.label.lineBreakMode = .byTruncatingTail
    self.addSubview(label)
    self.addSubview(slider)
  }

  required init?(coder: NSCoder) {
    fatalError("EqualBrightnessAlignedSliderRow does not support storyboard decoding")
  }

  override var isFlipped: Bool {
    true
  }

  override func layout() {
    super.layout()
    let labelWidth = Self.labelColumnWidth
    let sliderX = labelWidth + 12
    let sliderHeight: CGFloat = 24
    self.label.frame = NSRect(x: 0, y: 0, width: labelWidth, height: self.bounds.height)
    self.slider.frame = NSRect(
      x: sliderX,
      y: max(0, (self.bounds.height - sliderHeight) / 2),
      width: max(0, self.bounds.width - sliderX),
      height: sliderHeight
    )
  }
}

/// Lays out a labeled control using the same column as the live sliders.
/// 使用与实时滑块相同的标签列布局带标签控件。
final class EqualBrightnessAlignedControlRow: NSView {
  private let label: NSTextField
  private let control: NSView

  init(label: NSTextField, control: NSView) {
    self.label = label
    self.control = control
    super.init(frame: .zero)
    self.label.lineBreakMode = .byTruncatingTail
    self.addSubview(label)
    self.addSubview(control)
  }

  required init?(coder: NSCoder) {
    fatalError("EqualBrightnessAlignedControlRow does not support storyboard decoding")
  }

  override var isFlipped: Bool {
    true
  }

  override func layout() {
    super.layout()
    let labelWidth = EqualBrightnessAlignedSliderRow.labelColumnWidth
    let controlX = labelWidth + 12
    self.label.frame = NSRect(x: 0, y: 0, width: labelWidth, height: self.bounds.height)
    self.control.frame = NSRect(
      x: controlX,
      y: max(0, (self.bounds.height - 28) / 2),
      width: max(0, self.bounds.width - controlX),
      height: 28
    )
  }
}

/// Owns the calibration controls and keeps all live sliders aligned.
/// 管理校准控件，并确保所有实时滑块对齐。
final class EqualBrightnessCalibrationControlsView: NSView {
  private let sliderRows: [EqualBrightnessAlignedSliderRow]
  private let curveRow: EqualBrightnessAlignedControlRow
  private let addButton: NSButton
  private let removeButton: NSButton

  init(sliderRows: [EqualBrightnessAlignedSliderRow], curveRow: EqualBrightnessAlignedControlRow, addButton: NSButton, removeButton: NSButton) {
    self.sliderRows = sliderRows
    self.curveRow = curveRow
    self.addButton = addButton
    self.removeButton = removeButton
    super.init(frame: .zero)
    for row in sliderRows {
      self.addSubview(row)
    }
    self.addSubview(curveRow)
    self.addSubview(addButton)
    self.addSubview(removeButton)
  }

  required init?(coder: NSCoder) {
    fatalError("EqualBrightnessCalibrationControlsView does not support storyboard decoding")
  }

  override var isFlipped: Bool {
    true
  }

  /// Returns the exact height needed for all display sliders and actions.
  /// 返回所有显示器滑块和操作按钮所需的准确高度。
  var contentHeight: CGFloat {
    let rowHeight: CGFloat = 32
    let rowSpacing: CGFloat = 8
    return CGFloat(self.sliderRows.count + 2) * rowHeight + CGFloat(self.sliderRows.count + 1) * rowSpacing
  }

  override func layout() {
    super.layout()
    let rowHeight: CGFloat = 32
    let rowSpacing: CGFloat = 8
    for (index, row) in self.sliderRows.enumerated() {
      row.frame = NSRect(x: 0, y: CGFloat(index) * (rowHeight + rowSpacing), width: self.bounds.width, height: rowHeight)
    }
    let curveY = CGFloat(self.sliderRows.count) * (rowHeight + rowSpacing)
    self.curveRow.frame = NSRect(x: 0, y: curveY, width: self.bounds.width, height: rowHeight)
    let buttonY = curveY + rowHeight + rowSpacing
    self.addButton.frame = NSRect(x: 0, y: buttonY, width: max(132, self.addButton.fittingSize.width), height: rowHeight)
    self.removeButton.frame = NSRect(x: self.addButton.frame.maxX + rowSpacing, y: buttonY, width: max(190, self.removeButton.fittingSize.width), height: rowHeight)
  }
}

/// Places the target-display selector without relying on the host preferences layout.
/// 独立放置目标显示器选择器，不依赖宿主偏好设置页面布局。
final class EqualBrightnessDisplaySelectorView: NSView {
  private let label: NSTextField
  private let popup: NSPopUpButton

  init(label: NSTextField, popup: NSPopUpButton) {
    self.label = label
    self.popup = popup
    super.init(frame: .zero)
    self.label.lineBreakMode = .byTruncatingTail
    self.addSubview(label)
    self.addSubview(popup)
  }

  required init?(coder: NSCoder) {
    fatalError("EqualBrightnessDisplaySelectorView does not support storyboard decoding")
  }

  override var isFlipped: Bool {
    true
  }

  override func layout() {
    super.layout()
    let labelWidth = EqualBrightnessAlignedSliderRow.labelColumnWidth
    let popupX = labelWidth + 12
    self.label.frame = NSRect(x: 0, y: 0, width: labelWidth, height: self.bounds.height)
    self.popup.frame = NSRect(x: popupX, y: 0, width: min(260, max(220, self.bounds.width - popupX)), height: 28)
  }
}

/// Places Cancel and Save at the bottom-right of the standalone page.
/// 将“取消”和“保存”固定在独立页面右下角。
final class EqualBrightnessActionBar: NSView {
  private let cancelButton: NSButton
  private let saveButton: NSButton

  init(cancelButton: NSButton, saveButton: NSButton) {
    self.cancelButton = cancelButton
    self.saveButton = saveButton
    super.init(frame: .zero)
    self.addSubview(cancelButton)
    self.addSubview(saveButton)
  }

  required init?(coder: NSCoder) {
    fatalError("EqualBrightnessActionBar does not support storyboard decoding")
  }

  override var isFlipped: Bool {
    true
  }

  override func layout() {
    super.layout()
    let spacing: CGFloat = 12
    let buttonHeight: CGFloat = 32
    let saveWidth = max(88, self.saveButton.fittingSize.width)
    let cancelWidth = max(88, self.cancelButton.fittingSize.width)
    self.saveButton.frame = NSRect(x: self.bounds.width - saveWidth, y: 0, width: saveWidth, height: buttonHeight)
    self.cancelButton.frame = NSRect(x: self.saveButton.frame.minX - spacing - cancelWidth, y: 0, width: cancelWidth, height: buttonHeight)
  }
}

/// Provides a complete standalone page with explicit top-to-bottom frames.
/// 提供使用明确上下位置的完整独立页面。
final class EqualBrightnessSettingsPageView: NSView {
  private let displaySelector: EqualBrightnessDisplaySelectorView
  private let graphView: EqualBrightnessGraphView
  private let controlsView: EqualBrightnessCalibrationControlsView
  private let pointsSummary: NSTextField
  private let actionBar: EqualBrightnessActionBar

  init(displaySelector: EqualBrightnessDisplaySelectorView, graphView: EqualBrightnessGraphView, controlsView: EqualBrightnessCalibrationControlsView, pointsSummary: NSTextField, actionBar: EqualBrightnessActionBar) {
    self.displaySelector = displaySelector
    self.graphView = graphView
    self.controlsView = controlsView
    self.pointsSummary = pointsSummary
    self.actionBar = actionBar
    super.init(frame: NSRect(origin: .zero, size: EqualBrightnessSettingsLayout.contentSize))
    self.autoresizingMask = [.width, .height]
    self.addSubview(displaySelector)
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

  /// Calculates the minimum content height for the discovered display count.
  /// 根据当前发现的显示器数量计算页面所需的最小内容高度。
  var requiredContentHeight: CGFloat {
    let sectionCount = 5
    return EqualBrightnessSettingsLayout.contentInset * 2
      + EqualBrightnessSettingsLayout.headerHeight
      + EqualBrightnessSettingsLayout.graphHeight
      + self.controlsView.contentHeight
      + EqualBrightnessSettingsLayout.summaryHeight
      + EqualBrightnessSettingsLayout.footerHeight
      + CGFloat(sectionCount - 1) * EqualBrightnessSettingsLayout.sectionSpacing
  }

  override func layout() {
    super.layout()
    let inset = EqualBrightnessSettingsLayout.contentInset
    let spacing = EqualBrightnessSettingsLayout.sectionSpacing
    let width = max(0, self.bounds.width - inset * 2)
    var y = inset

    // Keep the graph as the first content block, directly below the window title bar.
    // 将曲线图作为第一个内容区块，直接放在窗口标题栏下方。
    self.graphView.frame = NSRect(x: inset, y: y, width: width, height: EqualBrightnessSettingsLayout.graphHeight)
    y += EqualBrightnessSettingsLayout.graphHeight + spacing

    self.displaySelector.frame = NSRect(x: inset, y: y, width: width, height: EqualBrightnessSettingsLayout.headerHeight)
    y += EqualBrightnessSettingsLayout.headerHeight + spacing

    let controlsHeight = self.controlsView.contentHeight
    self.controlsView.frame = NSRect(x: inset, y: y, width: width, height: controlsHeight)
    y += controlsHeight + spacing

    // Keep the point summary and usage guidance together immediately before the actions.
    // 将参考点摘要和使用提示作为同一个文本区块，放在操作按钮之前。
    let minimumFooterY = y + spacing + EqualBrightnessSettingsLayout.summaryHeight + spacing
    let footerY = max(minimumFooterY, self.bounds.height - inset - EqualBrightnessSettingsLayout.footerHeight)
    let summaryY = footerY - spacing - EqualBrightnessSettingsLayout.summaryHeight
    self.pointsSummary.frame = NSRect(x: inset, y: summaryY, width: width, height: EqualBrightnessSettingsLayout.summaryHeight)
    self.pointsSummary.preferredMaxLayoutWidth = width
    self.actionBar.frame = NSRect(x: inset, y: footerY, width: width, height: EqualBrightnessSettingsLayout.footerHeight)
  }
}
