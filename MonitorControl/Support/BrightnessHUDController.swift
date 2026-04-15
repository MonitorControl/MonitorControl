//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Cocoa

class BrightnessHUDController {
  static let shared = BrightnessHUDController()

  private var windows: [CGDirectDisplayID: NSWindow] = [:]
  private var fadeTimers: [CGDirectDisplayID: Timer] = [:]

  func show(displayID: CGDirectDisplayID, value: Float, maxValue: Float) {
    DispatchQueue.main.async {
      self.showHUD(displayID: displayID, value: value, maxValue: maxValue)
    }
  }

  private func showHUD(displayID: CGDirectDisplayID, value: Float, maxValue: Float) {
    let percentage = maxValue > 0 ? min(max(value / maxValue, 0), 1) : 0
    let window: NSWindow
    let hudView: BrightnessHUDView

    if let existing = windows[displayID], let existingView = existing.contentView as? BrightnessHUDView {
      window = existing
      hudView = existingView
      hudView.update(percentage: percentage)
    } else {
      hudView = BrightnessHUDView(percentage: percentage)
      window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 56), styleMask: [.borderless], backing: .buffered, defer: false)
      window.contentView = hudView
      window.backgroundColor = .clear
      window.isOpaque = false
      window.level = .floating
      window.ignoresMouseEvents = true
      window.collectionBehavior = [.stationary, .canJoinAllSpaces, .ignoresCycle]
      window.hasShadow = true
      windows[displayID] = window
    }

    if let screen = NSScreen.screens.first(where: { $0.displayID == displayID }) {
      let screenFrame = screen.frame
      let windowFrame = window.frame
      let x = screenFrame.midX - windowFrame.width / 2
      let y = screenFrame.origin.y + screenFrame.height * 0.12
      window.setFrameOrigin(NSPoint(x: x, y: y))
    }

    window.alphaValue = 1.0
    window.orderFrontRegardless()

    fadeTimers[displayID]?.invalidate()
    fadeTimers[displayID] = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
      NSAnimationContext.runAnimationGroup({ context in
        context.duration = 0.3
        window.animator().alphaValue = 0
      }, completionHandler: {
        window.orderOut(nil)
        guard self?.windows[displayID] === window else { return }
        self?.windows.removeValue(forKey: displayID)
        self?.fadeTimers.removeValue(forKey: displayID)
      })
    }
  }
}

// MARK: - HUD View

private class BrightnessHUDView: NSVisualEffectView {
  private let progressBar = NSView()
  private let progressTrack = NSView()
  private let iconView = NSImageView()
  private let percentLabel = NSTextField(labelWithString: "")
  private var percentage: Float = 0

  convenience init(percentage: Float) {
    self.init(frame: NSRect(x: 0, y: 0, width: 200, height: 56))
    self.percentage = percentage
    setup()
  }

  private func setup() {
    material = .hudWindow
    blendingMode = .behindWindow
    state = .active
    wantsLayer = true
    layer?.cornerRadius = 14

    if #available(macOS 11.0, *) {
      iconView.image = NSImage(systemSymbolName: "sun.max.fill", accessibilityDescription: "Brightness")
      iconView.contentTintColor = .labelColor
    } else {
      iconView.image = NSImage(named: "NSBrightnessTemplate")
    }
    iconView.frame = NSRect(x: 12, y: 16, width: 24, height: 24)
    addSubview(iconView)

    progressTrack.frame = NSRect(x: 44, y: 24, width: 108, height: 8)
    progressTrack.wantsLayer = true
    progressTrack.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.2).cgColor
    progressTrack.layer?.cornerRadius = 4
    addSubview(progressTrack)

    progressBar.frame = NSRect(x: 0, y: 0, width: CGFloat(percentage) * 108, height: 8)
    progressBar.wantsLayer = true
    progressBar.layer?.backgroundColor = NSColor.white.cgColor
    progressBar.layer?.cornerRadius = 4
    progressTrack.addSubview(progressBar)

    percentLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
    percentLabel.textColor = .secondaryLabelColor
    percentLabel.stringValue = "\(Int(round(percentage * 100)))%"
    percentLabel.sizeToFit()
    percentLabel.frame.origin = NSPoint(x: 160, y: 20)
    addSubview(percentLabel)
  }

  func update(percentage: Float) {
    self.percentage = percentage
    progressBar.frame.size.width = CGFloat(percentage) * 108
    percentLabel.stringValue = "\(Int(round(percentage * 100)))%"
    percentLabel.sizeToFit()
  }
}
