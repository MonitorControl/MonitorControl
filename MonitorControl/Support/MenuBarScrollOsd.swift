//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Cocoa
import Foundation

// Small custom HUD popping up under the menu bar icon while changing brightness with the scroll wheel.
// The system OSD is suppressed for scroll based changes, this gives the feedback instead.
class MenuBarScrollOsd {
  static let osdWidth: CGFloat = 190
  static let osdHeight: CGFloat = 34

  private let menuBarGap: CGFloat = 6 // Gap between the menu bar and the HUD
  private let visibleDuration: TimeInterval = 1.3
  private let fadeDuration: TimeInterval = 0.25

  private var panel: NSPanel?
  private var contentView: MenuBarScrollOsdView?
  private var hideTimer: Timer?

  func show(value: Float) {
    let panel = self.panel ?? self.makePanel()
    panel.setFrameOrigin(self.originForPanel())
    self.contentView?.value = max(0, min(1, value))
    self.contentView?.needsDisplay = true
    self.hideTimer?.invalidate()
    panel.alphaValue = 1
    panel.orderFrontRegardless()
    panel.invalidateShadow()
    self.hideTimer = Timer.scheduledTimer(withTimeInterval: self.visibleDuration, repeats: false) { [weak self] _ in
      self?.hide()
    }
  }

  func hide() {
    self.hideTimer?.invalidate()
    self.hideTimer = nil
    guard let panel = self.panel, panel.isVisible else {
      return
    }
    NSAnimationContext.runAnimationGroup { context in
      context.duration = self.fadeDuration
      panel.animator().alphaValue = 0
    } completionHandler: {
      panel.orderOut(nil)
    }
  }

  private func makePanel() -> NSPanel {
    let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: Self.osdWidth, height: Self.osdHeight), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
    panel.isFloatingPanel = true
    panel.level = .statusBar
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = true
    panel.ignoresMouseEvents = true
    panel.hidesOnDeactivate = false
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    let contentView = MenuBarScrollOsdView(frame: NSRect(x: 0, y: 0, width: Self.osdWidth, height: Self.osdHeight))
    panel.contentView = contentView
    self.contentView = contentView
    self.panel = panel
    return panel
  }

  // Centered under the menu bar icon, kept inside the screen holding it.
  private func originForPanel() -> NSPoint {
    guard let buttonWindow = app.statusItem.button?.window else {
      let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: Self.osdWidth, height: Self.osdHeight)
      return NSPoint(x: screenFrame.midX - Self.osdWidth / 2, y: screenFrame.maxY - Self.osdHeight - self.menuBarGap)
    }
    let anchor = buttonWindow.frame
    let screenFrame = (NSScreen.screens.first { $0.frame.intersects(anchor) } ?? NSScreen.main)?.frame ?? anchor
    let x = min(max(anchor.midX - Self.osdWidth / 2, screenFrame.minX + 8), screenFrame.maxX - Self.osdWidth - 8)
    return NSPoint(x: x, y: anchor.minY - Self.osdHeight - self.menuBarGap)
  }
}

class MenuBarScrollOsdView: NSView {
  var value: Float = 0

  private let horizontalInset: CGFloat = 13
  private let iconSize: CGFloat = 16
  private let barHeight: CGFloat = 8
  private let percentageWidth: CGFloat = 40

  override func draw(_: NSRect) {
    NSColor.windowBackgroundColor.setFill()
    NSBezierPath(roundedRect: self.bounds, xRadius: self.bounds.height / 2, yRadius: self.bounds.height / 2).fill()

    var barMinX = self.horizontalInset
    if !DEBUG_MACOS10, #available(macOS 11.0, *), let icon = NSImage(systemSymbolName: "sun.max.fill", accessibilityDescription: nil) {
      let configuredIcon = icon.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)) ?? icon
      configuredIcon.isTemplate = true
      let iconRect = NSRect(x: self.horizontalInset, y: (self.bounds.height - self.iconSize) / 2, width: self.iconSize, height: self.iconSize)
      NSColor.labelColor.set()
      configuredIcon.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: 0.85)
      barMinX = iconRect.maxX + 9
    }

    let percentageMinX = self.bounds.width - self.horizontalInset - self.percentageWidth
    let barRect = NSRect(x: barMinX, y: (self.bounds.height - self.barHeight) / 2, width: percentageMinX - 9 - barMinX, height: self.barHeight)
    let barRadius = self.barHeight / 2
    NSColor.tertiaryLabelColor.setFill()
    NSBezierPath(roundedRect: barRect, xRadius: barRadius, yRadius: barRadius).fill()
    let filledWidth = max(self.barHeight, barRect.width * CGFloat(max(0, min(1, self.value))))
    NSColor.systemGreen.setFill()
    NSBezierPath(roundedRect: NSRect(x: barRect.minX, y: barRect.minY, width: filledWidth, height: self.barHeight), xRadius: barRadius, yRadius: barRadius).fill()

    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.alignment = .right
    let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 12, weight: .medium), .foregroundColor: NSColor.secondaryLabelColor, .paragraphStyle: paragraphStyle]
    let percentage = NSAttributedString(string: "\(Int(self.value * 100))%", attributes: attributes)
    percentage.draw(in: NSRect(x: percentageMinX, y: (self.bounds.height - 15) / 2, width: self.percentageWidth, height: 15))
  }
}
