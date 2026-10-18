// SystemAudioTapEngine.swift — the app-facing façade and the render target.

import AudioToolbox
import Synchronization
import CoreAudio
import Foundation
import os.log

private let logger = Logger(subsystem: tapKitLogSubsystem, category: "TapEngine")

/// Captures all system audio bound for one output device, runs it through your
/// `AudioProcessor`, and writes the result back to that device, all inside a single
/// Core Audio IOProc on a single clock.
///
/// The Core Audio lifecycle lives in `SystemTapCapture`. This type is the public
/// façade and the IOProc render target: it normalizes the tap's input buffers to
/// interleaved stereo scratch, calls the processor, and writes the output buffers.
@available(macOS 15.0, *)
public final class SystemAudioTapEngine {
    let renderCallbacks = Atomic<UInt64>(0)
    private static let scratchBufferFrameCapacity = 16_384

    private let processor: AudioProcessor
    private let tapCapture: SystemTapCapture

    nonisolated(unsafe) public private(set) var isRunning = false
    /// The output device's nominal sample rate for the current run.
    nonisolated(unsafe) public private(set) var sampleRate: Double = 48_000

    // Pre-allocated scratch for the realtime callback. Sized generously up front so
    // the IOProc never touches the heap.
    nonisolated(unsafe) private let scratchBuffer = UnsafeMutablePointer<Float>.allocate(
        capacity: SystemAudioTapEngine.scratchBufferFrameCapacity * 2
    )

    public init(processor: AudioProcessor) {
        self.processor = processor
        tapCapture = SystemTapCapture(logger: logger)
    }

    public convenience init(_ process: @escaping (UnsafeMutablePointer<Float>, Int, Int) -> Void) {
        self.init(processor: ClosureAudioProcessor(process))
    }

    deinit {
        // The IOProc writes into `scratchBuffer`; destroy it before freeing the buffer.
        tapCapture.stop()
        scratchBuffer.deallocate()
    }

    /// Start capturing and rendering on the device with this UID.
    ///
    /// Blocking for up to a few seconds (tap and aggregate creation are mach round
    /// trips; the aggregate is polled until alive). Call it off the main thread.
    /// `prepare(sampleRate:)` is called on your processor before any audio flows.
    public func start(outputUID: String) throws {
        guard !outputUID.isEmpty else { throw CoreAudioTapError.missingDeviceUID }

        stop()

        do {
            let outputID = try SystemAudioDeviceLookup.resolveDeviceID(uid: outputUID)
            let reported = SystemAudioDeviceLookup.sampleRate(for: outputID)
            sampleRate = reported > 0 ? reported : 48_000

            processor.prepare(sampleRate: sampleRate)
            logger.info("Output device \(outputID) sample rate: \(self.sampleRate)")

            isRunning = true
            try tapCapture.start(outputDeviceID: outputID, renderTarget: self)
        } catch {
            logger.error("Start failed: \(error.localizedDescription)")
            stop()
            throw error
        }
    }

    /// Stop and tear down the tap, the aggregate, and the IOProc. Blocking; the
    /// device's IO thread must leave the running state first.
    public func stop() {
        tapCapture.stop()
        isRunning = false
    }
}

@available(macOS 15.0, *)
extension SystemAudioTapEngine: UnifiedRenderTarget {
    /// Single-clock render: the tap's input and the physical output arrive in the SAME
    /// IOProc invocation. Normalize input to stereo scratch, run the processor, write
    /// straight to the output buffers. No ring, no clock bridging.
    ///
    /// `tapStreamCount` is how many TRAILING input buffers belong to the tap. A duplex
    /// interface's own hardware inputs come first in the ABL, and reading them instead
    /// of the tap renders preamp noise floor as "audio".
    nonisolated func handleUnifiedRender(
        inputData: UnsafePointer<AudioBufferList>,
        outputData: UnsafeMutablePointer<AudioBufferList>,
        tapStreamCount: Int
    ) {
        renderCallbacks.wrappingAdd(1, ordering: .relaxed)
        zeroFillAudioBuffers(outputData)

        let outputBuffers = UnsafeMutableAudioBufferListPointer(outputData)
        let outputCapacity = writableFrameCapacity(outputBuffers)
        guard outputCapacity > 0 else { return }

        let inputBufferCount = Int(inputData.pointee.mNumberBuffers)
        let tapStart = tapBufferStartIndex(bufferCount: inputBufferCount, tapStreamCount: tapStreamCount)

        let frameLimit = min(outputCapacity, Self.scratchBufferFrameCapacity)
        let frameCount = normalizeToInterleavedStereo(
            inputData, into: scratchBuffer, maxFrames: frameLimit, startingAtBuffer: tapStart
        )
        guard frameCount > 0 else { return }

        processor.process(scratchBuffer, frameCount: frameCount, channelCount: 2)
        writeInterleavedStereo(scratchBuffer, frameCount: frameCount, to: outputBuffers)
    }
}
