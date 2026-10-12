//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Cocoa

// MARK: - Graph / 曲线图

/// A sampled curve used by the graph view without coupling the graph to display hardware.
/// 图表使用的采样曲线，避免图表直接依赖显示器硬件。
struct EqualBrightnessGraphCurve {
  let title: String
  let color: NSColor
  let evaluator: (Double) -> Double
  let isReference: Bool
}

/// Draws the normalized brightness grid, reference line, target curves, and calibration points.
/// 绘制归一化亮度网格、参考直线、目标曲线和校准点。
final class EqualBrightnessGraphView: NSView {
  var curves: [EqualBrightnessGraphCurve] = [] {
    didSet {
      self.needsDisplay = true
    }
  }

  var points: [EqualBrightnessCalibrationPoint] = [] {
    didSet {
      self.needsDisplay = true
    }
  }

  var selectedPointID: UUID? {
    didSet {
      self.needsDisplay = true
    }
  }

  /// Uses the selected target display color for its calibration markers.
  /// 使用当前选中目标显示器的颜色绘制校准点。
  var pointColor: NSColor = .systemOrange {
    didSet {
      self.needsDisplay = true
    }
  }

  var onPointSelected: ((UUID?) -> Void)?

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
    let candidates: [(point: EqualBrightnessCalibrationPoint, distance: CGFloat)] = self.points.map { point in
      let pointX = self.graphPoint(source: point.sourceValue, target: point.targetValue, in: rect).x
      return (point: point, distance: abs(pointX - location.x))
    }
    let nearest = candidates
      .filter { candidate in candidate.distance <= 12 }
      .min { left, right in left.distance < right.distance }
    self.selectedPointID = nearest?.0.id
    self.onPointSelected?(self.selectedPointID)
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
    for point in self.points {
      let x = self.graphPoint(source: point.sourceValue, target: point.targetValue, in: rect).x
      let guide = NSBezierPath()
      guide.lineWidth = point.id == self.selectedPointID ? 1.5 : 1
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
  private func drawPoint(_ point: EqualBrightnessCalibrationPoint, in rect: NSRect) {
    let center = self.graphPoint(source: point.sourceValue, target: point.targetValue, in: rect)
    if point.id == self.selectedPointID {
      let selection = NSBezierPath(ovalIn: NSRect(x: center.x - 8, y: center.y - 8, width: 16, height: 16))
      NSColor.controlAccentColor.setStroke()
      selection.lineWidth = 2
      selection.stroke()
    }
    let marker = NSBezierPath(ovalIn: NSRect(x: center.x - 4, y: center.y - 4, width: 8, height: 8))
    self.pointColor.setFill()
    marker.fill()
    NSColor.labelColor.setStroke()
    marker.lineWidth = 1
    marker.stroke()
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
