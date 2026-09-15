// Adapted from Crisp. Copyright (c) 2026 Didrik Galteland.
// Distributed under the MIT license; see MonitorControl/UI/Crisp-LICENSE.txt.

import AppKit
import Combine

// SkyLight private API: read/toggle system dark mode
private let _SLSGetAppearanceTheme: (@convention(c) () -> Bool)? = {
  guard let h = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY),
        let sym = dlsym(h, "SLSGetAppearanceThemeLegacy") else { return nil }
  return unsafeBitCast(sym, to: (@convention(c) () -> Bool).self)
}()

private let _SLSSetAppearanceTheme: (@convention(c) (Bool) -> Void)? = {
  guard let h = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY),
        let sym = dlsym(h, "SLSSetAppearanceThemeLegacy") else { return nil }
  return unsafeBitCast(sym, to: (@convention(c) (Bool) -> Void).self)
}()

// Animated variant: with notify=true the switch goes through the same crossfade
// Control Center uses, instead of the instant Legacy flip.
private let _SLSSetAppearanceThemeNotifying: (@convention(c) (Bool, Bool) -> Void)? = {
  guard let h = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY),
        let sym = dlsym(h, "SLSSetAppearanceThemeNotifying") else { return nil }
  return unsafeBitCast(sym, to: (@convention(c) (Bool, Bool) -> Void).self)
}()

/// System-level Night Shift / True Tone / Dark Mode switches, implemented via private frameworks
/// (CoreBrightness's CBBlueLightClient / CBTrueToneClient + SkyLight).
/// Per project convention, loaded at runtime with dlopen + NSClassFromString/dlsym; private frameworks are not linked.
@MainActor
final class CoreBrightnessService: ObservableObject {
  static let shared = CoreBrightnessService()

  @Published var nightShiftEnabled = false
  @Published var trueToneEnabled = false
  @Published var darkModeEnabled = false
  private(set) var nightShiftAvailable = false
  // Published because availability changes at runtime: CBTrueToneClient reports
  // available=false in clamshell, so an app launched lid-closed must un-latch later.
  @Published private(set) var trueToneAvailable = false
  var darkModeAvailable: Bool { _SLSGetAppearanceTheme != nil && _SLSSetAppearanceTheme != nil }

  private var blueLightClient: NSObject?
  private var trueToneClient: NSObject?
  private(set) var nightShiftTemperature: NightShiftTemperatureController?

  private init() {
    guard dlopen("/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness", RTLD_LAZY) != nil else { return }
    if let cls = NSClassFromString("CBBlueLightClient") as? NSObject.Type {
      let client = cls.init()
      self.blueLightClient = client
      self.nightShiftAvailable = true
      if let temperatureClient = NightShiftTemperatureClient(client: client) {
        self.nightShiftTemperature = NightShiftTemperatureController(
          read: { await temperatureClient.read() },
          write: { await temperatureClient.write($0) }
        )
      }
    }
    if let cls = NSClassFromString("CBTrueToneClient") as? NSObject.Type {
      let client = cls.init()
      self.trueToneClient = client
      self.trueToneAvailable = Self.boolCall(client, "supported") && Self.boolCall(client, "available")
    }
    self.refresh()
    self.observeSystemChanges()
  }

  /// Keep the published state live while the panel is closed, so it opens already-correct
  /// instead of visibly flipping a beat after it appears (the on-open refresh then finds
  /// nothing to change). Dark mode broadcasts a distributed notification; Night Shift /
  /// True Tone deliver a CoreBrightness status callback. Each just re-reads via refresh(),
  /// event-driven, never a poll. Singleton, so the observers live for the process.
  private func observeSystemChanges() {
    // Dark mode: Control Center / System Settings post this app-wide.
    DistributedNotificationCenter.default().addObserver(
      forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
      object: nil, queue: .main
    ) { [weak self] _ in
      Task { @MainActor in self?.refresh() }
    }
    // Night Shift / True Tone: each client invokes this block on any status change.
    // Guarded by responds(to:) so a client lacking the selector is simply skipped.
    let onChange: @convention(block) () -> Void = { [weak self] in
      Task { @MainActor in self?.refresh() }
    }
    let sel = NSSelectorFromString("setStatusNotificationBlock:")
    for client in [self.blueLightClient, self.trueToneClient].compactMap({ $0 }) where client.responds(to: sel) {
      typealias Fn = @convention(c) (NSObject, Selector, @convention(block) () -> Void) -> Void
      unsafeBitCast(client.method(for: sel), to: Fn.self)(client, sel, onChange)
    }
  }

  /// Re-read the current system state (the user may have toggled it via Control Center).
  /// The reads are XPC round-trips, so they run off the main thread to keep
  /// panel opening snappy; results publish back on main.
  func refresh() {
    // Strength-only changes do not always emit the status callback. The
    // existing panel-open and visible-panel refreshes cover those too.
    if let nightShiftTemperature {
      Task { await nightShiftTemperature.refresh() }
    }
    // The CoreBrightness XPC client objects are safe to message from any
    // thread, but NSObject is not Sendable; box them across the hop.
    let blueBox = UncheckedSendable(value: blueLightClient)
    let ttBox = UncheckedSendable(value: trueToneClient)
    DispatchQueue.global(qos: .userInitiated).async {
      var nightShift: Bool?
      if let c = blueBox.value {
        var buf = [UInt8](repeating: 0, count: 64)
        let sel = NSSelectorFromString("getBlueLightStatus:")
        if c.responds(to: sel) {
          typealias Fn = @convention(c) (NSObject, Selector, UnsafeMutableRawPointer) -> Bool
          let ok = buf.withUnsafeMutableBytes {
            unsafeBitCast(c.method(for: sel), to: Fn.self)(c, sel, $0.baseAddress!)
          }
          // Status struct layout {BOOL active, BOOL enabled, ...}, enabled is at offset 1
          if ok { nightShift = buf[1] != 0 }
        }
      }
      var trueTone: Bool?
      var ttAvailable = false
      if let c = ttBox.value {
        // Re-check every refresh: availability flips with the lid (clamshell
        // hides True Tone system-wide), and init may have run lid-closed.
        ttAvailable = Self.boolCall(c, "supported") && Self.boolCall(c, "available")
        if ttAvailable { trueTone = Self.boolCall(c, "enabled") }
      }
      let dark = _SLSGetAppearanceTheme?()
      DispatchQueue.main.async {
        if let nightShift { self.nightShiftEnabled = nightShift }
        if self.trueToneAvailable != ttAvailable { self.trueToneAvailable = ttAvailable }
        if let trueTone { self.trueToneEnabled = trueTone }
        // Don't clobber an optimistic toggle: the async theme change
        // may still be in flight, and a stale read here snaps the
        // button back for a beat (the native control never does).
        if let dark, Date().timeIntervalSince(self.lastDarkModeSetAt) > 3.0 {
          self.darkModeEnabled = dark
        }
      }
    }
  }

  private var lastDarkModeSetAt = Date.distantPast

  func setDarkMode(_ on: Bool) {
    self.darkModeEnabled = on
    self.lastDarkModeSetAt = Date()
    // The eased color crossfade is AppKit's private NSGlobalPreferenceTransition:
    // grab a transition, flip the theme silently, then post the change through
    // the transition so every app animates. Same path System Settings and
    // Control Center use; plain SLS notify (and System Events) flip instantly.
    // Acquiring the transition BLOCKS in the window server while it snapshots
    // every display, so the whole dance runs off the main thread; the toggle
    // above renders instantly, like the native control.
    Task.detached(priority: .userInitiated) {
      // Let the flipped control reach the screen first: the transition
      // freezes a snapshot of the display for the crossfade, and it must
      // capture the button already released and re-tinted (the button
      // flips instantly, so one frame-commit beat suffices).
      try? await Task.sleep(nanoseconds: 120_000_000)
      let transition = (NSClassFromString("NSGlobalPreferenceTransition") as? NSObject.Type)?
        .perform(NSSelectorFromString("transition"))?.takeUnretainedValue() as? NSObject
      if let setNotifying = _SLSSetAppearanceThemeNotifying {
        setNotifying(on, transition == nil)
      } else {
        _SLSSetAppearanceTheme?(on)
      }
      if let transition, transition.responds(to: NSSelectorFromString("postChangeNotification:completionHandler:")) {
        let sel = NSSelectorFromString("postChangeNotification:completionHandler:")
        typealias Post = @convention(c) (NSObject, Selector, Int, @escaping @convention(block) () -> Void) -> Void
        // Completion keeps the transition alive until the crossfade finishes.
        unsafeBitCast(transition.method(for: sel), to: Post.self)(transition, sel, 0, { _ = transition })
      }
    }
  }

  func setNightShift(_ on: Bool) {
    guard let c = blueLightClient else { return }
    Self.setBoolCall(c, "setEnabled:", on)
    self.nightShiftEnabled = on
  }

  func setTrueTone(_ on: Bool) {
    guard let c = trueToneClient else { return }
    Self.setBoolCall(c, "setEnabled:", on)
    self.trueToneEnabled = on
  }

  // MARK: - ObjC runtime call helpers

  private nonisolated static func boolCall(_ obj: NSObject, _ name: String) -> Bool {
    let sel = NSSelectorFromString(name)
    guard obj.responds(to: sel) else { return false }
    typealias Fn = @convention(c) (NSObject, Selector) -> Bool
    return unsafeBitCast(obj.method(for: sel), to: Fn.self)(obj, sel)
  }

  private nonisolated static func setBoolCall(_ obj: NSObject, _ name: String, _ v: Bool) {
    let sel = NSSelectorFromString(name)
    guard obj.responds(to: sel) else { return }
    typealias Fn = @convention(c) (NSObject, Selector, Bool) -> Void
    unsafeBitCast(obj.method(for: sel), to: Fn.self)(obj, sel, v)
  }
}

/// Carries a value across a `@Sendable` boundary the compiler cannot verify.
/// Only for objects that are documented or observed thread-safe to message
/// (here: the CoreBrightness XPC client objects).
private struct UncheckedSendable<T>: @unchecked Sendable { let value: T }
