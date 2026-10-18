// SystemTapCapture.swift — one aggregate, one clock: device-scoped tap + physical
// output in a single private aggregate device, driven by a single IOProc.

import AudioToolbox
import CoreAudio
import Foundation
import os.log

private struct TapFormatDescription {
    let channelCount: UInt32
    let sampleRate: Double
    let isInterleaved: Bool
    let isFloat: Bool
}

/// Receives the aggregate's input (the tap) and output (the physical device) in the
/// SAME callback and must write the output buffers before returning.
protocol UnifiedRenderTarget: AnyObject {
    func handleUnifiedRender(
        inputData: UnsafePointer<AudioBufferList>,
        outputData: UnsafeMutablePointer<AudioBufferList>,
        tapStreamCount: Int
    )
}

/// Owns the Core Audio lifecycle: process tap → private aggregate → IOProc.
///
/// The design is deliberately single-clock. A device-scoped muted tap and the
/// physical output live in ONE aggregate device whose clock master is the physical
/// output, with maximum-quality drift compensation on the tap. One IOProc hands the
/// tap's input buffers to the render target, which writes processed audio into the
/// aggregate's output buffers inside the same callback.
///
/// There is no inter-clock ring buffer, no fill servo, and no second output client.
/// Running the tap and the output on two clocks (a capture aggregate feeding a ring
/// drained by a separate AUHAL unit) is what makes Bluetooth audio warble in pitch:
/// the device-side clock estimate wobbles, and every reconciliation mechanism between
/// two domains prints that wobble into the audio. See docs/how-it-works.md.
@available(macOS 15.0, *)
final class SystemTapCapture {
    private let logger: Logger

    nonisolated(unsafe) private var tapID: AudioObjectID = AudioObjectID(kAudioObjectUnknown)
    nonisolated(unsafe) private var aggregateDeviceID: AudioObjectID = AudioObjectID(kAudioObjectUnknown)
    nonisolated(unsafe) private var aggregateIOProcID: AudioDeviceIOProcID?
    nonisolated(unsafe) private var aggregateIOBlock: AudioDeviceIOBlock?
    nonisolated(unsafe) private var tapChannelCount: Int = 2
    // How many trailing buffers of the aggregate's input ABL belong to the tap.
    // A duplex output device (USB interface with mic/line inputs) contributes its
    // own input streams AHEAD of the tap's; 0 = unknown, render falls back to buffer 0.
    nonisolated(unsafe) private var tapInputStreamCount: Int = 0
    nonisolated(unsafe) private var isCapturing = false

    init(logger: Logger) {
        self.logger = logger
    }

    /// Build the tap and the aggregate, attach the IOProc, and start the device.
    ///
    /// Blocking: creating the tap, creating the aggregate, waiting for it to come
    /// alive (up to 3 s), and `AudioDeviceCreateIOProcIDWithBlock` are all mach round
    /// trips to `coreaudiod`. Call this off the main thread. The call ORDER matters
    /// and is the non-obvious part; see the numbered comments.
    nonisolated func start(
        outputDeviceID: AudioObjectID,
        renderTarget: UnifiedRenderTarget
    ) throws {

        stop()

        let outputUID = try SystemAudioDeviceLookup.uid(for: outputDeviceID)
        let excludedProcesses = translateCurrentProcessForTapExclusion()

        // 1. A DEVICE-SCOPED tap bound to the output device's stream, so the tap's
        //    format matches that stream and there is no global-mixdown format mismatch.
        //    Muted, so the tapped audio plays only through our output, not twice.
        //    Our own process is excluded, or we would capture and re-emit ourselves.
        let tapUUID = UUID()
        let tapDescription = CATapDescription(
            excludingProcesses: excludedProcesses,
            deviceUID: outputUID,
            stream: 0
        )
        tapDescription.uuid = tapUUID
        tapDescription.muteBehavior = .muted
        tapDescription.name = TapKitIdentity.tapName

        tapID = AudioObjectID(kAudioObjectUnknown)
        try checkCoreAudioStatus(
            AudioHardwareCreateProcessTap(tapDescription, &tapID),
            operation: "AudioHardwareCreateProcessTap"
        )
        let tapFormat = queryTapFormat(tapID)
        tapChannelCount = max(1, Int(tapFormat?.channelCount ?? 2))

        // 2. ONE private aggregate containing BOTH the tap and the physical output.
        //    The physical output is the main sub-device, which makes it the clock
        //    master. The tap is drift-compensated at maximum quality against that
        //    clock, inside Core Audio, on the very clock the audio plays on.
        let aggregateUID = "\(TapKitIdentity.aggregateDeviceUIDPrefix).\(UUID().uuidString)"
        let aggregateDescription: [String: Any] = [
            kAudioAggregateDeviceNameKey: TapKitIdentity.aggregateDeviceName,
            kAudioAggregateDeviceUIDKey: aggregateUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceMainSubDeviceKey: outputUID,
            kAudioAggregateDeviceSubDeviceListKey: [
                [kAudioSubDeviceUIDKey: outputUID]
            ],
            kAudioAggregateDeviceTapListKey: [
                [
                    kAudioSubTapDriftCompensationKey: true,
                    kAudioSubTapDriftCompensationQualityKey:
                        kAudioAggregateDriftCompensationMaxQuality,
                    kAudioSubTapUIDKey: tapUUID.uuidString,
                ]
            ],
        ]

        aggregateDeviceID = AudioObjectID(kAudioObjectUnknown)
        try checkCoreAudioStatus(
            AudioHardwareCreateAggregateDevice(aggregateDescription as CFDictionary, &aggregateDeviceID),
            operation: "AudioHardwareCreateAggregateDevice"
        )

        // 3. Wait for the aggregate to report alive. Start the IOProc before this and
        //    you get an endless stream of silent buffers with no error.
        waitForAggregateDeviceToBecomeAlive(aggregateDeviceID)

        // 4. Work out which input buffers are the tap's. A duplex output device
        //    donates its own input streams to the aggregate ahead of the tap's; on a
        //    MOTU M4 the first input buffers are the hardware preamps, not the tapped
        //    system audio. The tap's streams are the trailing ones.
        let deviceInputStreams = SystemAudioDeviceLookup.inputStreamCount(for: outputDeviceID)
        let aggregateInputStreams = SystemAudioDeviceLookup.inputStreamCount(for: aggregateDeviceID)
        tapInputStreamCount = max(0, aggregateInputStreams - deviceInputStreams)
        logger.info("Aggregate input streams: total=\(aggregateInputStreams) device=\(deviceInputStreams) tap=\(self.tapInputStreamCount)")

        // 5. ONE IOProc. Input (tap) and output (physical device) arrive together.
        //    The render target writes the output buffers in this same call.
        var procID: AudioDeviceIOProcID?
        let ioBlock: AudioDeviceIOBlock = { [weak self, weak renderTarget] _, inputData, _, outputData, _ in
            guard let self, self.isCapturing, let renderTarget else {
                zeroFillAudioBuffers(outputData)
                return
            }
            renderTarget.handleUnifiedRender(
                inputData: inputData,
                outputData: outputData,
                tapStreamCount: self.tapInputStreamCount
            )
        }
        aggregateIOBlock = ioBlock

        try checkCoreAudioStatus(
            AudioDeviceCreateIOProcIDWithBlock(&procID, aggregateDeviceID, nil, ioBlock),
            operation: "AudioDeviceCreateIOProcIDWithBlock"
        )
        aggregateIOProcID = procID

        if let procID {
            disableDeviceInputStreams(
                procID: procID,
                deviceInputStreams: deviceInputStreams,
                tapStreams: tapInputStreamCount
            )
        }

        isCapturing = true
        try checkCoreAudioStatus(
            AudioDeviceStart(aggregateDeviceID, procID),
            operation: "AudioDeviceStart(aggregate)"
        )

        logStart(outputUID: outputUID, tapUUID: tapUUID, tapFormat: tapFormat)
    }

    /// Teardown order matters: flag off first, then stop → destroy IOProc → destroy
    /// aggregate → destroy tap. `AudioDeviceStop` blocks until the device's IO thread
    /// leaves the running state, so this too belongs off the main thread.
    nonisolated func stop() {
        isCapturing = false

        if let procID = aggregateIOProcID {
            AudioDeviceStop(aggregateDeviceID, procID)
            AudioDeviceDestroyIOProcID(aggregateDeviceID, procID)
            aggregateIOProcID = nil
        }
        aggregateIOBlock = nil

        if aggregateDeviceID != AudioObjectID(kAudioObjectUnknown) {
            AudioHardwareDestroyAggregateDevice(aggregateDeviceID)
            aggregateDeviceID = AudioObjectID(kAudioObjectUnknown)
        }

        if tapID != AudioObjectID(kAudioObjectUnknown) {
            AudioHardwareDestroyProcessTap(tapID)
            tapID = AudioObjectID(kAudioObjectUnknown)
        }
        tapChannelCount = 2
        tapInputStreamCount = 0
    }

    /// Turn off the physical device's own input streams in our IOProc so the
    /// aggregate stops pulling unused hardware inputs (mic/line preamps) every
    /// cycle. The tap's streams are the trailing ones; leave only those enabled.
    /// Best-effort: the render path's trailing-buffer indexing is the actual fix
    /// and stays correct whether or not this takes effect.
    nonisolated private func disableDeviceInputStreams(
        procID: AudioDeviceIOProcID,
        deviceInputStreams: Int,
        tapStreams: Int
    ) {
        guard deviceInputStreams > 0, tapStreams > 0 else { return }

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyIOProcStreamUsage,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(aggregateDeviceID, &address, 0, nil, &dataSize) == noErr,
              dataSize >= UInt32(MemoryLayout<AudioHardwareIOProcStreamUsage>.size) else {
            logger.warning("IOProcStreamUsage size query failed; device input streams stay enabled")
            return
        }

        let raw = UnsafeMutableRawPointer.allocate(
            byteCount: Int(dataSize),
            alignment: MemoryLayout<AudioHardwareIOProcStreamUsage>.alignment
        )
        defer { raw.deallocate() }
        let usage = raw.assumingMemoryBound(to: AudioHardwareIOProcStreamUsage.self)
        usage.pointee.mIOProc = unsafeBitCast(procID, to: UnsafeMutableRawPointer.self)

        var readSize = dataSize
        guard AudioObjectGetPropertyData(aggregateDeviceID, &address, 0, nil, &readSize, usage) == noErr else {
            logger.warning("IOProcStreamUsage read failed; device input streams stay enabled")
            return
        }

        let streamCount = Int(usage.pointee.mNumberStreams)
        guard streamCount > tapStreams,
              let flagsOffset = MemoryLayout<AudioHardwareIOProcStreamUsage>.offset(of: \.mStreamIsOn),
              Int(readSize) >= flagsOffset + streamCount * MemoryLayout<UInt32>.size else {
            return
        }
        let flags = raw.advanced(by: flagsOffset).assumingMemoryBound(to: UInt32.self)
        for i in 0..<streamCount {
            flags[i] = i >= streamCount - tapStreams ? 1 : 0
        }

        let status = AudioObjectSetPropertyData(aggregateDeviceID, &address, 0, nil, readSize, usage)
        if status == noErr {
            logger.info("Disabled \(streamCount - tapStreams) device input stream(s) in IOProc; tap streams stay live")
        } else {
            logger.warning("IOProcStreamUsage write failed (\(status)); device input streams stay enabled")
        }
    }

    nonisolated private func translateCurrentProcessForTapExclusion() -> [AudioObjectID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyTranslatePIDToProcessObject,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var pid = ProcessInfo.processInfo.processIdentifier
        var processObjectID = AudioObjectID(kAudioObjectUnknown)
        var dataSize = UInt32(MemoryLayout<AudioObjectID>.size)

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            UInt32(MemoryLayout<pid_t>.size),
            &pid,
            &dataSize,
            &processObjectID
        )

        guard status == noErr, processObjectID != AudioObjectID(kAudioObjectUnknown) else {
            return []
        }

        return [processObjectID]
    }

    nonisolated private func queryTapFormat(_ tapID: AudioObjectID) -> TapFormatDescription? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioTapPropertyFormat,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var format = AudioStreamBasicDescription()
        var dataSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        let status = AudioObjectGetPropertyData(tapID, &address, 0, nil, &dataSize, &format)
        guard status == noErr else { return nil }
        return TapFormatDescription(
            channelCount: format.mChannelsPerFrame,
            sampleRate: format.mSampleRate,
            isInterleaved: (format.mFormatFlags & kAudioFormatFlagIsNonInterleaved) == 0,
            isFloat: (format.mFormatFlags & kAudioFormatFlagIsFloat) != 0
        )
    }

    /// Deliberately a blocking sleep on the calling thread: an async yield here would
    /// let a queued `stop()` interleave into a half-built aggregate.
    nonisolated private func waitForAggregateDeviceToBecomeAlive(_ deviceID: AudioObjectID) {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsAlive,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        for _ in 0..<30 {
            var isAlive: UInt32 = 0
            var dataSize = UInt32(MemoryLayout<UInt32>.size)
            let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, &isAlive)
            if status == noErr, isAlive != 0 {
                return
            }
            Thread.sleep(forTimeInterval: 0.1)
        }
    }

    nonisolated private func logStart(outputUID: String, tapUUID: UUID, tapFormat: TapFormatDescription?) {
        if let tapFormat {
            logger.info(
                "Started single-clock aggregate | outputUID=\(outputUID, privacy: .public) tapUUID=\(tapUUID.uuidString, privacy: .public) tapID=\(self.tapID) aggregateID=\(self.aggregateDeviceID) fmt=\(tapFormat.sampleRate)Hz/\(tapFormat.channelCount)ch interleaved=\(tapFormat.isInterleaved) float=\(tapFormat.isFloat)"
            )
        } else {
            logger.info(
                "Started single-clock aggregate | outputUID=\(outputUID, privacy: .public) tapUUID=\(tapUUID.uuidString, privacy: .public) tapID=\(self.tapID) aggregateID=\(self.aggregateDeviceID)"
            )
        }
    }
}
