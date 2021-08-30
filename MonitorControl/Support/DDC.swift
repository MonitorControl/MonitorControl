// taken from: https://github.com/reitermarkus/DDC.swift

import Cocoa
import Foundation
import IOKit.i2c
import os.log

public class DDC {
  public enum Command: UInt8 {
    // Display Control
    case horizontalFrequency = 0xAC
    case verticalFrequency = 0xAE
    case sourceColorCoding = 0xB5
    case displayUsageTime = 0xC0
    case displayControllerId = 0xC8
    case displayFirmwareLevel = 0xC9
    case osdLanguage = 0xCC
    case powerMode = 0xD6
    case imageMode = 0xDB
    case vcpVersion = 0xDF

    // Geometry
    case horizontalPosition = 0x20
    case horizontalSize = 0x22
    case horizontalPincushion = 0x24
    case horizontalPincushionBalance = 0x26
    case horizontalConvergenceRB = 0x28
    case horizontalConvergenceMG = 0x29
    case horizontalLinearity = 0x2A
    case horizontalLinearityBalance = 0x2C
    case verticalPosition = 0x30
    case verticalSize = 0x32
    case verticalPincushion = 0x34
    case verticalPincushionBalance = 0x36
    case verticalConvergenceRB = 0x38
    case verticalConvergenceMG = 0x39
    case verticalLinearity = 0x3A
    case verticalLinearityBalance = 0x3C
    case horizontalParallelogram = 0x40
    case verticalParallelogram = 0x41
    case horizontalKeystone = 0x42
    case verticalKeystone = 0x43
    case rotation = 0x44
    case topCornerFlare = 0x46
    case topCornerHook = 0x48
    case bottomCornerFlare = 0x4A
    case bottomCornerHook = 0x4C
    case horizontalMirror = 0x82
    case verticalMirror = 0x84
    case displayScaling = 0x86
    case windowPositionTopLeftX = 0x95
    case windowPositionTopLeftY = 0x96
    case windowPositionBottomRightX = 0x97
    case windowPositionBottomRightY = 0x98
    case scanMode = 0xDA

    // Miscellaneous
    case degauss = 0x01
    case newControlValue = 0x02
    case softControls = 0x03
    case activeControl = 0x52
    case performancePreservation = 0x54
    case inputSelect = 0x60
    case ambientLightSensor = 0x66
    case remoteProcedureCall = 0x76
    case displayIdentificationOnDataOperation = 0x78
    case tvChannelUpDown = 0x8B
    case flatPanelSubPixelLayout = 0xB2
    case displayTechnologyType = 0xB6
    case displayDescriptorLength = 0xC2
    case transmitDisplayDescriptor = 0xC3
    case enableDisplayOfDisplayDescriptor = 0xC4
    case applicationEnableKey = 0xC6
    case displayEnableKey = 0xC7
    case statusIndicator = 0xCD
    case auxiliaryDisplaySize = 0xCE
    case auxiliaryDisplayData = 0xCF
    case outputSelect = 0xD0
    case assetTag = 0xD2
    case auxiliaryPowerOutput = 0xD7
    case scratchPad = 0xDE

    // Audio
    case audioSpeakerVolume = 0x62
    case speakerSelect = 0x63
    case audioMicrophoneVolume = 0x64
    case audioJackConnectionStatus = 0x65
    case audioMuteScreenBlank = 0x8D
    case audioTreble = 0x8F
    case audioBass = 0x91
    case audioBalanceLR = 0x93
    case audioProcessorMode = 0x94

    // OSD/Button Event Control
    case osd = 0xCA

    // Image Adjustment
    case sixAxisHueControlBlue = 0x9F
    case sixAxisHueControlCyan = 0x9E
    case sixAxisHueControlGreen = 0x9D
    case sixAxisHueControlMagenta = 0xA0
    case sixAxisHueControlRed = 0x9B
    case sixAxisHueControlYellow = 0x9C
    case sixAxisSaturationControlBlue = 0x5D
    case sixAxisSaturationControlCyan = 0x5C
    case sixAxisSaturationControlGreen = 0x5B
    case sixAxisSaturationControlMagenta = 0x5E
    case sixAxisSaturationControlRed = 0x59
    case sixAxisSaturationControlYellow = 0x5A
    case adjustZoom = 0x7C
    case autoColorSetup = 0x1F
    case autoSetup = 0x1E
    case autoSetupOnOff = 0xA2
    case backlightControlLegacy = 0x13
    case backlightLevelWhite = 0x6B
    case backlightLevelRed = 0x6D
    case backlightLevelGreen = 0x6F
    case backlightLevelBlue = 0x71
    case blockLutOperation = 0x75
    case clock = 0x0E
    case clockPhase = 0x3E
    case colorSaturation = 0x8A
    case colorTemperatureIncrement = 0x0B
    case colorTemperatureRequest = 0x0C
    case contrast = 0x12
    case displayApplication = 0xDC
    case fleshToneEnhancement = 0x11
    case focus = 0x1C
    case gamma = 0x72
    case grayScaleExpansion = 0x2E
    case horizontalMoire = 0x56
    case hue = 0x90
    case luminance = 0x10
    case lutSize = 0x73
    case screenOrientation = 0xAA
    case selectColorPreset = 0x14
    case sharpness = 0x87
    case singlePointLutOperation = 0x74
    case stereoVideoMode = 0xD4
    case tvBlackLevel = 0x92
    case tvContrast = 0x8E
    case tvSharpness = 0x8C
    case userColorVisionCompensation = 0x17
    case velocityScanModulation = 0x88
    case verticalMoire = 0x58
    case videoBlackLevelBlue = 0x70
    case videoBlackLevelGreen = 0x6E
    case videoBlackLevelRed = 0x6C
    case videoGainBlue = 0x1A
    case videoGainGreen = 0x18
    case videoGainRed = 0x16
    case windowBackground = 0x9A
    case windowControlOnOff = 0xA4
    case windowSelect = 0xA5
    case windowSize = 0xA6
    case windowTransparency = 0xA7

    // Preset Operations
    case restoreFactoryDefaults = 0x04
    case restoreFactoryLuminanceContrastDefaults = 0x05
    case restoreFactoryGeometryDefaults = 0x06
    case restoreFactoryColorDefaults = 0x08
    case restoreFactoryTvDefaults = 0x0A
    case settings = 0xB0

    // Manufacturer Specific
    case blackStabilizer = 0xF9 // LG 38UC99-W
    case colorPresetC = 0xE0
    case powerControl = 0xE1
    case topLeftScreenPurity = 0xE8
    case topRightScreenPurity = 0xE9
    case bottomLeftScreenPurity = 0xEA
    case bottomRightScreenPurity = 0xEB

    public static let brightness = luminance
  }

  static var sem = DispatchSemaphore(value: 1)
  static var dispatchGroups: [CGDirectDisplayID: (DispatchQueue, DispatchGroup)] = [:]
  static var framebufferDispatchGroups: [io_service_t: (DispatchQueue, DispatchGroup)] = [:]

  let displayId: CGDirectDisplayID
  let framebuffer: io_service_t
  let replyTransactionType: IOOptionBits
  var enabled: Bool = false

  deinit {
    assert(IOObjectRelease(self.framebuffer) == KERN_SUCCESS)
  }

  public init?(for displayId: CGDirectDisplayID, withReplyTransactionType replyTransactionType: IOOptionBits? = nil) {
    self.displayId = displayId

    guard let framebuffer = DDC.ioFramebufferPortFromDisplayId(displayId: displayId) else {
      return nil
    }

    self.framebuffer = framebuffer

    if let replyTransactionType = replyTransactionType {
      self.replyTransactionType = replyTransactionType
    } else if let replyTransactionType = DDC.supportedTransactionType() {
      self.replyTransactionType = replyTransactionType
    } else {
      os_log("No supported reply transaction type found for display with ID %u.", type: .error, displayId)
      return nil
    }
  }

  public convenience init?(for screen: NSScreen, withReplyTransactionType replyTransactionType: IOOptionBits? = nil) {
    guard let displayId = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
      return nil
    }

    self.init(for: displayId, withReplyTransactionType: replyTransactionType)
  }

  public func write(command: Command, value: UInt16, errorRecoveryWaitTime: UInt32? = nil) -> Bool {
    return self.write(command: command.rawValue, value: value, errorRecoveryWaitTime: errorRecoveryWaitTime)
  }

  public func write(command: UInt8, value: UInt16, errorRecoveryWaitTime: UInt32? = nil) -> Bool {
    let message: [UInt8] = [0x03, command, UInt8(value >> 8), UInt8(value & 0xFF)]
    var replyData: [UInt8] = []
    return self.sendMessage(message, replyData: &replyData, errorRecoveryWaitTime: errorRecoveryWaitTime ?? 50000) != nil
  }

  public func enableAppReport(_ enable: Bool = true, errorRecoveryWaitTime: UInt32? = nil) -> Bool {
    let message: [UInt8] = [0xF5, enable ? 0x01 : 0x00]
    var replyData: [UInt8] = []

    guard self.sendMessage(message, replyData: &replyData, errorRecoveryWaitTime: errorRecoveryWaitTime ?? 50000) != nil else {
      return false
    }

    self.enabled = true
    return true
  }

  public func capability(minReplyDelay: UInt64? = nil, errorRecoveryWaitTime: UInt32? = nil) -> String? {
    var block_length = 0

    var cString: [UInt8] = []

    var tries = 0

    while true {
      let offset = cString.count
      let message: [UInt8] = [0xF3, UInt8(offset >> 8), UInt8(offset & 0xFF)]
      var replyData: [UInt8] = Array(repeating: 0, count: 38)

      guard self.sendMessage(message, replyData: &replyData, minReplyDelay: minReplyDelay, errorRecoveryWaitTime: errorRecoveryWaitTime ?? 50000) != nil else {
        return nil
      }

      block_length = Int(replyData[1] & 0x7F) - 3

      if block_length < 0 {
        tries += 1

        if tries >= 3 {
          return nil
        }

        continue
      }

      tries = 0

      cString.append(contentsOf: replyData[5 ..< (block_length + 5)])

      if block_length < 32 {
        return String(cString: cString)
      }
    }
  }

  public func sendMessage(_ message: [UInt8], replyData: inout [UInt8], minReplyDelay: UInt64? = nil, errorRecoveryWaitTime: UInt32? = nil) -> IOI2CRequest? {
    var data: [UInt8] = [UInt8(0x51), UInt8(0x80 + message.count)] + message + [UInt8(0x6E)]

    for i in 0 ..< (data.count - 1) {
      data[data.count - 1] ^= data[i]
    }

    var request = IOI2CRequest()

    request.commFlags = 0
    request.sendAddress = 0x6E
    request.sendTransactionType = IOOptionBits(kIOI2CSimpleTransactionType)
    request.sendBytes = UInt32(data.count)
    request.sendBuffer = withUnsafePointer(to: &data[0]) { vm_address_t(bitPattern: $0) }

    if replyData.count == 0 {
      request.replyTransactionType = IOOptionBits(kIOI2CNoTransactionType)
      request.replyBytes = 0
    } else {
      request.minReplyDelay = minReplyDelay ?? 10

      request.replyAddress = 0x6F
      request.replySubAddress = 0x51
      request.replyTransactionType = self.replyTransactionType
      request.replyBytes = UInt32(replyData.count)
      request.replyBuffer = withUnsafePointer(to: &replyData[0]) { vm_address_t(bitPattern: $0) }
    }

    guard DDC.send(request: &request, to: self.framebuffer, errorRecoveryWaitTime: errorRecoveryWaitTime) else {
      return nil
    }

    if replyData.count > 0 {
      let checksum = replyData.last!
      var calculated = UInt8(0x50)

      for i in 0 ..< (replyData.count - 1) {
        calculated ^= replyData[i]
      }

      guard checksum == calculated else {
        os_log("Checksum of reply does not match. Expected %u, got %u.", type: .error, checksum, calculated)
        os_log("Response was: %{public}@", type: .debug, replyData.map { String(format: "%02X", $0) }.joined(separator: " "))
        return nil
      }
    }

    return request
  }

  // Send an “Identification Request” to check if DDC/CI is supported.
  public func supported(minReplyDelay: UInt64? = nil, errorRecoveryWaitTime: UInt32? = nil) -> Bool {
    var replyData: [UInt8] = Array(repeating: 0, count: 3)

    guard let request = self.sendMessage([0xF1], replyData: &replyData, minReplyDelay: minReplyDelay, errorRecoveryWaitTime: errorRecoveryWaitTime ?? 50000) else {
      return false
    }

    // If a “Null Message” is returned, DDC/CI is supported.
    return replyData == [UInt8(request.sendAddress), 0x80, 0xBE]
  }

  public func readVcp(command: UInt8, tries: UInt = 1, replyTransactionType _: IOOptionBits? = nil, minReplyDelay: UInt64? = nil, errorRecoveryWaitTime: UInt32? = nil) -> (UInt8, UInt8, UInt8, UInt8)? {
    assert(tries > 0)

    let message: [UInt8] = [0x01, command]

    var replyData: [UInt8] = Array(repeating: 0, count: 11)

    for i in 1 ... tries {
      guard self.sendMessage(message, replyData: &replyData, minReplyDelay: minReplyDelay, errorRecoveryWaitTime: errorRecoveryWaitTime ?? 40000) != nil else {
        continue
      }

      guard replyData[2] == 0x02 else {
        os_log("Got wrong response type for %{public}@. Expected %u, got %u.", type: .debug, String(reflecting: command), 0x02, replyData[2])
        os_log("Response was: %{public}@", type: .debug, replyData.map { String(format: "%02X", $0) }.joined(separator: " "))
        continue
      }

      guard replyData[3] == 0x00 else {
        os_log("Reading %{public}@ is not supported.", type: .debug, String(reflecting: command))
        return nil
      }

      if i > 1 {
        os_log("Reading %{public}@ took %u tries.", type: .debug, String(reflecting: command), i)
      }

      return (replyData[6], replyData[7], replyData[8], replyData[9])
    }

    os_log("Reading %{public}@ failed.", type: .error, String(reflecting: command))
    return nil
  }

  public func vcpVersion(replyTransactionType: IOOptionBits? = nil, minReplyDelay: UInt64? = nil) -> String? {
    guard let (_, _, sh, sl) = self.readVcp(command: DDC.Command.vcpVersion.rawValue, tries: 3, replyTransactionType: replyTransactionType, minReplyDelay: minReplyDelay) else {
      return nil
    }

    return "\(sh).\(sl)"
  }

  public func firmwareLevel(replyTransactionType: IOOptionBits? = nil, minReplyDelay: UInt64? = nil) -> String? {
    guard let (_, _, sh, sl) = self.readVcp(command: 0xC9, tries: 3, replyTransactionType: replyTransactionType, minReplyDelay: minReplyDelay) else {
      return nil
    }

    return "\(sh).\(sl)"
  }

  public func read(command: Command, tries: UInt = 1, replyTransactionType: IOOptionBits? = nil, minReplyDelay: UInt64? = nil, errorRecoveryWaitTime: UInt32? = nil) -> (UInt16, UInt16)? {
    return self.read(command: command.rawValue, tries: tries, replyTransactionType: replyTransactionType, minReplyDelay: minReplyDelay, errorRecoveryWaitTime: errorRecoveryWaitTime)
  }

  public func read(command: UInt8, tries: UInt = 1, replyTransactionType _: IOOptionBits? = nil, minReplyDelay: UInt64? = nil, errorRecoveryWaitTime: UInt32? = nil) -> (UInt16, UInt16)? {
    guard let (mh, ml, sh, sl) = readVcp(command: command, tries: tries, replyTransactionType: replyTransactionType, minReplyDelay: minReplyDelay, errorRecoveryWaitTime: errorRecoveryWaitTime) else {
      return nil
    }

    let maxValue = UInt16(mh << 8) + UInt16(ml)
    let currentValue = UInt16(sh << 8) + UInt16(sl)
    return (currentValue, maxValue)
  }

  private static func supportedTransactionType() -> IOOptionBits? {
    var ioIterator = io_iterator_t()

    guard IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceNameMatching("IOFramebufferI2CInterface"), &ioIterator) == KERN_SUCCESS else {
      return nil
    }

    defer {
      assert(IOObjectRelease(ioIterator) == KERN_SUCCESS)
    }

    while case let ioService = IOIteratorNext(ioIterator), ioService != 0 {
      var serviceProperties: Unmanaged<CFMutableDictionary>?

      guard IORegistryEntryCreateCFProperties(ioService, &serviceProperties, kCFAllocatorDefault, IOOptionBits()) == KERN_SUCCESS, serviceProperties != nil else {
        continue
      }

      let dict = serviceProperties!.takeRetainedValue() as NSDictionary

      if let types = dict[kIOI2CTransactionTypesKey] as? UInt64 {
        if (1 << kIOI2CDDCciReplyTransactionType) & types != 0 {
          os_log("kIOI2CDDCciReplyTransactionType is supported.", type: .debug)
          return IOOptionBits(kIOI2CDDCciReplyTransactionType)
        }

        if (1 << kIOI2CSimpleTransactionType) & types != 0 {
          os_log("kIOI2CSimpleTransactionType is supported.", type: .debug)
          return IOOptionBits(kIOI2CSimpleTransactionType)
        }
      }
    }

    return nil
  }

  static func send(request: inout IOI2CRequest, to framebuffer: io_service_t, errorRecoveryWaitTime: UInt32? = nil) -> Bool {
    DDC.sem.wait()

    if DDC.framebufferDispatchGroups[framebuffer] == nil {
      DDC.framebufferDispatchGroups[framebuffer] = (DispatchQueue(label: "ddc-framebuffer-\(framebuffer)"), DispatchGroup())
    }

    DDC.sem.signal()

    let (queue, group) = DDC.framebufferDispatchGroups[framebuffer]!

    group.wait()
    group.enter()

    defer {
      queue.async {
        if let errorRecoveryWaitTime = errorRecoveryWaitTime {
          usleep(errorRecoveryWaitTime)
        }

        group.leave()
      }
    }

    var busCount: IOItemCount = 0

    guard IOFBGetI2CInterfaceCount(framebuffer, &busCount) == KERN_SUCCESS else {
      os_log("Failed to get interface count for framebuffer with ID %u.", type: .error, framebuffer)
      return false
    }

    for bus: IOOptionBits in 0 ..< busCount {
      var interface = io_service_t()

      guard IOFBCopyI2CInterfaceForBus(framebuffer, bus, &interface) == KERN_SUCCESS else {
        os_log("Failed to get interface %u for framebuffer with ID %u.", type: .error, bus, framebuffer)
        continue
      }

      var connect: IOI2CConnectRef?
      guard IOI2CInterfaceOpen(interface, IOOptionBits(), &connect) == KERN_SUCCESS else {
        os_log("Failed to connect to interface %u for framebuffer with ID %u.", type: .error, bus, framebuffer)
        continue
      }

      defer { IOI2CInterfaceClose(connect, IOOptionBits()) }

      guard IOI2CSendRequest(connect, IOOptionBits(), &request) == KERN_SUCCESS else {
        os_log("Failed to send request to interface %u for framebuffer with ID %u.", type: .error, bus, framebuffer)
        continue
      }

      guard request.result == KERN_SUCCESS else {
        os_log("Request to interface %u for framebuffer with ID %u failed.", type: .error, bus, framebuffer)
        continue
      }

      return true
    }

    return false
  }

  static func servicePort(from displayId: CGDirectDisplayID) -> io_object_t? {
    if let port = DDC.servicePort(from: displayId, detectUnitNumber: true) {
      return port
    }

    return DDC.servicePort(from: displayId, detectUnitNumber: false)
  }

  static func servicePort(from displayId: CGDirectDisplayID, detectUnitNumber: Bool) -> io_object_t? {
    var portIterator = io_iterator_t()

    let status: kern_return_t = IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching(IOFRAMEBUFFER_CONFORMSTO), &portIterator)

    guard status == KERN_SUCCESS else {
      os_log("No matching services found for display with ID %u.", type: .error, displayId)
      return nil
    }

    defer {
      assert(IOObjectRelease(portIterator) == KERN_SUCCESS)
    }

    while case let port = IOIteratorNext(portIterator), port != 0 {
      let dict = IODisplayCreateInfoDictionary(port, IOOptionBits(kIODisplayOnlyPreferredName)).takeRetainedValue() as NSDictionary

      let valueForKey = { (k: String) in
        (dict[k] as? CFIndex).flatMap { Int32(exactly: $0) }.flatMap { UInt32(bitPattern: $0) } ?? 0
      }

      let portVendorId = valueForKey(kDisplayVendorID)
      let displayVendorId = CGDisplayVendorNumber(displayId)

      guard portVendorId == displayVendorId else {
        os_log("Service port vendor ID %u differs from display product ID %u.", type: .debug,
               portVendorId, displayVendorId)
        continue
      }

      let portProductId = valueForKey(kDisplayProductID)
      let displayProductId = CGDisplayModelNumber(displayId)

      guard portProductId == displayProductId else {
        os_log("Service port product ID %u differs from display product ID %u.", type: .debug,
               portProductId, displayProductId)
        continue
      }

      let portSerialNumber = valueForKey(kDisplaySerialNumber)
      let displaySerialNumber = CGDisplaySerialNumber(displayId)

      guard portSerialNumber == displaySerialNumber else {
        os_log("Service port serial number %u differs from display serial number %u.", type: .debug,
               portSerialNumber, displaySerialNumber)
        continue
      }

      if detectUnitNumber, let displayLocation = dict[kIODisplayLocationKey] as? NSString {
        // the unit number is the number right after the last "@" sign in the display location
        // swiftlint:disable:next force_try
        let regex = try! NSRegularExpression(pattern: "@([0-9]+)[^@]+$", options: [])
        if let match = regex.firstMatch(in: displayLocation as String, options: [],
                                        range: NSRange(location: 0, length: displayLocation.length))
        {
          let unitNumber = UInt32(displayLocation.substring(with: match.range(at: 1)))

          guard unitNumber == CGDisplayUnitNumber(displayId) else {
            continue
          }
        }
      }

      var name: io_name_t?
      let size = MemoryLayout.size(ofValue: name)
      if let framebufferName = (withUnsafeMutablePointer(to: &name) {
        $0.withMemoryRebound(to: CChar.self, capacity: size / MemoryLayout<CChar>.size) { n -> String? in
          guard IORegistryEntryGetName(port, n) == kIOReturnSuccess else {
            return nil
          }

          return String(cString: n)
        }
      }) {
        os_log("Framebuffer: %{public}@", type: .debug, framebufferName)
      }

      if let location = dict.object(forKey: kIODisplayLocationKey) as? String {
        os_log("Location: %{public}@", type: .debug, location)
      }

      os_log("Vendor ID: %u, Product ID: %u, Serial Number: %u", type: .debug,
             portVendorId, portProductId, portSerialNumber)
      os_log("Unit Number: %u", type: .debug, CGDisplayUnitNumber(displayId))
      os_log("Service Port: %u", type: .debug, port)

      return port
    }

    os_log("No service port found for display with ID %u.", type: .error, displayId)
    return nil
  }

  static func ioFramebufferPortFromDisplayId(displayId: CGDirectDisplayID) -> io_service_t? {
    if CGDisplayIsBuiltin(displayId) == boolean_t(truncating: true) {
      return nil
    }

    // MARK: This is experimental

    var servicePortUsingCGSServiceForDisplayNumber: io_service_t = 0
    CGSServiceForDisplayNumber(displayId, &servicePortUsingCGSServiceForDisplayNumber)
    if servicePortUsingCGSServiceForDisplayNumber != 0 {
      os_log("Using CGSServiceForDisplayNumber to acquire framebuffer port for %u.", type: .debug, displayId)
      return servicePortUsingCGSServiceForDisplayNumber
    }

    guard let servicePort = self.servicePort(from: displayId) else {
      return nil
    }

    var busCount: IOItemCount = 0
    guard IOFBGetI2CInterfaceCount(servicePort, &busCount) == KERN_SUCCESS, busCount >= 1 else {
      os_log("No framebuffer port found for display with ID %u.", type: .error, displayId)
      return nil
    }

    return servicePort
  }

  public func edid() -> EDID? {
    guard let servicePort = DDC.servicePort(from: displayId) else {
      return nil
    }

    defer {
      assert(IOObjectRelease(servicePort) == KERN_SUCCESS)
    }

    let dict = IODisplayCreateInfoDictionary(servicePort, IOOptionBits(kIODisplayOnlyPreferredName)).takeRetainedValue() as NSDictionary

    if let displayEDID = dict["IODisplayEDIDOriginal"] as? Data {
      let bytes = [UInt8](displayEDID)
      return EDID(data: bytes)
    }

    os_log("No EDID entry found for display with ID %u.", type: .error, self.displayId)
    return nil
  }

  public func edidOld() -> EDID? {
    let receiveBytes = { (count: Int, offset: UInt8) -> [UInt8]? in
      var data: [UInt8] = [offset]
      var replyData: [UInt8] = Array(repeating: 0, count: count)

      var request = IOI2CRequest()

      request.sendAddress = 0xA0
      request.sendTransactionType = IOOptionBits(kIOI2CSimpleTransactionType)
      request.sendBuffer = withUnsafePointer(to: &data[0]) { UInt(bitPattern: $0) }
      request.sendBytes = UInt32(data.count)

      request.replyAddress = 0xA1
      request.replyTransactionType = IOOptionBits(kIOI2CSimpleTransactionType)
      request.replyBuffer = withUnsafePointer(to: &replyData[0]) { UInt(bitPattern: $0) }
      request.replyBytes = UInt32(replyData.count)

      guard DDC.send(request: &request, to: self.framebuffer) else {
        return nil
      }

      return replyData
    }

    guard let edidData = receiveBytes(128, 0) else {
      os_log("Failed receiving EDID for display with ID %u.", type: .error, self.displayId)
      return nil
    }

    let extensions = Int(edidData[126])

    if extensions > 0 {
      guard let extensionData = receiveBytes(128 * extensions, 128) else {
        os_log("Failed receiving EDID extensions for display with ID %u.", type: .error, self.displayId)
        return nil
      }

      return EDID(data: edidData + extensionData)
    }

    return EDID(data: edidData)
  }
}
