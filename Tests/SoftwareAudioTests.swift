import AppKit
@available(macOS 15.0, *)
@main struct SoftwareAudioTests {
 static func main() {
  precondition(abs(SoftwareVolume.perceptualGain(0.5) - 0.125) < 0.00001)
  precondition(SoftwareVolume.perceptualGain(-1) == 0)
  precondition(SoftwareVolume.perceptualGain(2) == 1)
  precondition(SoftwareVolume.perceptualGain(.nan) == 0)
  let gain = VolumeGain(); gain.set(1); gain.prepare(sampleRate: 1000); gain.set(0)
  var samples = [Float](repeating: 1, count: 40)
  samples.withUnsafeMutableBufferPointer { gain.process($0.baseAddress!, frameCount: 20, channelCount: 2) }
  for frame in 0..<20 { precondition(samples[frame*2] == samples[frame*2+1]); if frame > 0 { precondition(samples[frame*2] <= samples[(frame-1)*2]) } }
  precondition(samples.last == 0)
  precondition(!SoftwareVolume.shouldUseSoftwareVolume(running: true, currentUID: "Mac", targetUID: "Monitor"))
  precondition(SoftwareVolume.shouldUseSoftwareVolume(running: true, currentUID: "Monitor", targetUID: "Monitor"))
  var gate = VolumeMediaEventGate()
  precondition(gate.accepts(key: 7, phase: 10, repeatEvent: false, now: 1))
  precondition(!gate.accepts(key: 7, phase: 10, repeatEvent: false, now: 1.003))
  precondition(!gate.accepts(key: 7, phase: 11, repeatEvent: false, now: 1.007))
  precondition(!gate.accepts(key: 7, phase: 10, repeatEvent: true, now: 1.1))
  precondition(gate.accepts(key: 7, phase: 10, repeatEvent: false, now: 2))
  precondition(gate.accepts(key: 0, phase: 10, repeatEvent: false, now: 3))
  precondition(!gate.accepts(key: 0, phase: 10, repeatEvent: false, now: 3.003))
  precondition(gate.accepts(key: 0, phase: 10, repeatEvent: true, now: 3.05))
  precondition(gate.accepts(key: 1, phase: 10, repeatEvent: false, now: 3.051))
  var watchdog = AudioProgressWatchdog()
  watchdog.reset(frames: 0)
  for t in 0...120 { precondition(!watchdog.check(now: Double(t), frames: 0, sourceActive: false).stalled) }
  precondition(!watchdog.check(now: 121, frames: 0, sourceActive: true).stalled)
  precondition(watchdog.check(now: 133, frames: 0, sourceActive: true).stalled)
  precondition(!watchdog.check(now: 134, frames: 0, sourceActive: nil).stalled)
  for t in 135...166 { let state = watchdog.check(now: Double(t), frames: UInt64(t), sourceActive: true); precondition(!state.stalled); if t == 166 { precondition(state.stable) } }
  print("OK: watchdog idle, active stall, stable recovery; gain, stereo ramp, mute, multimedia event deduplication and output routing")
 }
}
