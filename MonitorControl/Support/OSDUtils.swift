//  Copyright © MonitorControl. @victorchabbert, @JoniVR, @theOneyouseek, @waydabber and others

import Cocoa

class OSDUtils: NSObject {
  enum OSDImage: Int64 {
    case brightness = 1
    case audioSpeaker = 3
    case audioSpeakerMuted = 4
    case contrast = 11
  }

  static func getOSDImageByCommand(command: Command, value: Float = 1) -> OSDImage {
    var osdImage: OSDImage
    switch command {
    case .audioSpeakerVolume:
      osdImage = value > 0 ? .audioSpeaker : .audioSpeakerMuted
    case .audioMuteScreenBlank:
      osdImage = .audioSpeakerMuted
    case .contrast:
      osdImage = .contrast
    default:
      osdImage = .brightness
    }
    return osdImage
  }

  static func showOsd(displayID: CGDirectDisplayID, command: Command, value: Float, maxValue: Float = 1, roundChiclet: Bool = false, lock: Bool = false) {
    let safeMax = max(maxValue, 0.0001)
    let normalized: Float
    if roundChiclet {
      let chiclet = self.chiclet(fromValue: value, maxValue: safeMax).rounded()
      normalized = max(0, min(1, chiclet / self.chicletCount))
    } else {
      normalized = max(0, min(1, value / safeMax))
    }

    guard !DEBUG_MACOS10, #available(macOS 26.0, *) else {
      self.withLegacyOSD { manager in
        let osdImage = self.getOSDImageByCommand(command: command, value: value)
        let filledChiclets: Int
        let totalChiclets: Int
        if roundChiclet {
          let chiclet = self.chiclet(fromValue: value, maxValue: safeMax)
          filledChiclets = Int(chiclet.rounded())
          totalChiclets = Int(self.chicletCount)
        } else {
          filledChiclets = Int(value * 100)
          totalChiclets = Int(safeMax * 100)
        }
        manager.showImage(
          osdImage.rawValue,
          onDisplayID: displayID,
          priority: 0x1F4,
          msecUntilFade: 1000,
          filledChiclets: UInt32(filledChiclets),
          totalChiclets: UInt32(totalChiclets),
          locked: lock
        )
      }
      return
    }

    MacOS27OSDHudController.shared.show(displayID: displayID, command: command, normalizedValue: normalized, locked: lock)
  }

  static func showOsdVolumeDisabled(displayID: CGDirectDisplayID) {
    guard !DEBUG_MACOS10, #available(macOS 26.0, *) else {
      self.withLegacyOSD { manager in
        manager.showImage(22, onDisplayID: displayID, priority: 0x1F4, msecUntilFade: 1000)
      }
      return
    }
    MacOS27OSDHudController.shared.show(displayID: displayID, command: .audioSpeakerVolume, normalizedValue: 0, locked: true)
  }

  static func showOsdMuteDisabled(displayID: CGDirectDisplayID) {
    guard !DEBUG_MACOS10, #available(macOS 26.0, *) else {
      self.withLegacyOSD { manager in
        manager.showImage(21, onDisplayID: displayID, priority: 0x1F4, msecUntilFade: 1000)
      }
      return
    }
    MacOS27OSDHudController.shared.show(displayID: displayID, command: .audioMuteScreenBlank, normalizedValue: 0, locked: true)
  }

  static func popEmptyOsd(displayID: CGDirectDisplayID, command: Command) {
    guard !DEBUG_MACOS10, #available(macOS 26.0, *) else {
      self.withLegacyOSD { manager in
        let osdImage = self.getOSDImageByCommand(command: command)
        manager.showImage(osdImage.rawValue, onDisplayID: displayID, priority: 0x1F4, msecUntilFade: 0)
      }
      return
    }
  }

  private static func withLegacyOSD(_ show: @escaping (OSDUIHelperProtocol) -> Void) {
    if let manager = OSDManager.sharedManager() as? OSDManager {
      show(manager)
    }
  }

  static let chicletCount: Float = 16

  static func chiclet(fromValue value: Float, maxValue: Float, half: Bool = false) -> Float {
    (value * self.chicletCount * (half ? 2 : 1)) / maxValue
  }

  static func value(fromChiclet chiclet: Float, maxValue: Float, half: Bool = false) -> Float {
    (chiclet * maxValue) / (self.chicletCount * (half ? 2 : 1))
  }

  static func getDistance(fromNearestChiclet chiclet: Float) -> Float {
    abs(chiclet.rounded(.towardZero) - chiclet)
  }
}

@available(macOS 26.0, *)
final class MacOS27OSDHudController {
  static let shared = MacOS27OSDHudController()

  private var panels: [CGDirectDisplayID: OSDHudPanel] = [:]
  private var hideWorkItems: [CGDirectDisplayID: DispatchWorkItem] = [:]

  func show(displayID: CGDirectDisplayID, command: Command, normalizedValue: Float, locked: Bool = false) {
    guard Thread.isMainThread else {
      DispatchQueue.main.async {
        self.show(displayID: displayID, command: command, normalizedValue: normalizedValue, locked: locked)
      }
      return
    }
    let effectiveDisplayID = DisplayManager.resolveEffectiveDisplayID(displayID)
    guard let targetScreen = self.resolveScreen(for: effectiveDisplayID) else { return }
    let display = self.resolveDisplay(displayID: displayID, effectiveDisplayID: effectiveDisplayID)
    let displayName = self.resolveDisplayName(display: display, effectiveDisplayID: effectiveDisplayID)
    let badgeText = self.resolveBadgeText(display: display, command: command, normalizedValue: normalizedValue, locked: locked)
    let panel = self.panel(for: effectiveDisplayID)

    panel.hudView.update(
      title: displayName,
      badgeText: badgeText,
      command: command,
      value: normalizedValue,
      locked: locked
    )
    panel.position(on: targetScreen)
    self.presentPanel(panel)
    self.scheduleHide(for: effectiveDisplayID, panel: panel)
  }

  private func resolveDisplay(displayID: CGDirectDisplayID, effectiveDisplayID: CGDirectDisplayID) -> Display? {
    DisplayManager.shared.displays.first { $0.identifier == displayID }
      ?? DisplayManager.shared.displays.first { DisplayManager.resolveEffectiveDisplayID($0.identifier) == effectiveDisplayID }
  }

  private func resolveScreen(for effectiveDisplayID: CGDirectDisplayID) -> NSScreen? {
    DisplayManager.getByDisplayID(displayID: effectiveDisplayID) ?? NSScreen.main ?? NSScreen.screens.first
  }

  private func resolveDisplayName(display: Display?, effectiveDisplayID: CGDirectDisplayID) -> String {
    if let display = display {
      return display.getFriendlyName()
    }
    if CGDisplayIsBuiltin(effectiveDisplayID) != 0 {
      return NSLocalizedString("Built-in Display", comment: "Built-in display name")
    }
    return DisplayManager.getDisplayNameByID(displayID: effectiveDisplayID)
  }

  private func resolveBadgeText(display: Display?, command: Command, normalizedValue: Float, locked: Bool) -> String {
    if locked {
      return NSLocalizedString("Locked", comment: "Shown in OSD pill badge when control is disabled")
    }
    if command == .audioMuteScreenBlank || (command == .audioSpeakerVolume && normalizedValue <= 0.001) {
      return "0%"
    }
    let pct = Int((normalizedValue * 100).rounded())
    if command == .brightness, let nits = display?.getNits(forValue: normalizedValue) {
      return "\(pct)% • \(nits) nits"
    }
    return "\(pct)%"
  }

  private func panel(for effectiveDisplayID: CGDirectDisplayID) -> OSDHudPanel {
    if let existingPanel = self.panels[effectiveDisplayID] {
      return existingPanel
    }
    let panel = OSDHudPanel()
    self.panels[effectiveDisplayID] = panel
    return panel
  }

  private func presentPanel(_ panel: OSDHudPanel) {
    let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    if !panel.isVisible || panel.alphaValue < 0.99 {
      if !panel.isVisible {
        panel.alphaValue = reduceMotion ? 1.0 : 0.0
        panel.orderFrontRegardless()
      }
      if reduceMotion {
        panel.alphaValue = 1.0
      } else {
        NSAnimationContext.runAnimationGroup { context in
          context.duration = 0.14
          context.timingFunction = CAMediaTimingFunction(name: .easeOut)
          panel.animator().alphaValue = 1.0
        }
      }
    } else {
      panel.orderFrontRegardless()
    }
  }

  private func scheduleHide(for effectiveDisplayID: CGDirectDisplayID, panel: OSDHudPanel) {
    self.hideWorkItems[effectiveDisplayID]?.cancel()
    let workItem = DispatchWorkItem { [weak self, weak panel] in
      guard let panel = panel else { return }
      let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
      if reduceMotion {
        panel.alphaValue = 0.0
        panel.orderOut(nil)
      } else {
        NSAnimationContext.runAnimationGroup { context in
          context.duration = 0.25
          context.timingFunction = CAMediaTimingFunction(name: .easeIn)
          panel.animator().alphaValue = 0.0
        } completionHandler: {
          if panel.alphaValue == 0.0 {
            panel.orderOut(nil)
          }
        }
      }
      self?.hideWorkItems[effectiveDisplayID] = nil
    }
    self.hideWorkItems[effectiveDisplayID] = workItem
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.25, execute: workItem)
  }
}

@available(macOS 26.0, *)
final class OSDHudPanel: NSPanel {
  static let hudWidth: CGFloat = 306
  static let hudHeight: CGFloat = 64

  let hudView = MacOS27OSDHudView(frame: NSRect(x: 0, y: 0, width: OSDHudPanel.hudWidth, height: OSDHudPanel.hudHeight))

  override var canBecomeKey: Bool {
    true
  }

  @objc func hasKeyAppearance() -> Bool {
    true
  }

  @objc func _hasActiveAppearance() -> Bool {
    true
  }

  @objc func _hasActiveControls() -> Bool {
    true
  }

  init() {
    let rect = NSRect(x: 0, y: 0, width: Self.hudWidth, height: Self.hudHeight)
    super.init(
      contentRect: rect,
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    self.isFloatingPanel = true
    self.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)) + 1)
    self.backgroundColor = .clear
    self.isOpaque = false
    self.hasShadow = false
    self.isMovable = false
    self.ignoresMouseEvents = true
    self.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
    self.contentView = self.hudView
  }

  func position(on screen: NSScreen) {
    let screenFrame = screen.frame
    let visibleFrame = screen.visibleFrame
    let panelSize = self.frame.size
    let originX = screenFrame.midX - (panelSize.width / 2.0)
    let menuBarInset = max(screenFrame.maxY - visibleFrame.maxY, 26.0)
    let topMargin: CGFloat = 14.0
    let originY = screenFrame.maxY - menuBarInset - topMargin - panelSize.height
    self.setFrameOrigin(NSPoint(x: round(originX), y: round(originY)))
  }
}

@available(macOS 26.0, *)
private final class OSDHudLumaMonitor: NSObject, CALayerDelegate {
  var onLumaChange: ((Double) -> Void)?

  @objc(backdropLayer:didChangeLuma:)
  func backdropLayer(_: CALayer, didChangeLuma luma: Double) {
    if Thread.isMainThread {
      self.onLumaChange?(luma)
    } else {
      DispatchQueue.main.async { [weak self] in
        self?.onLumaChange?(luma)
      }
    }
  }
}

@available(macOS 26.0, *)
final class MacOS27OSDHudView: NSView {
  private static let adaptiveBannerVariant = 9
  private static let hudCornerRadius: CGFloat = 32.0
  private static let darkLumaThreshold: Double = 0.78
  private static let lightLumaThreshold: Double = 0.85
  private static let iconSize: CGFloat = 24.0
  private static let iconX: CGFloat = 24.0
  private static let trackX: CGFloat = 62.0
  private static let trackTrailingInset: CGFloat = 30.0
  private static let trackHeight: CGFloat = 18.0
  private static let trackCenterY: CGFloat = 29.0
  private static let calloutBottomY: CGFloat = 34.0

  private let glassView = NSGlassEffectView(frame: .zero)
  private let containerView = NSView()
  private let calloutView = MacOS27CalloutView()
  private let iconView = NSImageView()
  private let trackBarView = MacOS27TrackBarView()
  private let lumaMonitor = OSDHudLumaMonitor()
  private var lumaBackdropLayer: CALayer?
  private var isDarkBackdropOverride: Bool?
  private var progress: CGFloat = 0

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    self.setupViews()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    self.setupViews()
  }

  private func setupViews() {
    self.wantsLayer = true

    self.setupLumaBackdropLayer()

    self.glassView.frame = self.bounds
    self.glassView.autoresizingMask = [.width, .height]
    self.glassView.style = .regular
    if self.glassView.responds(to: NSSelectorFromString("set_variant:")) {
      self.glassView.setValue(Self.adaptiveBannerVariant, forKey: "_variant")
    }
    // Set after _variant: the variant resets the corner radius to its own default, which clips the rim highlight.
    self.glassView.cornerRadius = Self.hudCornerRadius
    self.addSubview(self.glassView)
    self.containerView.frame = self.glassView.bounds
    self.containerView.autoresizingMask = [.width, .height]
    self.glassView.contentView = self.containerView
    let rootContent = self.containerView

    self.iconView.imageScaling = .scaleProportionallyDown

    self.trackBarView.setAccessibilityElement(true)
    self.trackBarView.setAccessibilityRole(.levelIndicator)

    rootContent.addSubview(self.iconView)
    rootContent.addSubview(self.trackBarView)
    rootContent.addSubview(self.calloutView)

    self.applyAppearanceColors()
  }

  /// Inset well inside the capsule so the backdrop layer's aliased clip edge never shows at the HUD outline.
  private var lumaSampleFrame: NSRect {
    self.bounds.insetBy(dx: Self.hudCornerRadius * 0.6, dy: 8.0)
  }

  private func setupLumaBackdropLayer() {
    guard let backdropClass = NSClassFromString("CABackdropLayer") as? CALayer.Type else { return }
    let layer = backdropClass.init()
    layer.frame = self.lumaSampleFrame
    layer.cornerRadius = self.lumaSampleFrame.height / 2.0
    layer.masksToBounds = true
    layer.allowsEdgeAntialiasing = true
    layer.setValue(true, forKey: "windowServerAware")
    layer.setValue(true, forKey: "tracksLuma")
    layer.setValue(0.25, forKey: "scale")
    layer.setValue(0.05, forKey: "lumaUpdateRate")
    layer.setValue("monitorcontrol-osd-luma", forKey: "groupName")
    self.lumaMonitor.onLumaChange = { [weak self] luma in
      self?.handleBackdropLumaChange(luma)
    }
    layer.delegate = self.lumaMonitor
    self.layer?.insertSublayer(layer, at: 0)
    self.lumaBackdropLayer = layer
  }

  private func handleBackdropLumaChange(_ luma: Double) {
    let newIsDark: Bool
    if let current = self.isDarkBackdropOverride {
      if current, luma > Self.lightLumaThreshold {
        newIsDark = false
      } else if !current, luma < Self.darkLumaThreshold {
        newIsDark = true
      } else {
        newIsDark = current
      }
    } else {
      newIsDark = luma < 0.8
    }

    guard self.isDarkBackdropOverride != newIsDark else { return }
    self.isDarkBackdropOverride = newIsDark
    let targetAppearance = NSAppearance(named: newIsDark ? .darkAqua : .aqua)
    self.glassView.appearance = targetAppearance
    self.applyAppearanceColors()
  }

  override func viewDidChangeEffectiveAppearance() {
    super.viewDidChangeEffectiveAppearance()
    self.applyAppearanceColors()
  }

  private var resolvedIsDark: Bool {
    if let isDarkBackdropOverride = self.isDarkBackdropOverride {
      return isDarkBackdropOverride
    }
    return self.glassView.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
  }

  private func applyAppearanceColors() {
    let isDark = self.resolvedIsDark
    let fgColor = isDark ? NSColor(calibratedWhite: 1.0, alpha: 0.96) : NSColor(calibratedWhite: 0.06, alpha: 0.92)

    self.iconView.contentTintColor = fgColor
    self.calloutView.isDarkAppearance = isDark
    self.trackBarView.isDarkAppearance = isDark
  }

  override func layout() {
    super.layout()
    let bounds = self.bounds
    self.lumaBackdropLayer?.frame = self.lumaSampleFrame
    self.lumaBackdropLayer?.cornerRadius = self.lumaSampleFrame.height / 2.0

    let iconSize = Self.iconSize
    self.iconView.frame = NSRect(x: Self.iconX, y: round(Self.trackCenterY + 1.0 - iconSize / 2.0), width: iconSize, height: iconSize)

    let trackWidth = bounds.width - Self.trackX - Self.trackTrailingInset
    self.trackBarView.frame = NSRect(x: Self.trackX, y: Self.trackCenterY - Self.trackHeight / 2.0, width: trackWidth, height: Self.trackHeight)

    let calloutSize = self.calloutView.fittingSizeForContent
    let fillEndX = self.trackBarView.frame.minX + trackWidth * self.progress
    let minX = 8.0
    let maxX = bounds.width - 8.0 - calloutSize.width
    let calloutX = max(minX, min(maxX, round(fillEndX - calloutSize.width / 2.0)))
    self.calloutView.frame = NSRect(x: calloutX, y: Self.calloutBottomY, width: calloutSize.width, height: calloutSize.height)
    self.calloutView.caretCenterX = fillEndX - calloutX
  }

  func update(title: String, badgeText: String, command: Command, value: Float, locked: Bool) {
    self.progress = CGFloat(max(0, min(1, value)))
    self.calloutView.text = badgeText
    let iconConfig = NSImage.SymbolConfiguration(pointSize: 20.0, weight: .regular)
    self.iconView.image = NSImage(systemSymbolName: self.resolveSymbol(for: command, value: value), accessibilityDescription: nil)?.withSymbolConfiguration(iconConfig)
    self.trackBarView.progress = self.progress
    self.trackBarView.isLocked = locked
    self.trackBarView.setAccessibilityLabel(title)
    self.trackBarView.setAccessibilityValue(badgeText)
    self.applyAppearanceColors()
    self.needsLayout = true
    self.layoutSubtreeIfNeeded()
  }

  private func resolveSymbol(for command: Command, value: Float) -> String {
    switch command {
    case .audioSpeakerVolume, .audioMuteScreenBlank:
      return (command == .audioMuteScreenBlank || value <= 0.001) ? "speaker.slash" : "speaker.wave.3"
    case .contrast:
      return "circle.lefthalf.filled"
    default:
      return "sun.max"
    }
  }
}

@available(macOS 26.0, *)
final class MacOS27CalloutView: NSView {
  private static let bodyHeight: CGFloat = 16.0
  private static let caretHeight: CGFloat = 4.5
  private static let caretWidth: CGFloat = 9.0
  private static let padX: CGFloat = 9.0

  private let label = NSTextField(labelWithString: "")

  var text: String = "" {
    didSet {
      self.label.stringValue = self.text
      self.needsDisplay = true
    }
  }

  var caretCenterX: CGFloat = 0 {
    didSet {
      if oldValue != self.caretCenterX {
        self.needsDisplay = true
      }
    }
  }

  var isDarkAppearance: Bool = true {
    didSet {
      self.label.textColor = self.isDarkAppearance ? NSColor(calibratedWhite: 0.12, alpha: 0.96) : NSColor(calibratedWhite: 0.98, alpha: 0.96)
      self.needsDisplay = true
    }
  }

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    self.label.font = NSFont.monospacedDigitSystemFont(ofSize: 10.5, weight: .semibold)
    self.label.alignment = .center
    self.label.maximumNumberOfLines = 1
    self.label.textColor = NSColor(calibratedWhite: 0.12, alpha: 0.96)
    self.addSubview(self.label)
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  var fittingSizeForContent: NSSize {
    let textSize = self.label.fittingSize
    return NSSize(width: ceil(textSize.width) + Self.padX * 2, height: Self.bodyHeight + Self.caretHeight)
  }

  override func layout() {
    super.layout()
    let textSize = self.label.fittingSize
    self.label.frame = NSRect(
      x: Self.padX,
      y: Self.caretHeight + round((Self.bodyHeight - ceil(textSize.height)) / 2.0),
      width: ceil(textSize.width),
      height: ceil(textSize.height)
    )
  }

  override func draw(_: NSRect) {
    let bodyRect = NSRect(x: 0, y: Self.caretHeight, width: self.bounds.width, height: Self.bodyHeight)
    let path = NSBezierPath(roundedRect: bodyRect, xRadius: Self.bodyHeight / 2.0, yRadius: Self.bodyHeight / 2.0)
    let halfCaret = Self.caretWidth / 2.0
    let caretX = max(bodyRect.height / 2.0 + halfCaret, min(bodyRect.width - bodyRect.height / 2.0 - halfCaret, self.caretCenterX))
    let caret = NSBezierPath()
    caret.move(to: NSPoint(x: caretX - halfCaret, y: Self.caretHeight + 0.5))
    caret.line(to: NSPoint(x: caretX, y: 0))
    caret.line(to: NSPoint(x: caretX + halfCaret, y: Self.caretHeight + 0.5))
    caret.close()
    path.append(caret)
    let fill = self.isDarkAppearance ? NSColor(calibratedWhite: 0.78, alpha: 0.92) : NSColor(calibratedWhite: 0.08, alpha: 0.82)
    fill.setFill()
    path.fill()
  }
}

@available(macOS 26.0, *)
final class MacOS27TrackBarView: NSView {
  private static let segmentCount = 16
  private static let segmentGap: CGFloat = 2.0
  private static let segmentHeight: CGFloat = 3.5

  var progress: CGFloat = 0 {
    didSet {
      self.needsDisplay = true
    }
  }

  var isLocked: Bool = false {
    didSet {
      self.needsDisplay = true
    }
  }

  var isDarkAppearance: Bool? {
    didSet {
      if oldValue != self.isDarkAppearance {
        self.needsDisplay = true
      }
    }
  }

  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)
    let bounds = self.bounds
    let isDark = self.isDarkAppearance ?? (self.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua)
    let baseWhite: CGFloat = isDark ? 1.0 : 0.06
    let emptyAlpha: CGFloat = isDark ? 0.28 : 0.22
    let fillAlpha: CGFloat = isDark ? 0.98 : 0.90

    let count = CGFloat(Self.segmentCount)
    let segmentWidth = (bounds.width - Self.segmentGap * (count - 1)) / count
    let segmentY = round((bounds.height - Self.segmentHeight) / 2.0)
    let fillEndX = self.isLocked ? 0 : bounds.width * max(0, min(1, self.progress))

    for index in 0 ..< Self.segmentCount {
      let segmentX = CGFloat(index) * (segmentWidth + Self.segmentGap)
      let rect = NSRect(x: segmentX, y: segmentY, width: segmentWidth, height: Self.segmentHeight)
      let path = NSBezierPath(roundedRect: rect, xRadius: Self.segmentHeight / 2.0, yRadius: Self.segmentHeight / 2.0)
      NSColor(calibratedWhite: baseWhite, alpha: emptyAlpha).setFill()
      path.fill()
      if fillEndX > rect.minX {
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: fillEndX, height: bounds.height)).setClip()
        NSColor(calibratedWhite: baseWhite, alpha: fillAlpha).setFill()
        path.fill()
        NSGraphicsContext.restoreGraphicsState()
      }
    }
  }
}
