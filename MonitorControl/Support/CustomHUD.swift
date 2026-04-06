//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others
//  CustomHUD.swift - Custom OSD overlay for macOS Tahoe 26+ compatibility

import Cocoa

#if swift(>=5.3)
import SwiftUI
#endif

// MARK: - Custom HUD Manager

/// Manages custom HUD windows for brightness/volume display on macOS 26+
/// where the native OSD API no longer works correctly
class CustomHUDManager {
    static let shared = CustomHUDManager()
    
    private var hudWindows: [CGDirectDisplayID: NSWindow] = [:]
    private let hudLock = NSLock()
    
    private init() {}
    
    /// Shows a custom HUD on the specified display
    func showHUD(displayID: CGDirectDisplayID, type: HUDType, value: Float, maxValue: Float = 1.0) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.hudLock.lock()
            defer { self.hudLock.unlock() }
            
            // Get or create HUD window for this display
            let window: NSWindow
            if let existingWindow = self.hudWindows[displayID] {
                window = existingWindow
            } else {
                window = self.createHUDWindow(displayID: displayID)
                self.hudWindows[displayID] = window
            }
            
            // Update and show the HUD
            self.updateWindowContent(window: window, displayID: displayID, type: type, value: value, maxValue: maxValue)
            self.showWindowWithFade(window: window)
        }
    }
    
    private func createHUDWindow(displayID: CGDirectDisplayID) -> NSWindow {
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 260, height: 56),
            styleMask: [.nonactivatingPanel, .hudWindow],
            backing: .buffered,
            defer: false
        )
        
        window.level = .floating
        window.isFloatingPanel = true
        window.hidesOnDeactivate = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isMovable = false
        window.isMovableByWindowBackground = false
        window.ignoresMouseEvents = true
        
        positionWindow(window, onDisplay: displayID)
        
        return window
    }
    
    private func positionWindow(_ window: NSWindow, onDisplay displayID: CGDirectDisplayID) {
        guard let screen = getScreen(for: displayID) else { return }
        
        let screenFrame = screen.visibleFrame
        let windowSize = window.frame.size
        
        // Position at center-bottom of screen, above the dock
        let x = screenFrame.origin.x + (screenFrame.width - windowSize.width) / 2
        let y = screenFrame.origin.y + 100 // 100 points from bottom
        
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }
    
    private func getScreen(for displayID: CGDirectDisplayID) -> NSScreen? {
        return NSScreen.screens.first { screen in
            guard let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                return false
            }
            return CGDirectDisplayID(screenNumber.uint32Value) == displayID
        }
    }
    
    private func updateWindowContent(window: NSWindow, displayID: CGDirectDisplayID, type: HUDType, value: Float, maxValue: Float) {
        // Create content view using AppKit for maximum compatibility
        let contentView = createHUDContentView(type: type, value: value, maxValue: maxValue)
        window.contentView = contentView
        
        // Re-position in case screen changed
        positionWindow(window, onDisplay: displayID)
    }
    
    private func createHUDContentView(type: HUDType, value: Float, maxValue: Float) -> NSView {
        let w: CGFloat = 260
        let h: CGFloat = 56
        let containerView = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: w, height: h))
        containerView.material = .hudWindow
        containerView.blendingMode = .behindWindow
        containerView.state = .active
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = h / 2
        containerView.layer?.masksToBounds = true

        let iconSize: CGFloat = 26
        let iconView = NSImageView(frame: NSRect(x: 18, y: (h - iconSize) / 2, width: iconSize, height: iconSize))
        iconView.imageScaling = .scaleProportionallyDown
        iconView.wantsLayer = true
        iconView.layer?.isOpaque = false
        iconView.layer?.backgroundColor = NSColor.clear.cgColor
        if #available(macOS 11.0, *) {
            if let icon = NSImage(systemSymbolName: type.iconSystemName, accessibilityDescription: nil) {
                if #available(macOS 12.0, *) {
                    let base = NSImage.SymbolConfiguration(pointSize: iconSize * 0.85, weight: .semibold)
                    let palette = NSImage.SymbolConfiguration(paletteColors: [type.iconNSColor])
                    iconView.image = icon.withSymbolConfiguration(base.applying(palette))
                    iconView.contentTintColor = nil
                } else {
                    iconView.image = icon
                    iconView.contentTintColor = type.iconNSColor
                }
            }
        } else {
            let fallbackIcon: String
            switch type {
            case .brightness: fallbackIcon = NSImage.touchBarComposeTemplateName
            case .volume: fallbackIcon = NSImage.touchBarAudioOutputVolumeHighTemplateName
            case .volumeMuted: fallbackIcon = NSImage.touchBarAudioOutputMuteTemplateName
            case .contrast: fallbackIcon = NSImage.touchBarColorPickerFillName
            }
            iconView.image = NSImage(named: fallbackIcon)
            iconView.contentTintColor = type.iconNSColor
        }
        containerView.addSubview(iconView)

        let barX: CGFloat = 18 + iconSize + 12
        let barW: CGFloat = w - barX - 56
        let barH: CGFloat = 10
        let barY = (h - barH) / 2

        let progressBg = NSView(frame: NSRect(x: barX, y: barY, width: barW, height: barH))
        progressBg.wantsLayer = true
        progressBg.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.22).cgColor
        progressBg.layer?.cornerRadius = barH / 2
        containerView.addSubview(progressBg)

        let normalizedValue = CGFloat(min(max(value / maxValue, 0), 1))
        let progressFill = NSView(frame: NSRect(x: barX, y: barY, width: max(barH, barW * normalizedValue), height: barH))
        progressFill.wantsLayer = true
        progressFill.layer?.backgroundColor = NSColor.white.cgColor
        progressFill.layer?.cornerRadius = barH / 2
        containerView.addSubview(progressFill)

        let percentage = Int(normalizedValue * 100)
        let label = NSTextField(labelWithString: "\(percentage)%")
        label.frame = NSRect(x: barX + barW + 8, y: (h - 22) / 2, width: 44, height: 22)
        label.font = NSFont.monospacedDigitSystemFont(ofSize: 15, weight: .semibold)
        label.textColor = .white
        label.alignment = .right
        containerView.addSubview(label)

        return containerView
    }
    
    private var fadeTimers: [CGDirectDisplayID: Timer] = [:]
    
    private func showWindowWithFade(window: NSWindow) {
        // Find the displayID for this window
        guard let displayID = hudWindows.first(where: { $0.value === window })?.key else { return }
        
        // Cancel any existing fade timer
        fadeTimers[displayID]?.invalidate()
        
        // Make window fully visible
        window.alphaValue = 1.0
        window.orderFrontRegardless()
        
        // Schedule fade out after 1.5 seconds
        fadeTimers[displayID] = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self, weak window] _ in
            guard let window = window else { return }
            self?.fadeOut(window: window)
        }
    }
    
    private func fadeOut(window: NSWindow) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            window.animator().alphaValue = 0
        } completionHandler: {
            window.orderOut(nil)
        }
    }
    
    /// Cleans up HUD windows for removed displays
    func cleanupDisplay(_ displayID: CGDirectDisplayID) {
        hudLock.lock()
        defer { hudLock.unlock() }
        
        fadeTimers[displayID]?.invalidate()
        fadeTimers.removeValue(forKey: displayID)
        
        if let window = hudWindows[displayID] {
            window.close()
            hudWindows.removeValue(forKey: displayID)
        }
    }
}

// MARK: - HUD Type

enum HUDType {
    case brightness
    case volume
    case volumeMuted
    case contrast
    
    var iconSystemName: String {
        switch self {
        case .brightness: return "sun.max.fill"
        case .volume: return "speaker.wave.2.fill"
        case .volumeMuted: return "speaker.slash.fill"
        case .contrast: return "circle.lefthalf.filled"
        }
    }
    
    var iconNSColor: NSColor {
        switch self {
        case .brightness: return .systemYellow
        case .volume, .volumeMuted: return .systemBlue
        case .contrast: return .systemGray
        }
    }
}
