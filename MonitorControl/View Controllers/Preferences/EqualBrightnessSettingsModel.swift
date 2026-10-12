//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Foundation

// MARK: - Curve model / 曲线模型

/// A manually calibrated reference pair between the Mac display and one target display.
/// Mac 屏幕与目标显示器之间经过人工校准的一组参考点。
struct EqualBrightnessCalibrationPoint: Codable, Identifiable {
  let id: UUID
  var sourceValue: Double
  var targetValue: Double

  /// Creates a normalized calibration point and clamps both values to the supported range.
  /// 创建归一化参考点，并将两个值限制在支持的范围内。
  init(sourceValue: Double, targetValue: Double) {
    self.id = UUID()
    self.sourceValue = EqualBrightnessCurve.clamp(sourceValue)
    self.targetValue = EqualBrightnessCurve.clamp(targetValue)
  }
}

/// The first release keeps only monotonic curve choices that are safe to preview.
/// 第一版只提供适合预览且不会产生越界的曲线类型。
enum EqualBrightnessCurveKind: String, Codable, CaseIterable {
  case piecewiseLinear
  case monotoneCubic

  /// Returns the localized label shown in the curve selector.
  /// 返回曲线选择器中显示的本地化标题。
  var localizedTitle: String {
    switch self {
    case .piecewiseLinear:
      return NSLocalizedString("Piecewise Linear", comment: "Equal brightness curve type")
    case .monotoneCubic:
      return NSLocalizedString("Smooth Monotone Cubic", comment: "Equal brightness curve type")
    }
  }
}

/// Describes one target display mapping from reference brightness to target brightness.
/// 描述参考亮度到目标亮度映射的一条目标显示器曲线。
struct EqualBrightnessCurve: Codable {
  var kind: EqualBrightnessCurveKind
  var points: [EqualBrightnessCalibrationPoint]

  /// Evaluates the curve at a normalized reference brightness value.
  /// 根据归一化的参考亮度计算曲线输出。
  func value(at sourceValue: Double) -> Double {
    let source = Self.clamp(sourceValue)
    let result: Double
    switch self.kind {
    case .piecewiseLinear:
      result = self.piecewiseLinearValue(at: source)
    case .monotoneCubic:
      result = self.monotoneCubicValue(at: source)
    }
    return Self.clamp(result)
  }

  /// Performs a bounded piecewise-linear interpolation through the calibration points.
  /// 在参考点之间执行有界的分段线性插值。
  private func piecewiseLinearValue(at sourceValue: Double) -> Double {
    let sortedPoints = Self.pointsWithFixedEndpoints(self.points)
    guard let first = sortedPoints.first else {
      return sourceValue
    }
    guard sortedPoints.count > 1 else {
      return first.targetValue
    }
    if sourceValue <= first.sourceValue {
      return first.targetValue
    }
    if let last = sortedPoints.last, sourceValue >= last.sourceValue {
      return last.targetValue
    }
    for pair in zip(sortedPoints, sortedPoints.dropFirst()) {
      let left = pair.0
      let right = pair.1
      guard sourceValue <= right.sourceValue else {
        continue
      }
      let span = max(right.sourceValue - left.sourceValue, Double.ulpOfOne)
      let ratio = (sourceValue - left.sourceValue) / span
      return left.targetValue + (right.targetValue - left.targetValue) * ratio
    }
    return sourceValue
  }

  /// Adds immutable normalized endpoints and removes duplicate source positions.
  /// 添加固定的归一化端点，并移除重复的参考亮度位置。
  static func pointsWithFixedEndpoints(_ points: [EqualBrightnessCalibrationPoint]) -> [EqualBrightnessCalibrationPoint] {
    let tolerance = 0.000_001
    let sortedInterior = points
      .filter { $0.sourceValue > tolerance && $0.sourceValue < 1 - tolerance }
      .sorted { $0.sourceValue < $1.sourceValue }
    var result: [EqualBrightnessCalibrationPoint] = []
    for point in sortedInterior {
      if let last = result.last, abs(last.sourceValue - point.sourceValue) <= tolerance {
        result[result.count - 1].targetValue = Self.clamp(point.targetValue)
      } else {
        var normalized = point
        normalized.sourceValue = Self.clamp(normalized.sourceValue)
        normalized.targetValue = Self.clamp(normalized.targetValue)
        result.append(normalized)
      }
    }
    let lower = points.first(where: { abs($0.sourceValue) <= tolerance }) ?? EqualBrightnessCalibrationPoint(sourceValue: 0, targetValue: 0)
    let upper = points.first(where: { abs($0.sourceValue - 1) <= tolerance }) ?? EqualBrightnessCalibrationPoint(sourceValue: 1, targetValue: 1)
    var fixedLower = lower
    fixedLower.sourceValue = 0
    fixedLower.targetValue = 0
    var fixedUpper = upper
    fixedUpper.sourceValue = 1
    fixedUpper.targetValue = 1
    return [fixedLower] + result + [fixedUpper]
  }

  /// Evaluates a shape-preserving cubic Hermite spline through every point.
  /// 使用保形三次 Hermite 样条穿过每个参考点，同时保持曲线平滑。
  private func monotoneCubicValue(at sourceValue: Double) -> Double {
    let points = Self.pointsWithFixedEndpoints(self.points)
    guard points.count > 1 else {
      return sourceValue
    }
    if sourceValue <= points[0].sourceValue {
      return points[0].targetValue
    }
    if sourceValue >= points[points.count - 1].sourceValue {
      return points[points.count - 1].targetValue
    }
    let slopes = Self.monotoneSlopes(for: points)
    for index in 0 ..< points.count - 1 {
      let left = points[index]
      let right = points[index + 1]
      guard sourceValue <= right.sourceValue else {
        continue
      }
      let span = max(right.sourceValue - left.sourceValue, Double.ulpOfOne)
      let ratio = (sourceValue - left.sourceValue) / span
      let ratioSquared = ratio * ratio
      let ratioCubed = ratioSquared * ratio
      let h00 = 2 * ratioCubed - 3 * ratioSquared + 1
      let h10 = ratioCubed - 2 * ratioSquared + ratio
      let h01 = -2 * ratioCubed + 3 * ratioSquared
      let h11 = ratioCubed - ratioSquared
      return h00 * left.targetValue + h10 * span * slopes[index] + h01 * right.targetValue + h11 * span * slopes[index + 1]
    }
    return sourceValue
  }

  /// Calculates Fritsch-Carlson style slopes for a monotone cubic spline.
  /// 计算单调三次样条使用的 Fritsch-Carlson 风格切线斜率。
  private static func monotoneSlopes(for points: [EqualBrightnessCalibrationPoint]) -> [Double] {
    guard points.count > 2 else {
      let span = max(points[1].sourceValue - points[0].sourceValue, Double.ulpOfOne)
      let slope = (points[1].targetValue - points[0].targetValue) / span
      return [slope, slope]
    }
    var intervals: [Double] = []
    var widths: [Double] = []
    for pair in zip(points, points.dropFirst()) {
      let width = max(pair.1.sourceValue - pair.0.sourceValue, Double.ulpOfOne)
      widths.append(width)
      intervals.append((pair.1.targetValue - pair.0.targetValue) / width)
    }
    var slopes = [Double](repeating: 0, count: points.count)
    for index in 1 ..< points.count - 1 {
      let previous = intervals[index - 1]
      let next = intervals[index]
      if previous * next <= 0 {
        slopes[index] = 0
      } else {
        let weightPrevious = 2 * widths[index] + widths[index - 1]
        let weightNext = widths[index] + 2 * widths[index - 1]
        slopes[index] = (weightPrevious + weightNext) / (weightPrevious / previous + weightNext / next)
      }
    }
    slopes[0] = Self.endpointSlope(width: widths[0], nextWidth: widths[1], interval: intervals[0], nextInterval: intervals[1])
    slopes[slopes.count - 1] = Self.endpointSlope(width: widths[widths.count - 1], nextWidth: widths[widths.count - 2], interval: intervals[intervals.count - 1], nextInterval: intervals[intervals.count - 2])
    return slopes
  }

  /// Limits an endpoint tangent to the neighboring monotone interval.
  /// 将端点切线限制在相邻单调区间范围内。
  private static func endpointSlope(width: Double, nextWidth: Double, interval: Double, nextInterval: Double) -> Double {
    var slope = ((2 * width + nextWidth) * interval - width * nextInterval) / max(width + nextWidth, Double.ulpOfOne)
    if slope * interval <= 0 {
      slope = 0
    } else if interval * nextInterval < 0, abs(slope) > abs(3 * interval) {
      slope = 3 * interval
    }
    return slope
  }

  /// Clamps a curve value to the normalized brightness domain.
  /// 将曲线值限制在归一化亮度区间内。
  static func clamp(_ value: Double) -> Double {
    guard value.isFinite else {
      return 0
    }
    return max(0, min(1, value))
  }
}
