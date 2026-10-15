import Cocoa
import os.log

if CommandLine.arguments.contains("--self-test") {
  assert(ModernVolumeOSD.normalizedVolume(value: 0.5, maxValue: 1) == 0.5)
  assert(ModernVolumeOSD.normalizedVolume(value: -1, maxValue: 1) == 0)
  assert(ModernVolumeOSD.normalizedVolume(value: 2, maxValue: 1) == 1)
  assert(ModernVolumeOSD.normalizedVolume(value: 50, maxValue: 100) == 0.5)
  assert(ModernVolumeOSD.normalizedVolume(value: .nan, maxValue: 1) == nil)
  assert(ModernVolumeOSD.normalizedVolume(value: .infinity, maxValue: 1) == nil)
  assert(ModernVolumeOSD.normalizedVolume(value: 1, maxValue: 0) == nil)
  assert(ModernVolumeOSD.normalizedVolume(value: 1, maxValue: -.infinity) == nil)
  assert(!ModernVolumeOSD.show(displayID: .max, value: 0.5, maxValue: 1, isMuted: false))
  // Layer CGColors must refresh when the system appearance changes.
  let preview = ModernVolumeView()
  let track = preview.contentView!.subviews[1]
  let fill = track.subviews[0]
  for appearanceName in [NSAppearance.Name.aqua, .darkAqua, .aqua] {
    let appearance = NSAppearance(named: appearanceName)!
    preview.appearance = appearance
    preview.viewDidChangeEffectiveAppearance()
    appearance.performAsCurrentDrawingAppearance {
      assert(fill.layer?.backgroundColor == NSColor.labelColor.cgColor)
      assert(track.layer?.backgroundColor == NSColor.labelColor.withAlphaComponent(0.15).cgColor)
    }
  }
  os_log("Volume normalization, missing-display fallback and appearance checks passed")
  exit(0)
}

final class DemoDelegate: NSObject, NSApplicationDelegate {
  private var window: NSWindow?
  private var value: Float = 0.5
  private var isMuted = false
  private var inspectionTimer: Timer?
  private let status = NSTextField(labelWithString: "Preview volume: 50%")
  private let displayPicker = NSPopUpButton()
  private let previewView = ModernVolumeView()

  func applicationDidFinishLaunching(_: Notification) {
    if CommandLine.arguments.contains("--lifecycle-test") {
      self.checkLifecycle()
      return
    }
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 440, height: 300), styleMask: [.titled, .closable], backing: .buffered, defer: false)
    window.title = "Modern Volume OSD Prototype"
    let stack = NSStackView()
    stack.orientation = .vertical
    stack.spacing = 16
    stack.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
    stack.addArrangedSubview(NSTextField(labelWithString: "Visual preview only. Speaker volume is unchanged."))
    self.displayPicker.addItems(withTitles: NSScreen.screens.map { $0.localizedName })
    stack.addArrangedSubview(self.displayPicker)
    stack.addArrangedSubview(self.status)
    self.previewView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      self.previewView.widthAnchor.constraint(equalToConstant: 196),
      self.previewView.heightAnchor.constraint(equalToConstant: 48),
    ])
    stack.addArrangedSubview(self.previewView)
    let buttons = NSStackView()
    for (title, action) in [("Volume down", #selector(self.down)), ("Volume up", #selector(self.up)), ("Mute / unmute", #selector(self.mute)), ("Preview", #selector(self.preview))] {
      buttons.addArrangedSubview(NSButton(title: title, target: self, action: action))
    }
    stack.addArrangedSubview(buttons)
    stack.addArrangedSubview(NSButton(title: "Inspect HUD for 10 seconds", target: self, action: #selector(self.inspectHUD)))
    window.contentView = stack
    window.center()
    window.makeKeyAndOrderFront(nil)
    self.window = window
    NSApplication.shared.activate(ignoringOtherApps: true)
    self.preview()
  }

  @objc private func down() { self.value = max(0, self.value - 1 / 16); self.isMuted = false; self.preview() }
  @objc private func up() { self.value = min(1, self.value + 1 / 16); self.isMuted = false; self.preview() }
  @objc private func mute() { self.isMuted.toggle(); self.preview() }
  @objc private func preview() {
    self.status.stringValue = self.isMuted ? "Preview volume: muted" : "Preview volume: \(Int((self.value * 100).rounded()))%"
    self.previewView.update(level: self.isMuted ? 0 : CGFloat(self.value), isMuted: self.isMuted || self.value == 0)
    let screens = NSScreen.screens
    guard screens.indices.contains(self.displayPicker.indexOfSelectedItem),
          let displayID = (screens[self.displayPicker.indexOfSelectedItem].deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value else { return }
    ModernVolumeOSD.show(displayID: displayID, value: self.value, maxValue: 1, isMuted: self.isMuted)
  }

  @objc private func inspectHUD() {
    self.inspectionTimer?.invalidate()
    self.window?.orderOut(nil)
    self.preview()
    var remainingTicks = 25
    self.inspectionTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] timer in
      guard let self = self else { timer.invalidate(); return }
      remainingTicks -= 1
      if remainingTicks <= 0 {
        timer.invalidate()
        self.inspectionTimer = nil
        self.window?.makeKeyAndOrderFront(nil)
      } else {
        self.preview()
      }
    }
  }

  private func checkLifecycle() {
    guard let screen = NSScreen.screens.first,
          let displayID = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value else { fatalError("Lifecycle test needs a display") }
    assert(ModernVolumeOSD.show(displayID: displayID, value: 0.5, maxValue: 1, isMuted: false))
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.05) {
      // A new key press while the old fade is running must keep the HUD visible.
      assert(ModernVolumeOSD.show(displayID: displayID, value: 0.75, maxValue: 1, isMuted: false))
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
      assert(NSApplication.shared.windows.contains { $0.isVisible && $0.alphaValue > 0.9 })
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
      assert(!NSApplication.shared.windows.contains { $0.isVisible })
      assert(ModernVolumeOSD.show(displayID: displayID, value: 1, maxValue: 1, isMuted: true))
      assert(NSApplication.shared.windows.contains { $0.isVisible })
      ModernVolumeOSD.dismissAll()
      assert(!NSApplication.shared.windows.contains { $0.isVisible })
      os_log("Fade interruption, auto-dismiss, mute presentation and cleanup checks passed")
      NSApplication.shared.terminate(nil)
    }
  }

  func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool { true }
  func applicationWillTerminate(_: Notification) { self.inspectionTimer?.invalidate(); ModernVolumeOSD.dismissAll() }
}

let application = NSApplication.shared
let delegate = DemoDelegate()
application.setActivationPolicy(.regular)
application.delegate = delegate
application.run()
