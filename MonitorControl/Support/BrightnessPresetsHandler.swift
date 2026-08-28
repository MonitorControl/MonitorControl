//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Cocoa
import os.log

// Row of remembered brightness values shown under the brightness slider in the menu.
// The "+" chip stores the current brightness, clicking a chip applies it, the badge on a hovered chip removes it.
class BrightnessPresetsHandler {
  static let maxPresets = 12

  static func presets() -> [Int] {
    (prefs.array(forKey: PrefKey.brightnessPresets.rawValue) as? [Int] ?? []).sorted()
  }

  static func savePresets(_ presets: [Int]) {
    prefs.set(Array(Set(presets)).sorted(), forKey: PrefKey.brightnessPresets.rawValue)
  }

  // Stores the brightness of the display the menu belongs to. Invoked from the "+" icon in the menu footer.
  static func addCurrentBrightnessPreset() {
    guard let display = DisplayManager.shared.getCurrentDisplay() else {
      return
    }
    var presets = self.presets()
    let percent = Int((display.getBrightness() * 100).rounded())
    guard !presets.contains(percent), presets.count < self.maxPresets else {
      return
    }
    presets.append(percent)
    self.savePresets(presets)
    os_log("Brightness preset %{public}@%% stored", type: .info, String(percent))
    self.presetsChanged()
  }

  // Every display block shows the same presets, so all rows are refreshed. A changed number of chip rows
  // needs a menu laid out from scratch, which NSMenu can only do while it is closed.
  static func presetsChanged() {
    var needsMenuRebuild = menu.presetsHandlers.isEmpty
    for presetsHandler in menu.presetsHandlers {
      if presetsHandler.refreshLayout() {
        needsMenuRebuild = true
      }
    }
    guard needsMenuRebuild else {
      return
    }
    menu.closeMenu()
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { app.updateMenusAndKeys() }
  }

  private let chipHeight: CGFloat = 22
  private let chipWidth: CGFloat = 34
  private let chipGap: CGFloat = 5
  private let rowGap: CGFloat = 5
  private let inset: CGFloat = 15
  private let bottomPadding: CGFloat = 7
  private let topPadding: CGFloat = 1

  private let sliderHandler: SliderHandler
  private let width: CGFloat
  private var rowCount = 1

  var view: NSView?

  init(sliderHandler: SliderHandler, width: CGFloat) {
    self.sliderHandler = sliderHandler
    self.width = width
    self.rowCount = self.calculateRowCount()
    let view = NSView(frame: NSRect(x: 0, y: 0, width: width, height: self.viewHeight()))
    self.view = view
    self.layoutChips()
  }

  private func availableWidth() -> CGFloat {
    self.width - self.inset * 2
  }

  // The chips flow from the left and wrap to a new row when they no longer fit, the "+" chip closes the row.
  private func calculateRowCount() -> Int {
    var rows = 1
    var rowWidth: CGFloat = 0
    for chipWidth in Self.presets().map({ _ in self.chipWidth }) {
      if rowWidth > 0, rowWidth + chipWidth > self.availableWidth() {
        rows += 1
        rowWidth = 0
      }
      rowWidth += chipWidth + self.chipGap
    }
    return rows
  }

  private func viewHeight() -> CGFloat {
    CGFloat(self.rowCount) * self.chipHeight + CGFloat(self.rowCount - 1) * self.rowGap + self.bottomPadding + self.topPadding
  }

  private func layoutChips() {
    guard let view = self.view else {
      return
    }
    for subview in view.subviews {
      subview.removeFromSuperview()
    }
    let chips: [PresetChipView] = Self.presets().map { percent in
      let chip = PresetChipView(percent: percent, width: self.chipWidth, height: self.chipHeight)
      chip.isActive = { [weak self] in abs((self?.sliderHandler.slider?.floatValue ?? -1) - Float(percent) / 100) < 0.005 }
      chip.onClick = { [weak self] in self?.apply(percent: percent) }
      chip.onDelete = { [weak self] in self?.remove(percent: percent) }
      return chip
    }
    var x = self.inset
    var y = view.frame.height - self.topPadding - self.chipHeight
    for chip in chips {
      if x > self.inset, x + chip.frame.width > self.width - self.inset {
        x = self.inset
        y -= self.chipHeight + self.rowGap
      }
      chip.setFrameOrigin(NSPoint(x: x, y: y))
      view.addSubview(chip)
      x += chip.frame.width + self.chipGap
    }
  }

  // Relays out the chips in place and reports whether the row itself has to be rebuilt by the menu.
  func refreshLayout() -> Bool {
    let rowCount = self.calculateRowCount()
    guard rowCount == self.rowCount, !Self.presets().isEmpty else {
      self.rowCount = rowCount
      return true
    }
    self.layoutChips()
    return false
  }

  private func markChipsForRedraw() {
    self.view?.subviews.forEach { $0.needsDisplay = true }
  }

  private func apply(percent: Int) {
    guard let slider = self.sliderHandler.slider else {
      return
    }
    let value = Float(percent) / 100
    slider.floatValue = value
    self.sliderHandler.valueChanged(slider: slider)
    for display in self.sliderHandler.displays {
      self.sliderHandler.setValue(value, displayID: display.identifier)
    }
    os_log("Brightness preset %{public}@%% applied", type: .info, String(percent))
    self.markChipsForRedraw()
  }

  private func remove(percent: Int) {
    Self.savePresets(Self.presets().filter { $0 != percent })
    Self.presetsChanged()
  }
}

class PresetChipView: NSView {
  var onClick: (() -> Void)?
  var onDelete: (() -> Void)?
  var isActive: (() -> Bool)?

  private let percent: Int
  private let deleteBadgeSize: CGFloat = 13
  private var isHovered = false
  private var isPressed = false
  private var isDeleteHovered = false

  init(percent: Int, width: CGFloat, height: CGFloat) {
    self.percent = percent
    super.init(frame: NSRect(x: 0, y: 0, width: width, height: height))
    self.toolTip = NSLocalizedString("Click to apply, click the badge to remove", comment: "Shown in menu as tooltip")
  }

  required init?(coder: NSCoder) {
    self.percent = 0
    super.init(coder: coder)
  }

  override func updateTrackingAreas() {
    super.updateTrackingAreas()
    for trackingArea in self.trackingAreas {
      self.removeTrackingArea(trackingArea)
    }
    self.addTrackingArea(NSTrackingArea(rect: self.bounds, options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways], owner: self, userInfo: nil))
  }

  private var deleteBadgeRect: NSRect {
    NSRect(x: self.bounds.maxX - self.deleteBadgeSize + 2, y: self.bounds.maxY - self.deleteBadgeSize + 2, width: self.deleteBadgeSize, height: self.deleteBadgeSize)
  }

  override func mouseEntered(with _: NSEvent) {
    self.isHovered = true
    self.needsDisplay = true
  }

  override func mouseExited(with _: NSEvent) {
    self.isHovered = false
    self.isDeleteHovered = false
    self.needsDisplay = true
  }

  override func mouseMoved(with event: NSEvent) {
    let isDeleteHovered = self.onDelete != nil && self.deleteBadgeRect.contains(self.convert(event.locationInWindow, from: nil))
    if isDeleteHovered != self.isDeleteHovered {
      self.isDeleteHovered = isDeleteHovered
      self.needsDisplay = true
    }
  }

  override func mouseDown(with _: NSEvent) {
    self.isPressed = true
    self.needsDisplay = true
  }

  override func mouseUp(with event: NSEvent) {
    self.isPressed = false
    self.needsDisplay = true
    let point = self.convert(event.locationInWindow, from: nil)
    if self.onDelete != nil, self.deleteBadgeRect.contains(point) {
      self.onDelete?()
    } else if self.bounds.contains(point) {
      self.onClick?()
    }
  }

  // Right click removes as well, in case the badge is hard to hit.
  override func rightMouseUp(with event: NSEvent) {
    if self.onDelete != nil, self.bounds.contains(self.convert(event.locationInWindow, from: nil)) {
      self.onDelete?()
    }
  }

  override func draw(_: NSRect) {
    let isActive = self.isActive?() ?? false
    let radius = self.bounds.height / 2
    let chipPath = NSBezierPath(roundedRect: self.bounds, xRadius: radius, yRadius: radius)
    if isActive {
      NSColor.controlAccentColor.withAlphaComponent(self.isPressed ? 0.75 : 1).setFill()
    } else {
      NSColor.labelColor.withAlphaComponent(self.isPressed ? 0.25 : (self.isHovered ? 0.16 : 0.09)).setFill()
    }
    chipPath.fill()

    let foregroundColor = isActive ? NSColor.white : NSColor.labelColor.withAlphaComponent(0.85)
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.alignment = .center
    let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 11, weight: .medium), .foregroundColor: foregroundColor, .paragraphStyle: paragraphStyle]
    NSAttributedString(string: "\(self.percent)", attributes: attributes).draw(in: NSRect(x: 0, y: (self.bounds.height - 14) / 2 - 1, width: self.bounds.width, height: 14))

    if self.isHovered, self.onDelete != nil {
      let badgeRect = self.deleteBadgeRect
      (self.isDeleteHovered ? NSColor.systemRed : NSColor.secondaryLabelColor).setFill()
      NSBezierPath(ovalIn: badgeRect).fill()
      self.drawSymbol("xmark", color: .white, in: badgeRect.insetBy(dx: 3.5, dy: 3.5), fallback: "×")
    }
  }

  private func drawSymbol(_ name: String, color: NSColor, in rect: NSRect, fallback: String) {
    if !DEBUG_MACOS10, #available(macOS 11.0, *), let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil) {
      let configuredSymbol = symbol.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: rect.height, weight: .bold)) ?? symbol
      configuredSymbol.isTemplate = true
      color.set()
      configuredSymbol.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
      return
    }
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.alignment = .center
    let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: rect.height + 2, weight: .medium), .foregroundColor: color, .paragraphStyle: paragraphStyle]
    NSAttributedString(string: fallback, attributes: attributes).draw(in: NSRect(x: rect.minX - 4, y: rect.minY - 3, width: rect.width + 8, height: rect.height + 6))
  }
}
