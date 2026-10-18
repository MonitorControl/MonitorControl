import AppKit

/// Keeps the existing deployment target and original behavior on older systems.
final class MonitorSoftwareAudio {
  private let backend: AnyObject?
  init() {
    if #available(macOS 15.0, *) { backend = SoftwareAudioController() }
    else { backend = nil }
  }
  var ownsCurrentOutput: Bool {
    if #available(macOS 15.0, *), let backend = backend as? SoftwareAudioController { return backend.ownsCurrentOutput }
    return false
  }
  var sliderValue: Float {
    if #available(macOS 15.0, *), let backend = backend as? SoftwareAudioController { return Float(backend.audio.muted ? 0 : backend.audio.volume) }
    return 0
  }
  func configured(_ display: Display) -> Bool {
    if #available(macOS 15.0, *), let backend = backend as? SoftwareAudioController { return backend.configured(display) }
    return false
  }
  func start() {
    if #available(macOS 15.0, *), let backend = backend as? SoftwareAudioController { backend.start() }
  }
  func stop() {
    if #available(macOS 15.0, *), let backend = backend as? SoftwareAudioController { backend.stop() }
  }
  func stopForSleep() {
    if #available(macOS 15.0, *), let backend = backend as? SoftwareAudioController { backend.audio.stopForSleep() }
  }
  func resume() {
    if #available(macOS 15.0, *), let backend = backend as? SoftwareAudioController { backend.audio.resume() }
  }
  func stepVolume(isUp: Bool, isSmallIncrement: Bool, display: OtherDisplay) {
    if #available(macOS 15.0, *), let backend = backend as? SoftwareAudioController {
      backend.audio.setVolume(backend.audio.volume + (isUp ? 1 : -1) * (isSmallIncrement ? 0.0125 : 0.05))
      backend.refresh(display)
    }
  }
  func toggleMute(display: OtherDisplay, showHUD: Bool) {
    if #available(macOS 15.0, *), let backend = backend as? SoftwareAudioController {
      backend.audio.toggleMute(); backend.refresh(display, showHUD: showHUD)
    }
  }
  func set(_ value: Float, display: OtherDisplay) {
    if #available(macOS 15.0, *), let backend = backend as? SoftwareAudioController { backend.set(value, display: display) }
  }
  func addMenu(to menu: NSMenu) {
    if #available(macOS 15.0, *), let backend = backend as? SoftwareAudioController { backend.addMenu(to: menu) }
  }
}

// Optional software attenuation for digital monitor outputs.

@available(macOS 15.0, *)
private final class SoftwareAudioController: NSObject {
  let audio = SoftwareVolume(preferences: UserDefaults.standard)
  private var volumeTap: CFMachPort?
  private var volumeSource: CFRunLoopSource?
  private var mediaGate = VolumeMediaEventGate()
  private var timer: Timer?
  var enabled: Bool { prefs.bool(forKey: "softwareAudioEnabled") }
  var selectedDisplayID: String { prefs.string(forKey: "softwareAudioDisplayID") ?? "" }
  func configured(_ display: Display) -> Bool { enabled && display.prefsId == selectedDisplayID }
  var ownsCurrentOutput: Bool { enabled && audio.handlesVolumeKeys }
  func start() {
    audio.onRouteChanged = { [weak self] in
      self?.audio.reconcile()
      self?.reconcileVolumeTap()
      app.updateMenusAndKeys()
    }
    audio.onStatus = { [weak self] _, _ in self?.reconcileVolumeTap(); app.updateMenusAndKeys() }
    audio.observeOutputChanges()
    audio.restoreEnabled()
    // Volume and mute use native multimedia events with duplicate filtering.
    timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
      self?.audio.reconcile()
      self?.reconcileVolumeTap()
    }
  }
  func reconcileVolumeTap() {
    guard audio.handlesVolumeKeys else { releaseVolumeTap(); return }
    if let tap = volumeTap {
      if !CGEvent.tapIsEnabled(tap: tap) { CGEvent.tapEnable(tap: tap, enable: true) }
      return
    }
    // Filter volume at the session stage so unrelated playback keys retain
    // their normal routing to Spotify and other media applications.
    volumeTap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: CGEventMask(1 << 14), callback: { _, type, event, context in
      guard let context = context else { return Unmanaged.passUnretained(event) }
      let owner = Unmanaged<SoftwareAudioController>.fromOpaque(context).takeUnretainedValue()
      if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let tap = owner.volumeTap { CGEvent.tapEnable(tap: tap, enable: true) }
        return Unmanaged.passUnretained(event)
      }
      guard owner.audio.handlesVolumeKeys,
        let ns = NSEvent(cgEvent: event), ns.type == .systemDefined, ns.subtype.rawValue == 8 else { return Unmanaged.passUnretained(event) }
      let key = (ns.data1 >> 16) & 0xffff
      guard key == 0 || key == 1 || key == 7 else { return Unmanaged.passUnretained(event) }
      if owner.mediaGate.accepts(key: key, phase: (ns.data1 >> 8) & 0xff,
        repeatEvent: (ns.data1 & 1) != 0, now: ProcessInfo.processInfo.systemUptime) {
        let modifiers = ns.modifierFlags
        if modifiers.contains(.option), !modifiers.contains(.shift),
          !modifiers.contains(.control), !modifiers.contains(.command) {
          if ns.data1 & 1 == 0 {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/PreferencePanes/Sound.prefPane"))
          }
        } else {
          let fineKeys = modifiers.contains(.option) && modifiers.contains(.shift)
          let fineDefault = prefs.bool(forKey: PrefKey.useFineScaleVolume.rawValue)
          owner.perform(key == 7 ? 0 : (key == 0 ? 1 : -1), isSmallIncrement: fineKeys != fineDefault)
        }
      }
      return nil
    }, userInfo: Unmanaged.passUnretained(self).toOpaque())
    if let tap = volumeTap {
      volumeSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
      if let source = volumeSource { CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes) }
      CGEvent.tapEnable(tap: tap, enable: true)
    }

  }
  func releaseVolumeTap() {
    if let tap = volumeTap { CFMachPortInvalidate(tap) }
    if let source = volumeSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
    volumeTap = nil; volumeSource = nil
  }

  func perform(_ action: Int, isSmallIncrement: Bool = false) {
    guard let display = DisplayManager.shared.getOtherDisplays().first(where: { configured($0) }) else { return }
    if action == 0 { audio.toggleMute() }
    else { audio.setVolume(audio.volume + Double(action) * (isSmallIncrement ? 0.0125 : 0.05)) }
    refresh(display)
  }
  func refresh(_ display: OtherDisplay, showHUD: Bool = true) {
    let value = Float(audio.muted ? 0 : audio.volume)
    display.savePref(value, for: .audioSpeakerVolume)
    display.savePref(audio.muted ? 1 : 2, for: .audioMuteScreenBlank)
    display.sliderHandler[.audioSpeakerVolume]?.setValue(value, displayID: display.identifier)
    if showHUD { OSDUtils.showOsd(displayID: display.identifier, command: .audioSpeakerVolume, value: value) }
  }
  func set(_ value: Float, display: OtherDisplay) {
    audio.setVolume(Double(value)); refresh(display, showHUD: false)
  }
  func addMenu(to menu: NSMenu) {
    let item = NSMenuItem(title: enabled ? NSLocalizedString("Disable Software Volume", comment: "Software volume") : NSLocalizedString("Enable Software Volume for This Output…", comment: "Software volume"), action: #selector(toggle), keyEquivalent: "")
    item.target = self
    menu.addItem(NSMenuItem.separator()); menu.addItem(item)
    if enabled {
      let status = NSMenuItem(title: audio.message, action: nil, keyEquivalent: "")
      status.isEnabled = false; menu.addItem(status)
      let mute = NSMenuItem(title: audio.muted ? NSLocalizedString("Unmute", comment: "Software volume") : NSLocalizedString("Mute", comment: "Software volume"), action: #selector(toggleMute), keyEquivalent: "")
      mute.target = self; mute.isEnabled = ownsCurrentOutput; menu.addItem(mute)
      if !audio.running && audio.targetIsSelected {
        let retry = NSMenuItem(title: NSLocalizedString("Retry Audio Connection", comment: "Software volume"), action: #selector(retryAudio), keyEquivalent: "")
        retry.target = self; menu.addItem(retry)
      }
    }
  }
  @objc func retryAudio() { audio.enable() }
  @objc func toggleMute() { perform(0) }
  @objc func toggle() {
    if enabled { audio.disable(); app.updateMenusAndKeys(); return }
    guard let output = try? AudioDevices.defaultOutput(),
      let display = DisplayManager.shared.getOtherDisplays().first(where: { $0.name.caseInsensitiveCompare(output.name) == .orderedSame }) else {
      let alert = NSAlert(); alert.messageText = NSLocalizedString("Select the Monitor Audio Output", comment: "Software volume")
      alert.informativeText = NSLocalizedString("Select the external monitor as the audio output before enabling software volume. Built-in speakers retain their native volume control.", comment: "Software volume")
      alert.runModal(); return
    }
    let consent = NSAlert()
    consent.messageText = NSLocalizedString("Enable Software Volume?", comment: "Audio capture opt-in")
    consent.informativeText = NSLocalizedString("MonitorControl will process system audio for the selected output to lower its volume. This does not change the monitor's internal volume. Audio is not recorded or transmitted. macOS may request permission to capture system audio.", comment: "Audio capture opt-in details")
    consent.addButton(withTitle: NSLocalizedString("Enable", comment: "Enable software volume"))
    consent.addButton(withTitle: NSLocalizedString("Cancel", comment: "Cancel"))
    guard consent.runModal() == .alertFirstButtonReturn else { return }
    prefs.set(display.prefsId, forKey: "softwareAudioDisplayID")
    audio.selectOutput(uid: output.uid)
    audio.enable(); app.updateMenusAndKeys()
  }
  func stop() { releaseVolumeTap(); timer?.invalidate(); audio.shutdown() }
}
