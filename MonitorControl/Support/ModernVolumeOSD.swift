import Cocoa

/// An opt-in, app-drawn volume indicator. This does not drive audio or DDC.
@available(macOS 26.0, *)
final class ModernVolumeOSD {
  private static var indicators: [CGDirectDisplayID: ModernVolumeOSD] = [:]
  private let panel: NSPanel
  private let indicatorView = ModernVolumeView()
  private var dismissWork: DispatchWorkItem?
  private var revision = 0

  static func normalizedVolume(value: Float, maxValue: Float) -> CGFloat? {
    guard value.isFinite, maxValue.isFinite, maxValue > 0 else { return nil }
    return CGFloat(min(max(value / maxValue, 0), 1))
  }

  @discardableResult
  static func show(displayID: CGDirectDisplayID, value: Float, maxValue: Float, isMuted: Bool) -> Bool {
    guard Thread.isMainThread,
          let level = self.normalizedVolume(value: value, maxValue: maxValue),
          let screen = NSScreen.screens.first(where: {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == displayID
          }) else { return false }
    let indicator = self.indicators[displayID] ?? ModernVolumeOSD()
    self.indicators[displayID] = indicator
    indicator.show(screen: screen, displayID: displayID, level: isMuted ? 0 : level, isMuted: isMuted || level == 0)
    return true
  }

  static func dismissAll() {
    for indicator in self.indicators.values {
      indicator.dismissWork?.cancel()
      indicator.revision += 1
      indicator.panel.orderOut(nil)
    }
    self.indicators.removeAll()
  }

  private init() {
    let bounds = NSRect(x: 0, y: 0, width: 196, height: 48)
    self.panel = NSPanel(contentRect: bounds, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    self.panel.isOpaque = false
    self.panel.backgroundColor = .clear
    self.panel.level = .statusBar
    self.panel.hasShadow = true
    self.panel.ignoresMouseEvents = true
    self.panel.hidesOnDeactivate = false
    self.panel.isReleasedWhenClosed = false
    self.panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

    self.panel.contentView = self.indicatorView
  }

  private func show(screen: NSScreen, displayID: CGDirectDisplayID, level: CGFloat, isMuted: Bool) {
    self.dismissWork?.cancel()
    self.revision += 1
    let revision = self.revision
    self.indicatorView.update(level: level, isMuted: isMuted)
    // Keep the HUD inside the visible frame, below the menu bar and clear of the notch.
    self.panel.setFrameOrigin(NSPoint(x: screen.visibleFrame.maxX - 216, y: screen.visibleFrame.maxY - 64))
    let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    let wasVisible = self.panel.isVisible
    if !wasVisible { self.panel.alphaValue = reduceMotion ? 1 : 0 }
    self.panel.orderFrontRegardless()
    NSAnimationContext.runAnimationGroup { context in
      context.duration = reduceMotion || wasVisible ? 0 : 0.12
      self.panel.animator().alphaValue = 1
    }
    let work = DispatchWorkItem { [weak self] in
      guard let self = self, self.revision == revision else { return }
      NSAnimationContext.runAnimationGroup({ context in
        context.duration = reduceMotion ? 0 : 0.2
        self.panel.animator().alphaValue = 0
      }, completionHandler: { [weak self] in
        guard let self = self, self.revision == revision else { return }
        self.panel.orderOut(nil)
        ModernVolumeOSD.indicators.removeValue(forKey: displayID)
      })
    }
    self.dismissWork = work
    DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: work)
  }
}

/// Shared by the floating indicator and standalone visual preview.
@available(macOS 26.0, *)
final class ModernVolumeView: NSGlassEffectView {
  private let icon = NSImageView()
  private let track = NSView()
  private let fill = NSView()

  init() {
    let bounds = NSRect(x: 0, y: 0, width: 196, height: 48)
    super.init(frame: bounds)
    self.style = .regular
    self.cornerRadius = 24
    let content = NSView(frame: bounds)
    self.contentView = content
    self.icon.frame = NSRect(x: 16, y: 14, width: 22, height: 20)
    self.icon.contentTintColor = .labelColor
    content.addSubview(self.icon)
    self.track.frame = NSRect(x: 50, y: 20, width: 128, height: 8)
    self.track.wantsLayer = true
    self.track.layer?.cornerRadius = 4
    self.fill.wantsLayer = true
    self.fill.layer?.cornerRadius = 4
    self.track.addSubview(self.fill)
    content.addSubview(self.track)
    self.track.setAccessibilityElement(true)
    self.track.setAccessibilityRole(.levelIndicator)
    self.track.setAccessibilityLabel(NSLocalizedString("Volume", comment: "Volume indicator accessibility label"))
    self.updateColors()
  }

  required init?(coder: NSCoder) { return nil }

  override func viewDidChangeEffectiveAppearance() {
    super.viewDidChangeEffectiveAppearance()
    self.updateColors()
  }

  private func updateColors() {
    self.effectiveAppearance.performAsCurrentDrawingAppearance {
      self.track.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.15).cgColor
      self.fill.layer?.backgroundColor = NSColor.labelColor.cgColor
    }
  }

  func update(level: CGFloat, isMuted: Bool) {
    let symbol = isMuted ? "speaker.slash.fill" : (level < 0.5 ? "speaker.wave.1.fill" : "speaker.wave.3.fill")
    self.icon.image = NSImage(systemSymbolName: symbol, accessibilityDescription: isMuted ? "Muted" : "Volume")
    self.track.setAccessibilityValue(isMuted ? "Muted" : "\(Int((level * 100).rounded()))%")
    self.fill.frame = NSRect(x: 0, y: 0, width: self.track.bounds.width * level, height: 8)
  }
}
