// AudioOutputDevice.swift — a physical output device you can route audio to.

import CoreAudio
import Foundation

public struct AudioOutputDevice: Identifiable, Hashable, Sendable {
    public let id: AudioObjectID
    public let name: String
    public let uid: String
    public let sampleRate: Double

    public init(id: AudioObjectID, name: String, uid: String, sampleRate: Double) {
        self.id = id
        self.name = name
        self.uid = uid
        self.sampleRate = sampleRate
    }
}
