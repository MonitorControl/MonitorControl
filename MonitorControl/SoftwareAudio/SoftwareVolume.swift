import AppKit
import CoreAudio
import Synchronization

@available(macOS 15.0, *)
final class VolumeGain: AudioProcessor {
    let gainBits = Atomic<UInt32>(Float(0.5).bitPattern)
    let renderedFrames = Atomic<UInt64>(0)
    let audibleFrames = Atomic<UInt64>(0)
    private var appliedGain: Float = 0.5
    private var lastTarget: Float = 0.5
    private var rampFrames = 720
    private var remainingFrames = 0
    func prepare(sampleRate: Double) {
        rampFrames = max(1, Int(sampleRate * 0.015))
        appliedGain = Float(bitPattern: gainBits.load(ordering: .relaxed))
        lastTarget = appliedGain
        remainingFrames = 0
    }
    func set(_ value: Float) { gainBits.store(value.bitPattern, ordering: .relaxed) }
    func process(_ samples: UnsafeMutablePointer<Float>, frameCount: Int, channelCount: Int) {
        let gain = Float(bitPattern: gainBits.load(ordering: .relaxed))
        if gain != lastTarget { lastTarget = gain; remainingFrames = rampFrames }
        var audible = false
        for frame in 0..<frameCount {
            if remainingFrames > 0 {
                appliedGain += (gain - appliedGain) / Float(remainingFrames)
                remainingFrames -= 1
            } else { appliedGain = gain }
            for channel in 0..<channelCount {
                let i = frame * channelCount + channel
                if abs(samples[i]) > 0.00001 { audible = true }
                samples[i] *= appliedGain
            }
        }
        renderedFrames.wrappingAdd(UInt64(frameCount), ordering: .relaxed)
        if audible { audibleFrames.wrappingAdd(UInt64(frameCount), ordering: .relaxed) }
    }
}

/// Monotonic watchdog: only demand progress while another client is playing.
struct AudioProgressWatchdog {
    private var frames: UInt64 = 0
    private var stalledSince: TimeInterval?
    private var healthySince: TimeInterval?
    mutating func reset(frames: UInt64) { self.frames = frames; stalledSince = nil; healthySince = nil }
    mutating func check(now: TimeInterval, frames: UInt64, sourceActive: Bool?) -> (stalled: Bool, stable: Bool) {
        if frames != self.frames {
            self.frames = frames; stalledSince = nil
            if healthySince == nil { healthySince = now }
            return (false, now - (healthySince ?? now) >= 30)
        }
        healthySince = nil
        guard sourceActive == true else { stalledSince = nil; return (false, false) }
        if stalledSince == nil { stalledSince = now }
        return (now - (stalledSince ?? now) >= 12, false)
    }
}

/// Coalesce duplicate multimedia notifications without suppressing key repeat.
struct VolumeMediaEventGate {
    private var last: [Int: TimeInterval] = [:]
    mutating func accepts(key: Int, phase: Int, repeatEvent: Bool, now: TimeInterval) -> Bool {
        guard [0, 1, 7].contains(key), phase == 0x0a else { return false }
        guard key != 7 || !repeatEvent else { return false }
        if let previous = last[key], now - previous < 0.020 { return false }
        last[key] = now
        return true
    }
}

@available(macOS 15.0, *)
final class SoftwareVolume {
    let gain = VolumeGain()
    lazy var engine = SystemAudioTapEngine(processor: gain)
    let queue = DispatchQueue(label: "app.monitorcontrol.softwareAudio")
    var onRouteChanged: (() -> Void)?
    private var outputListener: AudioObjectPropertyListenerBlock?
    static func shouldUseSoftwareVolume(running: Bool, currentUID: String?, targetUID: String?) -> Bool {
        running && currentUID != nil && targetUID != nil && currentUID == targetUID
    }
    var targetIsSelected: Bool {
        guard let current = try? AudioDevices.defaultOutput() else { return false }
        let target = wantedUID ?? preferences.string(forKey: "softwareAudioOutputUID")
        return target != nil && current.uid == target
    }
    var handlesVolumeKeys: Bool {
        let current = try? AudioDevices.defaultOutput()
        let target = wantedUID ?? preferences.string(forKey: "softwareAudioOutputUID")
        return requested && !suspended && Self.shouldUseSoftwareVolume(running: running, currentUID: current?.uid, targetUID: target)
    }
    func observeOutputChanges() {
        guard outputListener == nil else { return }
        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            guard let self = self else { return }
            self.onRouteChanged?()
            self.reconcile()
        }
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        if AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main, listener) == noErr { outputListener = listener }
    }
    var onStatus: ((String, Bool) -> Void)?
    private(set) var running = false
    private var wantedUID: String?
    private var wantedRate: Double = 0
    private var requested = false
    private var busy = false
    private var suspended = false
    private var generation = 0
    private var retryAfter = Date.distantPast
    private var recoveryAttempts = 0
    private var lastDeviceSignature = ""
    private var watchdog = AudioProgressWatchdog()
    private var sourceActive: Bool?
    private(set) var message = "Monitor software volume disabled"
    let preferences: UserDefaults
    private(set) var volume: Double
    private(set) var muted = false
    static func perceptualGain(_ level: Double) -> Float {
        guard level.isFinite else { return 0 }
        let value = min(1, max(0, level))
        return Float(value * value * value)
    }
    init(preferences: UserDefaults) {
        self.preferences = preferences
        let saved = preferences.object(forKey: "softwareVolume") as? Double ?? 0.2
        volume = saved.isFinite ? min(1, max(0, saved)) : 0.5
        if preferences.integer(forKey: "volumeCurveVersion") < 1 {
            // Preserve the previous acoustic level when migrating from linear gain.
            if preferences.object(forKey: "softwareVolume") != nil {
                volume = pow(volume, 1.0 / 3.0)
                preferences.set(volume, forKey: "softwareVolume")
            }
            preferences.set(1, forKey: "volumeCurveVersion")
            preferences.synchronize()
        }
        gain.set(Self.perceptualGain(volume))
    }
    private func publish(_ value: String) {
        guard message != value else { return }
        message = value
        onStatus?(value, running)
    }
    func setVolume(_ value: Double) {
        guard value.isFinite else { return }
        volume = min(1, max(0, value))
        muted = false
        gain.set(Self.perceptualGain(volume))
        preferences.set(volume, forKey: "softwareVolume")
        preferences.synchronize()
    }
    func toggleMute() { muted.toggle(); gain.set(muted ? 0 : Self.perceptualGain(volume)) }
    func selectOutput(uid: String) {
        wantedUID = uid
        preferences.set(uid, forKey: "softwareAudioOutputUID")
    }
    func enable() {
        requested = true
        suspended = false
        retryAfter = .distantPast
        recoveryAttempts = 0
        preferences.set(true, forKey: "softwareAudioEnabled")
        reconcile()
    }
    private func stopAsync(message: String) {
        generation += 1
        let token = generation
        running = false
        busy = true
        publish(message)
        queue.async {
            self.engine.stop()
            DispatchQueue.main.async {
                guard self.generation == token else { return }
                self.busy = false
            }
        }
    }
    func disable() {
        requested = false
        preferences.set(false, forKey: "softwareAudioEnabled")
        stopAsync(message: "Original audio restored")
    }
    func restoreEnabled() {
        if preferences.bool(forKey: "softwareAudioEnabled") { enable() }
    }
    func resume() { suspended = false; retryAfter = .distantPast; reconcile() }
    func reconcile() {
        guard requested, !busy, !suspended else { return }
        do {
            guard let device = try AudioDevices.defaultOutput() else {
                if running { stopAsync(message: "Waiting for the monitor audio output") }
                return
            }
            let signature = "\(device.id):\(device.uid):\(device.sampleRate)"
            if signature != lastDeviceSignature {
                lastDeviceSignature = signature
                retryAfter = .distantPast
                recoveryAttempts = 0
            }
            if wantedUID == nil { wantedUID = preferences.string(forKey: "softwareAudioOutputUID") ?? device.uid }
            guard device.uid == wantedUID else {
                if running { stopAsync(message: "Paused: another audio output is selected") }
                return
            }
            if running && abs(device.sampleRate - wantedRate) <= 1 {
                sourceActive = SystemAudioDeviceLookup.hasExternalOutputClient(deviceID: device.id)
                let progress = watchdog.check(now: ProcessInfo.processInfo.systemUptime, frames: gain.renderedFrames.load(ordering: .relaxed), sourceActive: sourceActive)
                if progress.stable { recoveryAttempts = 0 }
                if progress.stalled {
                    recoveryAttempts += 1
                    retryAfter = recoveryAttempts <= 3 ? Date().addingTimeInterval(Double(recoveryAttempts) * 3) : .distantFuture
                    stopAsync(message: recoveryAttempts <= 3 ? "Recovering audio connection…" : "Audio stopped: retry from the menu")
                } else {
                    publish(sourceActive == true ? "Processing monitor audio" : "Waiting for audio playback")
                }
                return
            }
            guard Date() >= retryAfter else { return }
            generation += 1
            let token = generation
            busy = true
            wantedRate = device.sampleRate
            publish("Starting monitor audio…")
            queue.async {
                do {
                    try self.engine.start(outputUID: device.uid)
                    DispatchQueue.main.async {
                        guard self.generation == token, self.requested, !self.suspended else { return }
                        self.running = true; self.busy = false
                        self.watchdog.reset(frames: self.gain.renderedFrames.load(ordering: .relaxed))
                        self.preferences.set(device.uid, forKey: "softwareAudioOutputUID")
                        self.publish("Waiting for audio playback")
                    }
                } catch {
                    DispatchQueue.main.async {
                        guard self.generation == token else { return }
                        self.running = false; self.busy = false
                        // Avoid repeatedly opening permission prompts; retry manually or on a device change.
                        self.retryAfter = .distantFuture
                        self.publish("Audio paused: \(error.localizedDescription)")
                    }
                }
            }
        } catch {
            if running { stopAsync(message: "Waiting for the audio output to return") }
            else { publish("Unable to query the audio output") }
        }
    }
    func stopForSleep() {
        generation += 1
        suspended = true
        running = false; busy = false
        queue.sync { engine.stop() }
        publish("Audio suspended")
    }
    func shutdown() {
        if let listener = outputListener {
            var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
            AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main, listener)
            outputListener = nil
        }
        generation += 1
        requested = false; suspended = true
        queue.sync { engine.stop() }
        running = false; busy = false
    }
}
