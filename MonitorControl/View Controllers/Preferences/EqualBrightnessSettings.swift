//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Cocoa

/// Equal-brightness data, persistence, display helpers, and runtime synchronization.
/// 等亮度数据模型、持久化、显示器辅助方法和运行时同步。

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

// MARK: - Persistence / 配置持久化

/// Identifies a display with stable hardware values and keeps legacy aliases for migration.
/// 使用稳定硬件字段标识显示器，并保留旧键以便迁移已有配置。
struct EqualBrightnessDisplayIdentity: Codable, Hashable {
  let key: String
  let displayName: String
  private let legacyKeys: [String]
  private let legacyDisplayIDPrefixes: [String]

  /// Returns the current key followed by keys written by older builds.
  /// 返回当前键以及旧版本写入的兼容键。
  var lookupKeys: [String] {
    var keys = [self.key]
    for legacyKey in self.legacyKeys where !keys.contains(legacyKey) {
      keys.append(legacyKey)
    }
    return keys
  }

  /// Checks whether a stored key belongs to this display's old ID-based namespace.
  /// 检查持久化键是否属于当前显示器旧版的 ID 命名空间。
  func matchesLegacyDisplayIDKey(_ storedKey: String) -> Bool {
    self.legacyDisplayIDPrefixes.contains { storedKey.hasPrefix($0) }
  }

  /// Builds a stable identity from the current display metadata.
  /// 根据当前显示器元数据构造稳定身份。
  init(display: Display) {
    self.displayName = display.name
    let localizedName = Self.normalized(display.name)
    let hardwareName = Self.normalized(DisplayManager.getDisplayRawNameByID(displayID: display.identifier))
    let stableName = hardwareName.isEmpty ? localizedName : hardwareName
    let vendor = display.vendorNumber ?? 0
    let model = display.modelNumber ?? 0
    let serial = display.serialNumber ?? 0
    let unit = CGDisplayUnitNumber(display.identifier)
    let isBuiltin = CGDisplayIsBuiltin(display.identifier) != 0

    if isBuiltin {
      // Built-in displays are unique on a Mac, so vendor/model are sufficient when no serial exists.
      // 内置屏幕在一台 Mac 上唯一；没有序列号时使用厂商/型号即可。
      self.key = serial == 0 ? "builtin-\(vendor)-\(model)" : "builtin-\(vendor)-\(model)-serial-\(serial)"
    } else if serial != 0 {
      // Serial numbers keep identical external displays separate after reconnects.
      // 序列号可让同型号外接显示器在重连后仍保持独立配置。
      self.key = "external-\(vendor)-\(model)-serial-\(serial)"
    } else if !stableName.isEmpty, unit != 0 {
      // Unit number represents the physical display connection and survives display-ID reassignment.
      // 显示单元号代表物理连接，显示器 ID 重新分配后通常仍保持不变。
      self.key = "external-\(vendor)-\(model)-name-\(stableName)-unit-\(unit)"
    } else if !stableName.isEmpty {
      // Keep a metadata-only fallback when the system does not expose a unit number.
      // 系统不提供显示单元号时，至少使用显示器元数据作为稳定回退。
      self.key = "external-\(vendor)-\(model)-name-\(stableName)"
    } else {
      // A display ID is the last resort when no identifying metadata is available at all.
      // 完全没有可识别元数据时，最后才回退到当前显示器 ID。
      self.key = "external-display-\(display.identifier)"
    }

    // Keep both the original serial/zero format and the display-ID fallback used by recent builds.
    // 同时兼容最初的序列号/0 格式，以及近期版本使用的显示器 ID 回退格式。
    var aliases: [String] = []
    var displayIDPrefixes: [String] = []
    if isBuiltin {
      aliases.append("builtin-\(localizedName)-\(vendor)-\(model)")
      if hardwareName != localizedName, !hardwareName.isEmpty {
        aliases.append("builtin-\(hardwareName)-\(vendor)-\(model)")
      }
    } else {
      aliases.append("external-\(localizedName)-\(vendor)-\(model)-\(serial)")
      aliases.append("external-\(localizedName)-\(vendor)-\(model)-display-\(display.identifier)")
      displayIDPrefixes.append("external-\(localizedName)-\(vendor)-\(model)-display-")
      if hardwareName != localizedName, !hardwareName.isEmpty {
        aliases.append("external-\(hardwareName)-\(vendor)-\(model)-\(serial)")
        aliases.append("external-\(hardwareName)-\(vendor)-\(model)-display-\(display.identifier)")
        displayIDPrefixes.append("external-\(hardwareName)-\(vendor)-\(model)-display-")
      }
    }
    self.legacyKeys = aliases
    self.legacyDisplayIDPrefixes = displayIDPrefixes
  }

  /// Normalizes names without tying persistence to localization or whitespace.
  /// 规范化名称，避免持久化结果依赖语言设置或空白字符。
  private static func normalized(_ value: String) -> String {
    value.filter { !$0.isWhitespace }.lowercased()
  }
}

/// Stores every saved curve and the reference display for one app installation.
/// 保存当前应用的一组曲线以及参考显示器身份。
struct EqualBrightnessSettingsProfile: Codable {
  static let currentSchemaVersion = 1

  var schemaVersion: Int = EqualBrightnessSettingsProfile.currentSchemaVersion
  var isEnabled: Bool = false
  var referenceDisplayKey: String?
  var curves: [String: EqualBrightnessCurve] = [:]
}

/// Persists equal-brightness curves separately from the legacy brightness preferences.
/// 将等亮度曲线与原有亮度偏好分开持久化。
final class EqualBrightnessSettingsStore {
  static let shared = EqualBrightnessSettingsStore()

  private let userDefaultsKey = "equalBrightnessSettings.profile.v1"
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder

  /// Creates a versioned JSON encoder and decoder for UserDefaults data.
  /// 创建用于 UserDefaults 数据的版本化 JSON 编解码器。
  private init() {
    self.encoder = JSONEncoder()
    self.decoder = JSONDecoder()
  }

  /// Loads a valid profile or returns nil when no profile has been saved.
  /// 读取有效配置；尚未保存配置时返回 nil。
  func load() -> EqualBrightnessSettingsProfile? {
    guard let data = UserDefaults.standard.data(forKey: self.userDefaultsKey) else {
      return nil
    }
    guard let profile = try? self.decoder.decode(EqualBrightnessSettingsProfile.self, from: data), profile.schemaVersion == EqualBrightnessSettingsProfile.currentSchemaVersion else {
      return nil
    }
    return profile
  }

  /// Saves a complete profile atomically after encoding it in memory.
  /// 先在内存中编码完整配置，再原子写入保存。
  @discardableResult
  func save(_ profile: EqualBrightnessSettingsProfile) -> Bool {
    guard let data = try? self.encoder.encode(profile) else {
      return false
    }
    UserDefaults.standard.set(data, forKey: self.userDefaultsKey)
    return true
  }

  /// Saves one target curve and enables mapped synchronization for future changes.
  /// 保存一台目标显示器的曲线，并为后续亮度变化启用映射同步。
  @discardableResult
  func saveCurve(_ curve: EqualBrightnessCurve, for targetDisplay: Display, referenceDisplay: Display) -> Bool {
    var profile = self.load() ?? EqualBrightnessSettingsProfile()
    let targetIdentity = EqualBrightnessDisplayIdentity(display: targetDisplay)
    let referenceIdentity = EqualBrightnessDisplayIdentity(display: referenceDisplay)
    profile.isEnabled = true
    profile.referenceDisplayKey = referenceIdentity.key
    profile.curves[targetIdentity.key] = curve
    return self.save(profile)
  }

  /// Returns the saved curve for a target display, if one exists.
  /// 返回目标显示器已保存的曲线；不存在时返回 nil。
  func curve(for display: Display) -> EqualBrightnessCurve? {
    guard let profile = self.load() else {
      return nil
    }
    let identity = EqualBrightnessDisplayIdentity(display: display)
    for key in identity.lookupKeys {
      if let curve = profile.curves[key] {
        return curve
      }
    }

    // Recover one pre-migration display-ID record after reconnecting; refuse ambiguous matches.
    // 重连后尝试恢复一条旧显示器 ID 记录；存在歧义时拒绝匹配，避免串用曲线。
    let legacyMatches = profile.curves.filter { key, _ in
      identity.matchesLegacyDisplayIDKey(key)
    }
    if legacyMatches.count == 1 {
      return legacyMatches.first?.value
    }
    return nil
  }

  /// Indicates whether a saved mapping should participate in runtime synchronization.
  /// 判断已保存的映射是否应参与运行时同步。
  func isEnabled() -> Bool {
    self.load()?.isEnabled ?? false
  }

  /// Checks whether a display is the configured reference display.
  /// 检查某台显示器是否为配置中的参考显示器。
  func isReferenceDisplay(_ display: Display) -> Bool {
    guard let configuredKey = self.load()?.referenceDisplayKey else {
      return false
    }
    let identity = EqualBrightnessDisplayIdentity(display: display)
    if identity.lookupKeys.contains(configuredKey) {
      return true
    }
    // Also recognize the old display-ID key so legacy profiles keep their reference display after reconnecting.
    // 同时识别旧版显示器 ID 键，确保旧配置在重连后仍能找到参考显示器。
    return identity.matchesLegacyDisplayIDKey(configuredKey)
  }

  /// Deletes all equal-brightness data and restores the disabled default.
  /// 删除全部等亮度数据并恢复为关闭状态。
  func reset() {
    UserDefaults.standard.removeObject(forKey: self.userDefaultsKey)
  }
}

// MARK: - Display support / 显示器辅助

/// Provides display selection and naming helpers for the equal-brightness editor.
/// 为等亮度编辑器提供显示器选择和命名辅助函数。
enum EqualBrightnessDisplaySupport {
  /// Returns a stable user-facing name with a localized fallback.
  /// 返回稳定的用户可见名称，并提供本地化兜底名称。
  static func userFacingName(for display: Display, fallbackIndex: Int = 0) -> String {
    let friendlyName = display.readPrefAsString(key: .friendlyName).trimmingCharacters(in: .whitespacesAndNewlines)
    if !friendlyName.isEmpty {
      return friendlyName
    }
    let displayName = display.name.trimmingCharacters(in: .whitespacesAndNewlines)
    if !displayName.isEmpty {
      return displayName
    }
    if CGDisplayIsBuiltin(display.identifier) != 0 {
      return NSLocalizedString("Built-in Display", comment: "Fallback built-in display name")
    }
    let externalName = NSLocalizedString("External Display", comment: "Fallback external display name")
    return "\(externalName) \(fallbackIndex + 1)"
  }

  /// Chooses the built-in or first Apple display as the reference display.
  /// 选择内置显示器或第一台 Apple 显示器作为参考显示器。
  static func referenceDisplay(from displays: [Display]) -> Display? {
    DisplayManager.shared.getBuiltInDisplay()
      ?? DisplayManager.shared.getAppleDisplays().first
      ?? displays.first
  }

  /// Removes the reference display from the list of target displays.
  /// 从目标显示器列表中移除参考显示器。
  static func targetDisplays(from displays: [Display], reference: Display?) -> [Display] {
    displays.filter { display in
      guard let reference else {
        return true
      }
      return display != reference
    }
  }
}

// MARK: - Runtime synchronization / 运行时同步

/// Selects the equal-brightness mapping path while preserving legacy synchronization fallback.
/// 在保留旧同步回退路径的前提下选择等亮度映射路径。
final class EqualBrightnessSyncCoordinator {
  static let shared = EqualBrightnessSyncCoordinator()

  private(set) var isCalibrationActive = false

  /// Creates the process-wide coordinator used by the existing brightness job.
  /// 创建供现有亮度任务使用的进程级协调器。
  private init() {}

  /// Temporarily pauses cross-display synchronization while calibration is edited.
  /// 编辑校准曲线期间临时暂停显示器之间的亮度同步。
  func beginCalibrationSession() {
    self.isCalibrationActive = true
  }

  /// Resumes cross-display synchronization after the calibration window closes.
  /// 等亮度窗口关闭后恢复显示器之间的亮度同步。
  func endCalibrationSession() {
    self.isCalibrationActive = false
  }

  /// Allows only the configured reference display to start mapped synchronization.
  /// 只允许配置的参考显示器启动映射同步。
  func shouldPropagate(sourceDisplay: Display) -> Bool {
    guard !self.isCalibrationActive else {
      return false
    }
    let store = EqualBrightnessSettingsStore.shared
    return !store.isEnabled() || store.isReferenceDisplay(sourceDisplay)
  }

  /// Computes a target value from a curve or falls back to the legacy delta rule.
  /// 使用曲线计算目标值；不满足映射条件时回退到原有增量规则。
  func targetValue(for targetDisplay: Display, sourceDisplay: Display, delta: Float) -> Float {
    let store = EqualBrightnessSettingsStore.shared
    guard store.isEnabled(), store.isReferenceDisplay(sourceDisplay), targetDisplay != sourceDisplay else {
      return Self.clamp(targetDisplay.getBrightness() + delta)
    }
    let curve = store.curve(for: targetDisplay) ?? EqualBrightnessCurve(kind: .piecewiseLinear, points: [])
    let mappedValue = curve.value(at: Double(sourceDisplay.getBrightness()))
    return Float(EqualBrightnessCurve.clamp(mappedValue))
  }

  /// Keeps runtime brightness values inside the same normalized range as Display.
  /// 将运行时亮度值限制在 Display 使用的归一化范围内。
  private static func clamp(_ value: Float) -> Float {
    guard value.isFinite else {
      return 0
    }
    return max(0, min(1, value))
  }
}
