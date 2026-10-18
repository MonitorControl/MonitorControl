import Foundation

/// Logger subsystem for the whole package.
let tapKitLogSubsystem = "app.monitorcontrol.softwareAudio"

/// Names CoreAudioTapKit uses when creating its process tap and aggregate device.
/// Consumers who ship two tap-based apps side by side can fork these.
enum TapKitIdentity {
    static let tapName = "MonitorControl Audio"
    static let aggregateDeviceName = "MonitorControl Private Audio"
    static let aggregateDeviceUIDPrefix = "app.monitorcontrol.softwareAudio.tap"
}
