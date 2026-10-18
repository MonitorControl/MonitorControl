// AudioBufferListUtilities.swift — realtime-safe helpers for AudioBufferList.
//
// Everything here runs inside the aggregate IOProc. No allocation, no locks,
// no logging. Plain loops over Float pointers.

import AudioToolbox
import Foundation

nonisolated func zeroFillAudioBuffers(_ ioData: UnsafeMutablePointer<AudioBufferList>) {
    let buffers = UnsafeMutableAudioBufferListPointer(ioData)
    for buffer in buffers {
        guard let data = buffer.mData else { continue }
        memset(data, 0, Int(buffer.mDataByteSize))
    }
}

/// Smallest writable frame count across an output ABL's non-nil buffers.
nonisolated func writableFrameCapacity(_ buffers: UnsafeMutableAudioBufferListPointer) -> Int {
    var capacity = Int.max
    var found = false
    for buffer in buffers where buffer.mData != nil {
        let channels = max(1, Int(buffer.mNumberChannels))
        capacity = min(capacity, Int(buffer.mDataByteSize) / (MemoryLayout<Float>.size * channels))
        found = true
    }
    return found ? capacity : 0
}

/// First ABL buffer belonging to the tap.
///
/// A duplex interface (a USB interface with mic or line inputs) contributes its own
/// hardware-input streams to the aggregate AHEAD of the tap's, so the tap's buffers
/// are the TRAILING `tapStreamCount` entries. Counting from the end stays correct
/// whether or not disabled device streams appear in the ABL.
/// `tapStreamCount <= 0` means unknown; fall back to buffer 0 (output-only devices).
nonisolated func tapBufferStartIndex(bufferCount: Int, tapStreamCount: Int) -> Int {
    guard tapStreamCount > 0 else { return 0 }
    return max(0, bufferCount - tapStreamCount)
}

/// Normalize a tap input ABL (split mono pair, interleaved N-channel, or mono) into
/// interleaved stereo scratch, reading from `startingAtBuffer` onward (buffers before
/// it belong to the physical device's own inputs, not the tap).
/// Returns frames written (0 = no usable input).
nonisolated func normalizeToInterleavedStereo(
    _ inputData: UnsafePointer<AudioBufferList>,
    into scratch: UnsafeMutablePointer<Float>,
    maxFrames: Int,
    startingAtBuffer start: Int = 0
) -> Int {
    let inputBuffers = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: inputData))
    guard start >= 0, inputBuffers.count > start else { return 0 }

    if inputBuffers.count >= start + 2,
       inputBuffers[start].mNumberChannels == 1,
       inputBuffers[start + 1].mNumberChannels == 1,
       let left = inputBuffers[start].mData?.assumingMemoryBound(to: Float.self),
       let right = inputBuffers[start + 1].mData?.assumingMemoryBound(to: Float.self) {
        let frames = min(
            maxFrames,
            min(Int(inputBuffers[start].mDataByteSize), Int(inputBuffers[start + 1].mDataByteSize))
                / MemoryLayout<Float>.size
        )
        for i in 0..<frames {
            scratch[i * 2] = left[i]
            scratch[i * 2 + 1] = right[i]
        }
        return frames
    }

    guard let source = inputBuffers[start].mData?.assumingMemoryBound(to: Float.self) else { return 0 }
    let channels = max(1, Int(inputBuffers[start].mNumberChannels))
    let frames = min(
        maxFrames,
        Int(inputBuffers[start].mDataByteSize) / (MemoryLayout<Float>.size * channels)
    )
    if channels >= 2 {
        for i in 0..<frames {
            scratch[i * 2] = source[i * channels]
            scratch[i * 2 + 1] = source[i * channels + 1]
        }
    } else {
        for i in 0..<frames {
            scratch[i * 2] = source[i]
            scratch[i * 2 + 1] = source[i]
        }
    }
    return frames
}

/// Write interleaved stereo scratch into an output ABL (channel-stride aware for
/// interleaved destinations wider than stereo; split buffers get L/R).
nonisolated func writeInterleavedStereo(
    _ scratch: UnsafePointer<Float>,
    frameCount: Int,
    to buffers: UnsafeMutableAudioBufferListPointer
) {
    if !buffers.isEmpty,
       buffers[0].mNumberChannels >= 2,
       let destination = buffers[0].mData?.assumingMemoryBound(to: Float.self) {
        let channels = Int(buffers[0].mNumberChannels)
        for frame in 0..<frameCount {
            destination[frame * channels] = scratch[frame * 2]
            destination[frame * channels + 1] = scratch[frame * 2 + 1]
        }
        return
    }
    for channel in 0..<min(2, buffers.count) {
        guard let destination = buffers[channel].mData?.assumingMemoryBound(to: Float.self) else {
            continue
        }
        for frame in 0..<frameCount {
            destination[frame] = scratch[frame * 2 + channel]
        }
    }
}
