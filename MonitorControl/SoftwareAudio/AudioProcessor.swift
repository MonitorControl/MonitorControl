// AudioProcessor.swift — the realtime hook consumers implement to modify audio.

import Foundation

/// Implement this to modify captured system audio before it reaches the output.
///
/// - `prepare(sampleRate:)` is called on `start`, OFF the realtime thread — do
///   sample-rate-dependent setup (allocate coefficients, etc.) here.
/// - `process(_:frameCount:channelCount:)` is called ON the realtime audio
///   thread for every output render. Mutate the interleaved buffer in place.
///   Do NOT allocate, lock, or block here — it runs under a hard deadline.
public protocol AudioProcessor: AnyObject {
    /// Called before capture starts and whenever the output sample rate changes.
    func prepare(sampleRate: Double)

    /// Interleaved samples: `L R L R …`, length `frameCount * channelCount`.
    /// `channelCount` is 2 in v1. Mutate in place.
    func process(_ samples: UnsafeMutablePointer<Float>, frameCount: Int, channelCount: Int)
}

public extension AudioProcessor {
    /// Optional: default no-op so simple processors can skip it.
    func prepare(sampleRate: Double) {}
}

/// Adapts a plain closure to `AudioProcessor` for the engine's closure init.
final class ClosureAudioProcessor: AudioProcessor {
    private let body: (UnsafeMutablePointer<Float>, Int, Int) -> Void

    init(_ body: @escaping (UnsafeMutablePointer<Float>, Int, Int) -> Void) {
        self.body = body
    }

    func process(_ samples: UnsafeMutablePointer<Float>, frameCount: Int, channelCount: Int) {
        body(samples, frameCount, channelCount)
    }
}
