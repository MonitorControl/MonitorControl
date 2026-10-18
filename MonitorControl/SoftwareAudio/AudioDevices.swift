// AudioDevices.swift — enumerate output devices via the CoreAudio HAL.

import CoreAudio
import Foundation

public enum AudioDevices {

    /// All devices that expose at least one output stream.
    public static func outputs() throws -> [AudioOutputDevice] {
        try deviceIDs().compactMap { deviceID in
            guard try deviceHasOutput(deviceID) else { return nil }
            let name = try readString(on: deviceID, selector: kAudioObjectPropertyName)
            let uid = try readString(on: deviceID, selector: kAudioDevicePropertyDeviceUID)
            return AudioOutputDevice(id: deviceID, name: name, uid: uid,
                                     sampleRate: readNominalSampleRate(deviceID))
        }
    }

    /// The current system default output device, if resolvable.
    public static func defaultOutput() throws -> AudioOutputDevice? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID = AudioObjectID(0)
        var dataSize = UInt32(MemoryLayout<AudioObjectID>.size)
        try check(AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize, &deviceID
        ))
        guard deviceID != AudioObjectID(kAudioObjectUnknown) else { return nil }
        let name = try readString(on: deviceID, selector: kAudioObjectPropertyName)
        let uid = try readString(on: deviceID, selector: kAudioDevicePropertyDeviceUID)
        return AudioOutputDevice(id: deviceID, name: name, uid: uid,
                                 sampleRate: readNominalSampleRate(deviceID))
    }

    // MARK: - Private plumbing

    private static func deviceIDs() throws -> [AudioObjectID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        try check(AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize
        ))
        let count = Int(dataSize) / MemoryLayout<AudioObjectID>.size
        var ids = Array(repeating: AudioObjectID(), count: count)
        try check(AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize, &ids
        ))
        return ids
    }

    private static func deviceHasOutput(_ deviceID: AudioObjectID) throws -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        try check(AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &dataSize))
        let bufferList = UnsafeMutableRawPointer.allocate(
            byteCount: Int(dataSize),
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { bufferList.deallocate() }
        try check(AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, bufferList))
        let audioBufferList = bufferList.bindMemory(to: AudioBufferList.self, capacity: 1)
        let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
        return buffers.contains(where: { $0.mNumberChannels > 0 })
    }

    private static func readNominalSampleRate(_ deviceID: AudioObjectID) -> Double {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyNominalSampleRate,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var sampleRate: Float64 = 48_000
        var size = UInt32(MemoryLayout<Float64>.size)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &sampleRate)
        return status == noErr && sampleRate > 0 ? sampleRate : 48_000
    }

    private static func readString(on objectID: AudioObjectID,
                                   selector: AudioObjectPropertySelector) throws -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var cfString: CFString = "" as CFString
        var dataSize = UInt32(MemoryLayout<CFString>.size)
        let status = withUnsafeMutablePointer(to: &cfString) { pointer in
            AudioObjectGetPropertyData(objectID, &address, 0, nil, &dataSize, pointer)
        }
        try check(status)
        return cfString as String
    }

    private static func check(_ status: OSStatus) throws {
        guard status == noErr else {
            throw CoreAudioTapError.osStatus(status, "AudioObjectGetPropertyData")
        }
    }
}
