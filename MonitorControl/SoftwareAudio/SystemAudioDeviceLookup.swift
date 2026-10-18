// SystemAudioDeviceLookup.swift — resolve CoreAudio devices by UID.

import CoreAudio
import Foundation

@available(macOS 15.0, *)
enum SystemAudioDeviceLookup {
    /// Read only HAL activity; exclude our renderer so silence is not a failure.
    static func hasExternalOutputClient(deviceID: AudioObjectID) -> Bool? {
        func list(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> [AudioObjectID]? {
            var a = AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
            var size: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(object, &a, 0, nil, &size) == noErr else { return nil }
            if size == 0 { return [] }
            var values = [AudioObjectID](repeating: 0, count: Int(size) / 4)
            guard AudioObjectGetPropertyData(object, &a, 0, nil, &size, &values) == noErr else { return nil }
            return values
        }
        func scalar(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) -> UInt32? {
            var a = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
            var value: UInt32 = 0; var size: UInt32 = 4
            return AudioObjectGetPropertyData(object, &a, 0, nil, &size, &value) == noErr ? value : nil
        }
        guard let processes = list(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyProcessObjectList) else { return nil }
        var uncertain = false
        for process in processes {
            guard let pid = scalar(process, kAudioProcessPropertyPID), let active = scalar(process, kAudioProcessPropertyIsRunningOutput) else { uncertain = true; continue }
            if pid == UInt32(ProcessInfo.processInfo.processIdentifier) || active == 0 { continue }
            guard let devices = list(process, kAudioProcessPropertyDevices, scope: kAudioObjectPropertyScopeOutput) else { uncertain = true; continue }
            if devices.contains(deviceID) { return true }
        }
        return uncertain ? nil : false
    }

    static func resolveDeviceID(uid: String) throws -> AudioObjectID {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        try checkCoreAudioStatus(
            AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize),
            operation: "GetDeviceListSize"
        )

        let count = Int(dataSize) / MemoryLayout<AudioObjectID>.size
        var ids = Array(repeating: AudioObjectID(), count: count)
        try checkCoreAudioStatus(
            AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize, &ids),
            operation: "GetDeviceList"
        )

        for id in ids {
            var uidAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceUID,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var cfUID: CFString = "" as CFString
            var uidSize = UInt32(MemoryLayout<CFString>.size)
            let status = withUnsafeMutablePointer(to: &cfUID) { pointer in
                AudioObjectGetPropertyData(id, &uidAddress, 0, nil, &uidSize, pointer)
            }
            if status == noErr, (cfUID as String) == uid {
                return id
            }
        }

        throw CoreAudioTapError.missingDeviceUID
    }

    static func sampleRate(for deviceID: AudioObjectID) -> Double {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyNominalSampleRate,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var sampleRate: Float64 = 0
        var dataSize = UInt32(MemoryLayout<Float64>.size)
        return AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, &sampleRate) == noErr ? sampleRate : 0
    }

    /// Number of input-scope streams a device publishes (0 on failure or for
    /// output-only devices). Each stream contributes one buffer to an IOProc ABL.
    static func inputStreamCount(for deviceID: AudioObjectID) -> Int {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &dataSize) == noErr else {
            return 0
        }
        return Int(dataSize) / MemoryLayout<AudioStreamID>.size
    }

    static func uid(for deviceID: AudioObjectID) throws -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var uid: CFString = "" as CFString
        var dataSize = UInt32(MemoryLayout<CFString>.size)
        let status = withUnsafeMutablePointer(to: &uid) { pointer in
            AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, pointer)
        }
        try checkCoreAudioStatus(status, operation: "GetDeviceUID")
        return uid as String
    }
}
