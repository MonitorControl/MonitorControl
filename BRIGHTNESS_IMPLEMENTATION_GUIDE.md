# MonitorControl Brightness Implementation Guide

## ⚠️ CRITICAL NOTICE FOR IMPLEMENTERS

**This document describes the PROVEN brightness control mechanism from MonitorControl that works reliably on BOTH Intel and Apple Silicon Macs.**

**DO NOT attempt to "improve" or substitute this mechanism with your own approach. This implementation has been battle-tested across thousands of users and multiple macOS versions. Follow these instructions EXACTLY.**

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Component Dependencies](#component-dependencies)
3. [Intel DDC Implementation (IntelDDC)](#intel-ddc-implementation)
4. [Apple Silicon DDC Implementation (Arm64DDC)](#apple-silicon-ddc-implementation)
5. [Display Base Class](#display-base-class)
6. [AppleDisplay Implementation](#appledisplay-implementation)
7. [OtherDisplay Implementation](#otherdisplay-implementation)
8. [DisplayManager and Shade System](#displaymanager-and-shade-system)
9. [Critical Implementation Details](#critical-implementation-details)
10. [Testing Checklist](#testing-checklist)

---

## Architecture Overview

### The Four-Layer Brightness Control System

```
┌─────────────────────────────────────────────────────────────┐
│  Layer 1: Entry Points (setBrightness)                      │
│  - Routes to smooth or direct based on user preference      │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  Layer 2: Smooth Transitions (setSmoothBrightness)          │
│  - 50Hz animation with adaptive stepping                    │
│  - Queues next frame via DispatchQueue.main.asyncAfter      │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  Layer 3: Direct Control (setDirectBrightness)              │
│  - AppleDisplay: DisplayServices API                        │
│  - OtherDisplay: DDC + Software combined mode               │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  Layer 4: Hardware/Software (setSwBrightness)               │
│  - Gamma Table Manipulation (CGSetDisplayTransferByTable)   │
│  - Window Shade Overlay (semi-transparent black window)     │
└─────────────────────────────────────────────────────────────┘
```

### Display Type Classification

```
Display Detection
    ├─ Built-in Display → AppleDisplay
    │   └─ Uses DisplayServicesSetBrightness API
    │
    ├─ External Apple Display → AppleDisplay
    │   └─ Detected via DisplayServicesGetBrightness success
    │
    └─ External Monitor → OtherDisplay
        ├─ Intel Mac → IntelDDC (IOI2CInterface)
        ├─ Apple Silicon → Arm64DDC (IOAVService)
        └─ Fallback → Software-only (gamma/shade)
```

---

## Component Dependencies

### Required Frameworks

```swift
import Foundation
import Cocoa
import CoreGraphics
import IOKit
import IOKit.i2c
import os.log
```

### Private API Declarations (Bridging Header)

```c
// DisplayServices (Apple displays)
extern int DisplayServicesGetBrightness(CGDirectDisplayID display, float *brightness);
extern int DisplayServicesSetBrightness(CGDirectDisplayID display, float brightness);

// CoreDisplay (display info)
extern CFDictionaryRef CoreDisplay_DisplayCreateInfoDictionary(CGDirectDisplayID display);

// CoreGraphics Private (Intel framebuffer)
extern void CGSServiceForDisplayNumber(CGDirectDisplayID display, io_service_t *service);

// CoreGraphics HDR (macOS 15+)
extern bool CGSIsHDRSupported(CGDirectDisplayID display);
extern bool CGSIsHDREnabled(CGDirectDisplayID display);

// IOAVService (Apple Silicon DDC)
typedef CFTypeRef IOAVService;
extern IOAVService IOAVServiceCreate(CFAllocatorRef allocator);
extern IOAVService IOAVServiceCreateWithService(CFAllocatorRef allocator, io_service_t service);
extern IOReturn IOAVServiceReadI2C(IOAVService service, uint32_t chipAddress, uint32_t offset, void* outputBuffer, uint32_t outputBufferSize);
extern IOReturn IOAVServiceWriteI2C(IOAVService service, uint32_t chipAddress, uint32_t dataAddress, void* inputBuffer, uint32_t inputBufferSize);
```

---

## Intel DDC Implementation

### Critical DDC/CI Protocol Details

#### I2C Addresses
- **Write Address**: `0x6E` (monitor DDC/CI address)
- **Read Address**: `0x6F` (monitor response address)
- **Reply Sub-Address**: `0x51` (expected response header)

#### VCP Command Codes
- **Brightness**: `0x10`
- **Contrast**: `0x12`
- **Volume**: `0x62`

### IntelDDC Class Structure

```swift
public class IntelDDC {
    let displayId: CGDirectDisplayID
    let framebuffer: io_service_t
    let replyTransactionType: IOOptionBits
    var enabled: Bool = false

    deinit {
        assert(IOObjectRelease(self.framebuffer) == KERN_SUCCESS)
    }

    public init?(for displayId: CGDirectDisplayID, withReplyTransactionType replyTransactionType: IOOptionBits? = nil)
    public func write(command: UInt8, value: UInt16, errorRecoveryWaitTime: UInt32? = nil, writeSleepTime: UInt32 = 10000, numofWriteCycles: UInt8 = 2) -> Bool
    public func read(command: UInt8, tries: UInt = 1, replyTransactionType _: IOOptionBits? = nil, minReplyDelay: UInt64? = nil, errorRecoveryWaitTime: UInt32? = nil, writeSleepTime: UInt32 = 10000) -> (UInt16, UInt16)?
}
```

### DDC Write Implementation

#### Packet Structure (7 bytes)
```swift
var data: [UInt8] = Array(repeating: 0, count: 7)
data[0] = 0x51           // Source address (host)
data[1] = 0x84           // Write command with length
data[2] = 0x03           // VCP opcode length
data[3] = command        // VCP command code (e.g., 0x10 for brightness)
data[4] = UInt8(value >> 8)   // Value high byte
data[5] = UInt8(value & 255)  // Value low byte
data[6] = 0x6E ^ data[0] ^ data[1] ^ data[2] ^ data[3] ^ data[4] ^ data[5]  // Checksum
```

#### Critical Timing Parameters
```swift
writeSleepTime: UInt32 = 10000      // 10ms delay before each write
numofWriteCycles: UInt8 = 2          // Write packet twice for reliability
errorRecoveryWaitTime: UInt32 = 2000 // 2ms recovery delay (use in OtherDisplay)
```

#### IOI2CRequest Configuration
```swift
var request = IOI2CRequest()
request.commFlags = 0
request.sendAddress = 0x6E
request.sendTransactionType = IOOptionBits(kIOI2CSimpleTransactionType)
request.sendBuffer = withUnsafePointer(to: &data[0]) { vm_address_t(bitPattern: $0) }
request.sendBytes = UInt32(data.count)
request.replyTransactionType = IOOptionBits(kIOI2CNoTransactionType)
request.replyBytes = 0
```

### DDC Read Implementation

#### Request Packet (5 bytes)
```swift
var data: [UInt8] = Array(repeating: 0, count: 5)
data[0] = 0x51           // Source address
data[1] = 0x82           // Read command with length
data[2] = 0x01           // VCP opcode length
data[3] = command        // VCP command code
data[4] = 0x6E ^ data[0] ^ data[1] ^ data[2] ^ data[3]  // Checksum
```

#### Expected Reply (11 bytes)
```swift
var replyData: [UInt8] = Array(repeating: 0, count: 11)
// After IOI2CSendRequest:
// replyData[6] = max value high byte
// replyData[7] = max value low byte
// replyData[8] = current value high byte
// replyData[9] = current value low byte
// replyData[10] = checksum

let maxValue = UInt16(replyData[6] << 8) + UInt16(replyData[7])
let currentValue = UInt16(replyData[8] << 8) + UInt16(replyData[9])
```

#### Checksum Validation
```swift
var calculated = UInt8(0x50)
for i in 0 ..< (replyData.count - 1) {
    calculated ^= replyData[i]
}
guard checksum == calculated else {
    // Checksum mismatch, retry
    continue
}
```

### Framebuffer Discovery

**CRITICAL**: Must obtain the correct framebuffer port for the display.

```swift
static func ioFramebufferPortFromDisplayId(displayId: CGDirectDisplayID) -> io_service_t? {
    // 1. Reject built-in displays
    if CGDisplayIsBuiltin(displayId) == boolean_t(truncating: true) {
        return nil
    }

    // 2. Fast path: Try private API
    var servicePortUsingCGSServiceForDisplayNumber: io_service_t = 0
    CGSServiceForDisplayNumber(displayId, &servicePortUsingCGSServiceForDisplayNumber)
    if servicePortUsingCGSServiceForDisplayNumber != 0 {
        return servicePortUsingCGSServiceForDisplayNumber
    }

    // 3. Fallback: Manual matching by properties
    guard let servicePort = self.servicePortUsingDisplayPropertiesMatching(from: displayId) else {
        return nil
    }

    // 4. Verify I2C interface exists
    var busCount: IOItemCount = 0
    guard IOFBGetI2CInterfaceCount(servicePort, &busCount) == KERN_SUCCESS, busCount >= 1 else {
        return nil
    }

    return servicePort
}
```

### Transaction Type Detection

```swift
static func supportedTransactionType() -> IOOptionBits? {
    var ioIterator = io_iterator_t()
    guard IOServiceGetMatchingServices(kIOMasterPortDefault,
          IOServiceNameMatching("IOFramebufferI2CInterface"), &ioIterator) == KERN_SUCCESS else {
        return nil
    }
    defer {
        assert(IOObjectRelease(ioIterator) == KERN_SUCCESS)
    }

    while case let ioService = IOIteratorNext(ioIterator), ioService != 0 {
        var serviceProperties: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(ioService, &serviceProperties, kCFAllocatorDefault, IOOptionBits()) == KERN_SUCCESS else {
            continue
        }
        let dict = serviceProperties!.takeRetainedValue() as NSDictionary
        if let types = dict[kIOI2CTransactionTypesKey] as? UInt64 {
            if (1 << kIOI2CDDCciReplyTransactionType) & types != 0 {
                return IOOptionBits(kIOI2CDDCciReplyTransactionType)
            }
            if (1 << kIOI2CSimpleTransactionType) & types != 0 {
                return IOOptionBits(kIOI2CSimpleTransactionType)
            }
        }
    }
    return nil
}
```

---

## Apple Silicon DDC Implementation

### IOAVService Discovery Process

**CRITICAL**: Apple Silicon uses a completely different API than Intel.

#### Constants
```swift
let ARM64_DDC_7BIT_ADDRESS: UInt8 = 0x37  // DisplayPort DDC address
let ARM64_DDC_DATA_ADDRESS: UInt8 = 0x51  // DDC data register
```

### Service Matching Algorithm

#### Step 1: IORegistry Traversal

```swift
static func getIoregServicesForMatching() -> [IOregService] {
    var serviceLocation = 0
    var ioregServicesForMatching: [IOregService] = []
    let ioregRoot: io_registry_entry_t = IORegistryGetRootEntry(kIOMasterPortDefault)

    var iterator = io_iterator_t()
    defer {
        IOObjectRelease(iterator)
    }

    var ioregService = IOregService()
    guard IORegistryEntryCreateIterator(ioregRoot, "IOService",
          IOOptionBits(kIORegistryIterateRecursively), &iterator) == KERN_SUCCESS else {
        return ioregServicesForMatching
    }

    let keyDCPAVServiceProxy = "DCPAVServiceProxy"
    let keysFramebuffer = ["AppleCLCD2", "IOMobileFramebufferShim"]

    while true {
        guard let objectOfInterest = ioregIterateToNextObjectOfInterest(
              interests: [keyDCPAVServiceProxy] + keysFramebuffer, iterator: &iterator) else {
            break
        }

        if keysFramebuffer.contains(objectOfInterest.name) {
            // Extract display properties (EDID, serial, etc.)
            ioregService = self.getIORegServiceAppleCDC2Properties(entry: objectOfInterest.entry)
            serviceLocation += 1
            ioregService.serviceLocation = serviceLocation
        } else if objectOfInterest.name == keyDCPAVServiceProxy {
            // Create IOAVService handle
            self.setIORegServiceDCPAVServiceProxy(entry: objectOfInterest.entry, ioregService: &ioregService)
            ioregServicesForMatching.append(ioregService)
        }
    }
    return ioregServicesForMatching
}
```

#### Step 2: Scored Matching

**CRITICAL**: Uses multi-factor scoring to match displays to services.

```swift
static func getServiceMatches(displayIDs: [CGDirectDisplayID]) -> [Arm64Service] {
    let ioregServicesForMatching = self.getIoregServicesForMatching()
    var matchedDisplayServices: [Arm64Service] = []
    var scoredCandidateDisplayServices: [Int: [Arm64Service]] = [:]

    // Generate scores for all combinations
    for displayID in displayIDs {
        for ioregServiceForMatching in ioregServicesForMatching {
            let score = self.ioregMatchScore(displayID: displayID,
                                            ioregEdidUUID: ioregServiceForMatching.edidUUID,
                                            ioDisplayLocation: ioregServiceForMatching.ioDisplayLocation,
                                            ioregProductName: ioregServiceForMatching.productName,
                                            ioregSerialNumber: ioregServiceForMatching.serialNumber,
                                            serviceLocation: ioregServiceForMatching.serviceLocation)

            let displayService = Arm64Service(displayID: displayID,
                                              service: ioregServiceForMatching.service,
                                              serviceLocation: ioregServiceForMatching.serviceLocation,
                                              discouraged: self.checkIfDiscouraged(ioregService: ioregServiceForMatching),
                                              dummy: self.checkIfDummy(ioregService: ioregServiceForMatching),
                                              serviceDetails: ioregServiceForMatching,
                                              matchScore: score)

            if scoredCandidateDisplayServices[score] == nil {
                scoredCandidateDisplayServices[score] = []
            }
            scoredCandidateDisplayServices[score]?.append(displayService)
        }
    }

    // Greedy assignment from highest to lowest score
    var takenServiceLocations: [Int] = []
    var takenDisplayIDs: [CGDirectDisplayID] = []
    for score in stride(from: self.MAX_MATCH_SCORE, to: 0, by: -1) {
        if let scoredCandidateDisplayService = scoredCandidateDisplayServices[score] {
            for candidateDisplayService in scoredCandidateDisplayService
                where !(takenDisplayIDs.contains(candidateDisplayService.displayID) ||
                        takenServiceLocations.contains(candidateDisplayService.serviceLocation)) {
                takenDisplayIDs.append(candidateDisplayService.displayID)
                takenServiceLocations.append(candidateDisplayService.serviceLocation)
                matchedDisplayServices.append(candidateDisplayService)
            }
        }
    }
    return matchedDisplayServices
}
```

#### Scoring Function

```swift
static func ioregMatchScore(displayID: CGDirectDisplayID,
                           ioregEdidUUID: String,
                           ioDisplayLocation: String = "",
                           ioregProductName: String = "",
                           ioregSerialNumber: Int64 = 0,
                           serviceLocation _: Int = 0) -> Int {
    var matchScore = 0

    if let dictionary = CoreDisplay_DisplayCreateInfoDictionary(displayID)?.takeRetainedValue() as NSDictionary? {
        // EDID matching (+4 max)
        if let kDisplayYearOfManufacture = dictionary[kDisplayYearOfManufacture] as? Int64,
           let kDisplayWeekOfManufacture = dictionary[kDisplayWeekOfManufacture] as? Int64,
           let kDisplayVendorID = dictionary[kDisplayVendorID] as? Int64,
           let kDisplayProductID = dictionary[kDisplayProductID] as? Int64,
           let kDisplayVerticalImageSize = dictionary[kDisplayVerticalImageSize] as? Int64,
           let kDisplayHorizontalImageSize = dictionary[kDisplayHorizontalImageSize] as? Int64 {

            // Match vendor ID, product ID, manufacture date, image size
            // Each match adds +1, up to +4 total
        }

        // Location match (+10) - STRONGEST INDICATOR
        if ioDisplayLocation != "",
           let kIODisplayLocation = dictionary[kIODisplayLocationKey] as? String,
           ioDisplayLocation == kIODisplayLocation {
            matchScore += 10
        }

        // Product name match (+1)
        if ioregProductName != "",
           let nameList = dictionary["DisplayProductName"] as? [String: String],
           let name = nameList["en_US"] ?? nameList.first?.value,
           name.lowercased() == ioregProductName.lowercased() {
            matchScore += 1
        }

        // Serial number match (+1)
        if ioregSerialNumber != 0,
           let serial = dictionary[kDisplaySerialNumber] as? Int64,
           serial == ioregSerialNumber {
            matchScore += 1
        }
    }
    return matchScore
}
```

### DDC Communication

#### Write Operation

```swift
static func write(service: IOAVService?,
                 command: UInt8,
                 value: UInt16,
                 writeSleepTime: UInt32? = nil,
                 numOfWriteCycles: UInt8? = nil,
                 numOfRetryAttemps: UInt8? = nil,
                 retrySleepTime: UInt32? = nil) -> Bool {
    var send: [UInt8] = [command, UInt8(value >> 8), UInt8(value & 255)]
    var reply: [UInt8] = []
    return Self.performDDCCommunication(service: service,
                                       send: &send,
                                       reply: &reply,
                                       writeSleepTime: writeSleepTime,
                                       numOfWriteCycles: numOfWriteCycles,
                                       numOfRetryAttemps: numOfRetryAttemps,
                                       retrySleepTime: retrySleepTime)
}
```

#### Packet Construction

```swift
static func performDDCCommunication(service: IOAVService?,
                                   send: inout [UInt8],
                                   reply: inout [UInt8],
                                   writeSleepTime: UInt32? = nil,
                                   numOfWriteCycles: UInt8? = nil,
                                   readSleepTime: UInt32? = nil,
                                   numOfRetryAttemps: UInt8? = nil,
                                   retrySleepTime: UInt32? = nil) -> Bool {
    let dataAddress = ARM64_DDC_DATA_ADDRESS
    var success = false
    guard service != nil else {
        return success
    }

    // Construct packet
    var packet: [UInt8] = [UInt8(0x80 | (send.count + 1)), UInt8(send.count)] + send + [0]

    // Calculate checksum
    packet[packet.count - 1] = self.checksum(
        chk: send.count == 1 ? ARM64_DDC_7BIT_ADDRESS << 1 : ARM64_DDC_7BIT_ADDRESS << 1 ^ dataAddress,
        data: &packet,
        start: 0,
        end: packet.count - 2)

    // Retry loop
    for _ in 1 ... (numOfRetryAttemps ?? 4) + 1 {
        // Write cycles
        for _ in 1 ... max((numOfWriteCycles ?? 2) + 0, 1) {
            usleep(writeSleepTime ?? 10000)
            success = IOAVServiceWriteI2C(service,
                                         UInt32(ARM64_DDC_7BIT_ADDRESS),
                                         UInt32(dataAddress),
                                         &packet,
                                         UInt32(packet.count)) == 0
        }

        // Read reply if expected
        if !reply.isEmpty {
            usleep(readSleepTime ?? 50000)
            if IOAVServiceReadI2C(service,
                                 UInt32(ARM64_DDC_7BIT_ADDRESS),
                                 0,
                                 &reply,
                                 UInt32(reply.count)) == 0 {
                success = self.checksum(chk: 0x50,
                                       data: &reply,
                                       start: 0,
                                       end: reply.count - 2) == reply[reply.count - 1]
            }
        }

        if success {
            return success
        }
        usleep(retrySleepTime ?? 20000)
    }
    return success
}
```

#### Checksum Function

```swift
static func checksum(chk: UInt8, data: inout [UInt8], start: Int, end: Int) -> UInt8 {
    var chkd: UInt8 = chk
    for i in start ... end {
        chkd ^= data[i]
    }
    return chkd
}
```

---

## Display Base Class

### Class Structure

```swift
class Display: Equatable {
    let identifier: CGDirectDisplayID
    let prefsId: String
    var name: String
    var vendorNumber: UInt32?
    var modelNumber: UInt32?
    var serialNumber: UInt32?

    // Smooth brightness state
    var smoothBrightnessTransient: Float = 1
    var smoothBrightnessRunning: Bool = false
    var smoothBrightnessSlow: Bool = false
    let swBrightnessSemaphore = DispatchSemaphore(value: 1)

    // Slider handlers
    var sliderHandler: [Command: SliderHandler] = [:]
    var brightnessSyncSourceValue: Float = 1

    // Display properties
    var isVirtual: Bool = false
    var isDummy: Bool = false

    // Gamma table storage
    var defaultGammaTableRed = [CGGammaValue](repeating: 0, count: 256)
    var defaultGammaTableGreen = [CGGammaValue](repeating: 0, count: 256)
    var defaultGammaTableBlue = [CGGammaValue](repeating: 0, count: 256)
    var defaultGammaTableSampleCount: UInt32 = 0
    var defaultGammaTablePeak: Float = 1
}
```

### Initialization

**CRITICAL**: Must capture default gamma tables at initialization.

```swift
init(_ identifier: CGDirectDisplayID,
     name: String,
     vendorNumber: UInt32?,
     modelNumber: UInt32?,
     serialNumber: UInt32?,
     isVirtual: Bool = false,
     isDummy: Bool = false) {
    self.identifier = identifier
    self.name = name
    self.vendorNumber = vendorNumber
    self.modelNumber = modelNumber
    self.serialNumber = serialNumber
    self.isVirtual = DEBUG_VIRTUAL ? true : isVirtual
    self.isDummy = isDummy

    // Generate unique preference ID
    self.prefsId = "(\(name.filter { !$0.isWhitespace })\(vendorNumber ?? 0)\(modelNumber ?? 0)@\(self.isVirtual ? (self.serialNumber ?? 9999) : identifier))"

    os_log("Display init with prefsIdentifier %{public}@", type: .info, self.prefsId)

    // CRITICAL: Capture default gamma tables
    self.swUpdateDefaultGammaTable()

    // Initialize brightness state
    self.smoothBrightnessTransient = self.getBrightness()

    // Setup shade or gamma based on preferences
    if self.isVirtual || self.readPrefAsBool(key: PrefKey.avoidGamma), !self.isDummy {
        os_log("Creating or updating shade for display %{public}@", type: .info, String(self.identifier))
        _ = DisplayManager.shared.updateShade(displayID: self.identifier)
    } else {
        os_log("Destroying shade (if exists) for display %{public}@", type: .info, String(self.identifier))
        _ = DisplayManager.shared.destroyShade(displayID: self.identifier)
    }

    self.brightnessSyncSourceValue = self.getBrightness()
}
```

### Smooth Brightness Implementation

**CRITICAL**: This creates the smooth animation effect.

```swift
func setSmoothBrightness(_ to: Float = -1, slow: Bool = false) -> Bool {
    // Safety checks
    guard app.sleepID == 0, app.reconfigureID == 0 else {
        self.savePref(self.smoothBrightnessTransient, for: .brightness)
        self.smoothBrightnessRunning = false
        return false
    }

    if slow {
        self.smoothBrightnessSlow = true
    }

    var stepDivider: Float = 6      // Normal speed
    if self.smoothBrightnessSlow {
        stepDivider = 16            // Slow speed
    }

    var dontPushAgain = false
    if to != -1 {
        // New target brightness
        let value = max(min(to, 1), 0)
        self.savePref(value, for: .brightness)
        self.brightnessSyncSourceValue = value
        self.smoothBrightnessSlow = slow
        if self.smoothBrightnessRunning {
            return true  // Already animating, will use new target
        }
    }

    let brightness = self.readPrefAsFloat(for: .brightness)
    if brightness != self.smoothBrightnessTransient {
        if abs(brightness - self.smoothBrightnessTransient) < 0.01 {
            // Close enough, snap to target
            self.smoothBrightnessTransient = brightness
            dontPushAgain = true
            self.smoothBrightnessRunning = false
        } else if brightness > self.smoothBrightnessTransient {
            // Moving up
            self.smoothBrightnessTransient += max((brightness - self.smoothBrightnessTransient) / stepDivider, 1 / 100)
        } else {
            // Moving down
            self.smoothBrightnessTransient += min((brightness - self.smoothBrightnessTransient) / stepDivider, 1 / 100)
        }

        // Apply current step
        _ = self.setDirectBrightness(self.smoothBrightnessTransient, transient: true)

        if !dontPushAgain {
            // Schedule next frame (50 FPS = 20ms)
            self.smoothBrightnessRunning = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                _ = self.setSmoothBrightness()
            }
        }
    } else {
        // Reached target
        _ = self.setDirectBrightness(self.smoothBrightnessTransient, transient: true)
        self.smoothBrightnessRunning = false
    }

    self.swBrightnessSemaphore.signal()
    return true
}
```

### Software Brightness via Gamma Tables

**CRITICAL**: This is the primary software dimming method.

```swift
func swUpdateDefaultGammaTable() {
    guard !self.isDummy else {
        return
    }
    CGGetDisplayTransferByTable(self.identifier,
                                256,
                                &self.defaultGammaTableRed,
                                &self.defaultGammaTableGreen,
                                &self.defaultGammaTableBlue,
                                &self.defaultGammaTableSampleCount)
    let redPeak = self.defaultGammaTableRed.max() ?? 0
    let greenPeak = self.defaultGammaTableGreen.max() ?? 0
    let bluePeak = self.defaultGammaTableBlue.max() ?? 0
    self.defaultGammaTablePeak = max(redPeak, greenPeak, bluePeak)
}

func swBrightnessTransform(value: Float, reverse: Bool = false) -> Float {
    let lowTreshold: Float = prefs.bool(forKey: PrefKey.allowZeroSwBrightness.rawValue) ? 0.0 : 0.15
    if !reverse {
        return value * (1 - lowTreshold) + lowTreshold
    } else {
        return (value - lowTreshold) / (1 - lowTreshold)
    }
}

func setSwBrightness(_ value: Float, smooth: Bool = false, noPrefSave: Bool = false) -> Bool {
    self.swBrightnessSemaphore.wait()
    let brightnessValue = min(1, value)
    var currentValue = self.readPrefAsFloat(key: .SwBrightness)
    if !noPrefSave {
        self.savePref(brightnessValue, key: .SwBrightness)
    }
    guard !self.isDummy else {
        self.swBrightnessSemaphore.signal()
        return true
    }

    var newValue = brightnessValue
    currentValue = self.swBrightnessTransform(value: currentValue)
    newValue = self.swBrightnessTransform(value: newValue)

    if smooth {
        // Smooth transition
        DispatchQueue.global(qos: .userInteractive).async {
            for transientValue in stride(from: currentValue, to: newValue, by: 0.005 * (currentValue > newValue ? -1 : 1)) {
                guard app.reconfigureID == 0 else {
                    self.swBrightnessSemaphore.signal()
                    return
                }
                if self.isVirtual || self.readPrefAsBool(key: .avoidGamma) {
                    _ = DisplayManager.shared.setShadeAlpha(value: 1 - transientValue, displayID: DisplayManager.resolveEffectiveDisplayID(self.identifier))
                } else {
                    let gammaTableRed = self.defaultGammaTableRed.map { $0 * transientValue }
                    let gammaTableGreen = self.defaultGammaTableGreen.map { $0 * transientValue }
                    let gammaTableBlue = self.defaultGammaTableBlue.map { $0 * transientValue }
                    CGSetDisplayTransferByTable(self.identifier, self.defaultGammaTableSampleCount, gammaTableRed, gammaTableGreen, gammaTableBlue)
                }
                Thread.sleep(forTimeInterval: 0.001)
            }
        }
    } else {
        // Instant change
        if self.isVirtual || self.readPrefAsBool(key: .avoidGamma) {
            self.swBrightnessSemaphore.signal()
            return DisplayManager.shared.setShadeAlpha(value: 1 - newValue, displayID: DisplayManager.resolveEffectiveDisplayID(self.identifier))
        } else {
            let gammaTableRed = self.defaultGammaTableRed.map { $0 * newValue }
            let gammaTableGreen = self.defaultGammaTableGreen.map { $0 * newValue }
            let gammaTableBlue = self.defaultGammaTableBlue.map { $0 * newValue }
            DisplayManager.shared.moveGammaActivityEnforcer(displayID: self.identifier)
            CGSetDisplayTransferByTable(self.identifier, self.defaultGammaTableSampleCount, gammaTableRed, gammaTableGreen, gammaTableBlue)
            DisplayManager.shared.enforceGammaActivity()
        }
    }

    self.swBrightnessSemaphore.signal()
    return true
}
```

### Gamma Interference Detection

**CRITICAL**: Detects conflicts with f.lux, Night Shift, etc.

```swift
func checkGammaInterference() {
    let currentSwBrightness = self.getSwBrightness()
    guard !self.isDummy,
          !DisplayManager.shared.gammaInterferenceWarningShown,
          !(prefs.bool(forKey: PrefKey.disableCombinedBrightness.rawValue)),
          !self.readPrefAsBool(key: .avoidGamma),
          !self.isVirtual,
          !self.smoothBrightnessRunning,
          self.prefExists(key: .SwBrightness),
          abs(currentSwBrightness - self.readPrefAsFloat(key: .SwBrightness)) > 0.02 else {
        return
    }

    DisplayManager.shared.gammaInterferenceCounter += 1
    _ = self.setSwBrightness(1)
    os_log("Gamma table interference detected, number of events: %{public}@", type: .info, String(DisplayManager.shared.gammaInterferenceCounter))

    if DisplayManager.shared.gammaInterferenceCounter >= 3 {
        DisplayManager.shared.gammaInterferenceWarningShown = true
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Is f.lux or similar running?", comment: "Shown in the alert dialog")
        alert.informativeText = NSLocalizedString("An other app seems to change the brightness or colors which causes issues.\n\nTo solve this, you need to quit the other app or disable gamma control for your displays in MonitorControl!", comment: "Shown in the alert dialog")
        alert.addButton(withTitle: NSLocalizedString("I'll quit the other app", comment: "Shown in the alert dialog"))
        alert.addButton(withTitle: NSLocalizedString("Disable gamma control for my displays", comment: "Shown in the alert dialog"))
        alert.alertStyle = NSAlert.Style.critical

        if alert.runModal() != .alertFirstButtonReturn {
            // Switch all displays to shade mode
            for otherDisplay in DisplayManager.shared.getOtherDisplays() {
                _ = otherDisplay.setSwBrightness(1)
                _ = otherDisplay.setDirectBrightness(1)
                otherDisplay.savePref(true, key: .avoidGamma)
                _ = otherDisplay.setSwBrightness(1)
                DisplayManager.shared.gammaInterferenceWarningShown = false
                DisplayManager.shared.gammaInterferenceCounter = 0
            }
        }
    }
}
```

---

## AppleDisplay Implementation

**CRITICAL**: Uses private DisplayServices API for built-in and Apple displays.

### Class Structure

```swift
class AppleDisplay: Display {
    private var displayQueue: DispatchQueue

    override init(_ identifier: CGDirectDisplayID,
                 name: String,
                 vendorNumber: UInt32?,
                 modelNumber: UInt32?,
                 serialNumber: UInt32?,
                 isVirtual: Bool = false,
                 isDummy: Bool = false) {
        self.displayQueue = DispatchQueue(label: String("displayQueue-\(identifier)"))
        super.init(identifier, name: name, vendorNumber: vendorNumber, modelNumber: modelNumber, serialNumber: serialNumber, isVirtual: isVirtual, isDummy: isDummy)
    }
}
```

### Brightness Control

```swift
public func getAppleBrightness() -> Float {
    guard !self.isDummy else {
        return 1
    }
    var brightness: Float = 0
    DisplayServicesGetBrightness(self.identifier, &brightness)
    return brightness
}

public func setAppleBrightness(value: Float) {
    guard !self.isDummy else {
        return
    }
    _ = self.displayQueue.sync {
        DisplayServicesSetBrightness(self.identifier, value)
    }
}

override func setDirectBrightness(_ to: Float, transient: Bool = false) -> Bool {
    guard !self.isDummy else {
        return false
    }
    let value = max(min(to, 1), 0)
    self.setAppleBrightness(value: value)
    if !transient {
        self.savePref(value, for: .brightness)
        self.brightnessSyncSourceValue = value
        self.smoothBrightnessTransient = value
    }
    return true
}
```

### Brightness Sync Mechanism

**CRITICAL**: Implements smooth slider updates for external brightness changes.

```swift
override func refreshBrightness() -> Float {
    guard !self.smoothBrightnessRunning else {
        return 0
    }

    let brightness = self.getAppleBrightness()
    let oldValue = self.brightnessSyncSourceValue
    self.savePref(brightness, for: .brightness)

    if brightness != oldValue {
        os_log("Pushing slider and reporting delta for Apple display %{public}@", type: .info, String(self.identifier))
        var newValue: Float

        if abs(brightness - oldValue) < 0.01 {
            newValue = brightness
        } else if brightness > oldValue {
            newValue = oldValue + max((brightness - oldValue) / 3, 0.005)
        } else {
            newValue = oldValue + min((brightness - oldValue) / 3, -0.005)
        }

        self.brightnessSyncSourceValue = newValue
        if let sliderHandler = self.sliderHandler[.brightness] {
            sliderHandler.setValue(newValue, displayID: self.identifier)
        }
        return newValue - oldValue
    }
    return 0
}
```

---

## OtherDisplay Implementation

### Class Structure

```swift
class OtherDisplay: Display {
    var ddc: IntelDDC?
    var arm64ddc: Bool = false
    var arm64avService: IOAVService?
    var isDiscouraged: Bool = false

    let writeDDCQueue = DispatchQueue(label: "Local write DDC queue")
    var writeDDCNextValue: [Command: UInt16] = [:]
    var writeDDCLastSavedValue: [Command: UInt16] = [:]

    var pollingCount: Int {
        get {
            switch self.readPrefAsInt(key: .pollingMode) {
            case PollingMode.none.rawValue: return 0
            case PollingMode.minimal.rawValue: return 1
            case PollingMode.normal.rawValue: return 5
            case PollingMode.heavy.rawValue: return 20
            case PollingMode.custom.rawValue: return prefs.integer(forKey: PrefKey.pollingCount.rawValue + self.prefsId)
            default: return PollingMode.none.rawValue
            }
        }
        set { prefs.set(newValue, forKey: PrefKey.pollingCount.rawValue + self.prefsId) }
    }
}
```

### Initialization

```swift
override init(_ identifier: CGDirectDisplayID,
             name: String,
             vendorNumber: UInt32?,
             modelNumber: UInt32?,
             serialNumber: UInt32?,
             isVirtual: Bool = false,
             isDummy: Bool = false) {
    super.init(identifier, name: name, vendorNumber: vendorNumber, modelNumber: modelNumber, serialNumber: serialNumber, isVirtual: isVirtual, isDummy: isDummy)

    // Initialize DDC for Intel Macs
    if !isVirtual, !Arm64DDC.isArm64 {
        self.ddc = IntelDDC(for: identifier)
    }
}
```

### Combined Brightness Mode

**CRITICAL**: Extends brightness range below hardware minimum.

```swift
func combinedBrightnessSwitchingValue() -> Float {
    Float(self.readPrefAsInt(key: .combinedBrightnessSwitchingPoint) + 8) / 16
}

override func setDirectBrightness(_ to: Float, transient: Bool = false) -> Bool {
    let value = max(min(to, 1), 0)

    if !self.isSw() {
        if !prefs.bool(forKey: PrefKey.disableCombinedBrightness.rawValue) {
            var brightnessValue: Float = 0
            var brightnessSwValue: Float = 1

            if value >= self.combinedBrightnessSwitchingValue() {
                // Upper range: use hardware DDC
                brightnessValue = (value - self.combinedBrightnessSwitchingValue()) *
                                 (1 / (1 - self.combinedBrightnessSwitchingValue()))
                brightnessSwValue = 1
            } else {
                // Lower range: use software gamma
                brightnessValue = 0
                brightnessSwValue = (value / self.combinedBrightnessSwitchingValue())
            }

            self.writeDDCValues(command: .brightness, value: self.convValueToDDC(for: .brightness, from: brightnessValue))
            if self.readPrefAsFloat(key: .SwBrightness) != brightnessSwValue {
                _ = self.setSwBrightness(brightnessSwValue)
            }
        } else {
            self.writeDDCValues(command: .brightness, value: self.convValueToDDC(for: .brightness, from: value))
        }

        if !transient {
            self.savePref(value, for: .brightness)
            self.smoothBrightnessTransient = value
        }
    } else {
        _ = super.setDirectBrightness(to, transient: transient)
    }
    return true
}
```

### DDC Write Queue System

**CRITICAL**: Ensures thread-safe DDC writes with deduplication.

```swift
public func writeDDCValues(command: Command, value: UInt16) {
    guard app.sleepID == 0,
          app.reconfigureID == 0,
          !self.readPrefAsBool(key: .forceSw),
          !self.readPrefAsBool(key: .unavailableDDC, for: command) else {
        return
    }

    self.writeDDCQueue.async(flags: .barrier) {
        self.writeDDCNextValue[command] = value
    }

    DisplayManager.shared.globalDDCQueue.async(flags: .barrier) {
        self.asyncPerformWriteDDCValues(command: command)
    }
}

func asyncPerformWriteDDCValues(command: Command) {
    var value = UInt16.max
    var lastValue = UInt16.max

    self.writeDDCQueue.sync {
        value = self.writeDDCNextValue[command] ?? UInt16.max
        lastValue = self.writeDDCLastSavedValue[command] ?? UInt16.max
    }

    guard value != UInt16.max, value != lastValue else {
        return
    }

    self.writeDDCQueue.async(flags: .barrier) {
        self.writeDDCLastSavedValue[command] = value
        self.savePref(true, key: PrefKey.isTouched, for: command)
    }

    var controlCodes = self.getRemapControlCodes(command: command)
    if controlCodes.count == 0 {
        controlCodes.append(command.rawValue)
    }

    for controlCode in controlCodes {
        if Arm64DDC.isArm64 {
            if self.arm64ddc {
                _ = Arm64DDC.write(service: self.arm64avService, command: controlCode, value: value)
            }
        } else {
            _ = self.ddc?.write(command: controlCode, value: value, errorRecoveryWaitTime: 2000) ?? false
        }
    }
}
```

### Value Conversion and Curves

```swift
func getCurveMultiplier(_ curveDDC: Int) -> Float {
    switch curveDDC {
    case 1: return 0.6
    case 2: return 0.7
    case 3: return 0.8
    case 4: return 0.9
    case 6: return 1.3
    case 7: return 1.5
    case 8: return 1.7
    case 9: return 1.88
    default: return 1.0
    }
}

func convValueToDDC(for command: Command, from: Float) -> UInt16 {
    var value = from
    if self.readPrefAsBool(key: .invertDDC, for: command) {
        value = 1 - value
    }
    let curveMultiplier = self.getCurveMultiplier(self.readPrefAsInt(key: .curveDDC, for: command))
    let minDDCValue = Float(self.readPrefAsInt(key: .minDDCOverride, for: command))
    let maxDDCValue = Float(self.readPrefAsInt(key: .maxDDC, for: command))
    let curvedValue = pow(max(min(value, 1), 0), curveMultiplier)
    let deNormalizedValue = (maxDDCValue - minDDCValue) * curvedValue + minDDCValue
    var intDDCValue = UInt16(min(max(deNormalizedValue, minDDCValue), maxDDCValue))

    if from > 0, command == Command.audioSpeakerVolume {
        intDDCValue = max(1, intDDCValue)
    }
    return intDDCValue
}

func convDDCToValue(for command: Command, from: UInt16) -> Float {
    let curveMultiplier = self.getCurveMultiplier(self.readPrefAsInt(key: .curveDDC, for: command))
    let minDDCValue = Float(self.readPrefAsInt(key: .minDDCOverride, for: command))
    let maxDDCValue = Float(self.readPrefAsInt(key: .maxDDC, for: command))
    let normalizedValue = ((min(max(Float(from), minDDCValue), maxDDCValue) - minDDCValue) / (maxDDCValue - minDDCValue))
    let deCurvedValue = pow(normalizedValue, 1.0 / curveMultiplier)
    var value = deCurvedValue
    if self.readPrefAsBool(key: .invertDDC, for: command) {
        value = 1 - value
    }
    return max(min(value, 1), 0)
}
```

---

## DisplayManager and Shade System

### Shade Window Creation

**CRITICAL**: Window-based software brightness for virtual displays and gamma conflicts.

```swift
func createShadeOnDisplay(displayID: CGDirectDisplayID) -> NSWindow? {
    if let screen = DisplayManager.getByDisplayID(displayID: displayID) {
        let shade = NSWindow(contentRect: .init(origin: NSPoint(x: 0, y: 0), size: .init(width: 10, height: 1)),
                            styleMask: [],
                            backing: .buffered,
                            defer: false)
        shade.title = "Monitor Control Window Shade for Display " + String(displayID)
        shade.isMovableByWindowBackground = false
        shade.backgroundColor = .clear
        shade.ignoresMouseEvents = true
        shade.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        shade.orderFrontRegardless()
        shade.collectionBehavior = [.stationary, .canJoinAllSpaces, .ignoresCycle]
        shade.setFrame(screen.frame, display: true)
        shade.contentView?.wantsLayer = true
        shade.contentView?.alphaValue = 0.0
        shade.contentView?.layer?.backgroundColor = .black
        shade.contentView?.setNeedsDisplay(shade.frame)
        os_log("Window shade created for display %{public}@", type: .info, String(displayID))
        return shade
    }
    return nil
}

func setShadeAlpha(value: Float, displayID: CGDirectDisplayID) -> Bool {
    guard !self.isDisqualifiedFromShade(displayID) else {
        return false
    }
    if let shade = getShade(displayID: displayID) {
        shade.contentView?.alphaValue = CGFloat(value)
        return true
    }
    return false
}
```

### Gamma Activity Enforcer

**CRITICAL**: Prevents macOS from reverting gamma table changes.

```swift
let gammaActivityEnforcer = NSWindow(contentRect: .init(origin: NSPoint(x: 0, y: 0),
                                                        size: .init(width: DEBUG_GAMMA_ENFORCER ? 15 : 1,
                                                                   height: DEBUG_GAMMA_ENFORCER ? 15 : 1)),
                                    styleMask: [],
                                    backing: .buffered,
                                    defer: false)

func createGammaActivityEnforcer() {
    self.gammaActivityEnforcer.title = "Monitor Control Gamma Activity Enforcer"
    self.gammaActivityEnforcer.isMovableByWindowBackground = false
    self.gammaActivityEnforcer.backgroundColor = DEBUG_GAMMA_ENFORCER ? .red : .black
    self.gammaActivityEnforcer.alphaValue = 1 * (DEBUG_GAMMA_ENFORCER ? 0.5 : 0.01)
    self.gammaActivityEnforcer.ignoresMouseEvents = true
    self.gammaActivityEnforcer.level = .screenSaver
    self.gammaActivityEnforcer.orderFrontRegardless()
    self.gammaActivityEnforcer.collectionBehavior = [.stationary, .canJoinAllSpaces]
    os_log("Gamma activity enforcer created.", type: .info)
}

func enforceGammaActivity() {
    if self.gammaActivityEnforcer.alphaValue == 1 * (DEBUG_GAMMA_ENFORCER ? 0.5 : 0.01) {
        self.gammaActivityEnforcer.alphaValue = 2 * (DEBUG_GAMMA_ENFORCER ? 0.5 : 0.01)
    } else {
        self.gammaActivityEnforcer.alphaValue = 1 * (DEBUG_GAMMA_ENFORCER ? 0.5 : 0.01)
    }
}

func moveGammaActivityEnforcer(displayID: CGDirectDisplayID) {
    if let screen = DisplayManager.getByDisplayID(displayID: DisplayManager.resolveEffectiveDisplayID(displayID)) {
        self.gammaActivityEnforcer.setFrameOrigin(screen.frame.origin)
    }
    self.gammaActivityEnforcer.orderFrontRegardless()
}
```

### Display Discovery and Classification

```swift
func configureDisplays() {
    self.clearDisplays()
    var onlineDisplayIDs = [CGDirectDisplayID](repeating: 0, count: 16)
    var displayCount: UInt32 = 0
    guard CGGetOnlineDisplayList(16, &onlineDisplayIDs, &displayCount) == .success else {
        os_log("Unable to get display list.", type: .info)
        return
    }

    for onlineDisplayID in onlineDisplayIDs where onlineDisplayID != 0 {
        let name = DisplayManager.getDisplayNameByID(displayID: onlineDisplayID)
        let id = onlineDisplayID
        let vendorNumber = CGDisplayVendorNumber(onlineDisplayID)
        let modelNumber = CGDisplayModelNumber(onlineDisplayID)
        let serialNumber = CGDisplaySerialNumber(onlineDisplayID)
        let isDummy: Bool = DisplayManager.isDummy(displayID: onlineDisplayID)
        let isVirtual: Bool = DisplayManager.isVirtual(displayID: onlineDisplayID)

        if !DEBUG_SW, DisplayManager.isAppleDisplay(displayID: onlineDisplayID) {
            let appleDisplay = AppleDisplay(id, name: name, vendorNumber: vendorNumber, modelNumber: modelNumber, serialNumber: serialNumber, isVirtual: isVirtual, isDummy: isDummy)
            os_log("Apple display found - %{public}@", type: .info, "ID: \(appleDisplay.identifier), Name: \(appleDisplay.name) (Vendor: \(appleDisplay.vendorNumber ?? 0), Model: \(appleDisplay.modelNumber ?? 0))")
            self.addDisplay(display: appleDisplay)
        } else {
            let otherDisplay = OtherDisplay(id, name: name, vendorNumber: vendorNumber, modelNumber: modelNumber, serialNumber: serialNumber, isVirtual: isVirtual, isDummy: isDummy)
            os_log("Other display found - %{public}@", type: .info, "ID: \(otherDisplay.identifier), Name: \(otherDisplay.name) (Vendor: \(otherDisplay.vendorNumber ?? 0), Model: \(otherDisplay.modelNumber ?? 0))")
            self.addDisplay(display: otherDisplay)
        }
    }
}

static func isAppleDisplay(displayID: CGDirectDisplayID) -> Bool {
    if #available(macOS 15.0, *) {
        if CGDisplayVendorNumber(displayID) != 1552, CGSIsHDRSupported(displayID), CGSIsHDREnabled(displayID) {
            return CGDisplayIsBuiltin(displayID) != 0
        }
    }
    var brightness: Float = -1
    let ret = DisplayServicesGetBrightness(displayID, &brightness)
    if ret == 0, brightness >= 0 {
        return true
    }
    return CGDisplayIsBuiltin(displayID) != 0
}
```

---

## Critical Implementation Details

### 1. Thread Safety Requirements

**Global DDC Queue:**
```swift
class DisplayManager {
    let globalDDCQueue = DispatchQueue(label: "Global DDC queue")
}
```

**Per-Display Queues:**
```swift
// AppleDisplay
private var displayQueue: DispatchQueue

// OtherDisplay
let writeDDCQueue = DispatchQueue(label: "Local write DDC queue")

// Display (base)
let swBrightnessSemaphore = DispatchSemaphore(value: 1)
```

### 2. Timing Parameters (DO NOT CHANGE)

```swift
// DDC write timing
writeSleepTime: 10000 µs (10ms)
numofWriteCycles: 2
errorRecoveryWaitTime: 2000 µs (2ms)

// DDC read timing
readSleepTime: 50000 µs (50ms)
numOfRetryAttemps: 4
retrySleepTime: 20000 µs (20ms)

// Smooth brightness
frameInterval: 20ms (50 FPS)
normalStepDivider: 6
slowStepDivider: 16
minimumStep: 0.01 (1%)
```

### 3. Preference Keys

**CRITICAL**: Must use per-display preference storage.

```swift
private func getKey(key: PrefKey? = nil, for command: Command? = nil) -> String {
    (key ?? PrefKey.value).rawValue +
    (command != nil ? String((command ?? Command.none).rawValue) : "") +
    self.prefsId
}
```

**PrefsId Format:**
```swift
"(\(name.filter { !$0.isWhitespace })\(vendorNumber ?? 0)\(modelNumber ?? 0)@\(self.isVirtual ? (self.serialNumber ?? 9999) : identifier))"
```

### 4. Error Handling

**DDC Communication Failures:**
- Retry with exponential backoff
- Mark command as unavailable after persistent failures
- Fall back to software mode

**Sleep/Reconfigure Protection:**
```swift
guard app.sleepID == 0, app.reconfigureID == 0 else {
    return
}
```

### 5. Apple Silicon Service Matching

**MUST run service matching on every display configuration change:**

```swift
func updateArm64AVServices() {
    if Arm64DDC.isArm64 {
        os_log("arm64 AVService update requested", type: .info)
        var displayIDs: [CGDirectDisplayID] = []
        for otherDisplay in self.getOtherDisplays() {
            displayIDs.append(otherDisplay.identifier)
        }
        for serviceMatch in Arm64DDC.getServiceMatches(displayIDs: displayIDs) {
            for otherDisplay in self.getOtherDisplays() where otherDisplay.identifier == serviceMatch.displayID && serviceMatch.service != nil {
                otherDisplay.arm64avService = serviceMatch.service
                os_log("Display service match successful for display %{public}@", type: .info, String(serviceMatch.displayID))
                if serviceMatch.discouraged {
                    os_log("Display %{public}@ is flagged as discouraged by Arm64DDC.", type: .info, String(serviceMatch.displayID))
                    otherDisplay.isDiscouraged = true
                } else if serviceMatch.dummy {
                    os_log("Display %{public}@ is flagged as dummy by Arm64DDC.", type: .info, String(serviceMatch.displayID))
                    otherDisplay.isDiscouraged = true
                    otherDisplay.isDummy = true
                } else {
                    otherDisplay.arm64ddc = DEBUG_SW ? false : true
                }
            }
        }
        os_log("AVService update done", type: .info)
    }
}
```

### 6. Gamma Table Manipulation Best Practices

**MUST capture default tables at initialization:**
```swift
CGGetDisplayTransferByTable(self.identifier, 256, &self.defaultGammaTableRed, &self.defaultGammaTableGreen, &self.defaultGammaTableBlue, &self.defaultGammaTableSampleCount)
```

**MUST use gamma enforcer to prevent resets:**
```swift
DisplayManager.shared.moveGammaActivityEnforcer(displayID: self.identifier)
CGSetDisplayTransferByTable(self.identifier, self.defaultGammaTableSampleCount, gammaTableRed, gammaTableGreen, gammaTableBlue)
DisplayManager.shared.enforceGammaActivity()
```

**MUST detect and handle interference:**
```swift
func checkGammaInterference() {
    let currentSwBrightness = self.getSwBrightness()
    guard abs(currentSwBrightness - self.readPrefAsFloat(key: .SwBrightness)) > 0.02 else {
        return
    }
    // Interference detected
}
```

---

## Testing Checklist

### Intel Mac Testing
- [ ] External monitor brightness control via DDC
- [ ] Smooth brightness transitions
- [ ] Software brightness (gamma tables)
- [ ] Combined brightness mode
- [ ] Multiple monitors
- [ ] Gamma interference detection
- [ ] Sleep/wake cycles
- [ ] Display hotplug

### Apple Silicon Testing
- [ ] External monitor brightness via IOAVService
- [ ] Service matching accuracy
- [ ] All Intel Mac test cases
- [ ] DisplayPort displays
- [ ] HDMI displays (may not work - acceptable)
- [ ] Thunderbolt displays
- [ ] USB-C displays

### Built-in Display Testing
- [ ] MacBook Pro brightness control
- [ ] MacBook Air brightness control
- [ ] iMac brightness control
- [ ] DisplayServices API reliability
- [ ] Brightness sync across displays
- [ ] Hardware keyboard brightness keys

### Software Brightness Testing
- [ ] Gamma table manipulation
- [ ] Shade window overlay
- [ ] Virtual displays (Sidecar, AirPlay)
- [ ] Dummy displays
- [ ] Mirrored displays
- [ ] Night Shift compatibility
- [ ] f.lux conflict detection

### Edge Cases
- [ ] Zero displays (headless mode)
- [ ] 16+ displays (array limit)
- [ ] Display reconfiguration during brightness change
- [ ] Rapid brightness changes (queue coalescing)
- [ ] System sleep during smooth transition
- [ ] App termination during DDC write
- [ ] Preference corruption recovery

---

## Final Notes

**This implementation is PROVEN and BATTLE-TESTED. DO NOT deviate from these specifications unless you have a specific bug to fix or hardware incompatibility to work around.**

**The MonitorControl project has hundreds of thousands of users across all Mac hardware. This implementation works reliably across:**
- Intel Macs (2012-2023)
- Apple Silicon Macs (M1, M2, M3, M4)
- macOS 10.15 Catalina through macOS 15 Sequoia
- Hundreds of different monitor models
- Complex multi-monitor setups

**If your implementation doesn't work, the problem is YOUR implementation, not this specification.**

Follow these instructions EXACTLY, and you will have reliable brightness control.
