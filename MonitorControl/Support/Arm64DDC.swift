//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Foundation
import IOKit

class Arm64DDC: NSObject {
  public struct DisplayService {
    var displayID: CGDirectDisplayID = 0
    var service: IOAVService?
    var serviceLocation: Int = 0
    var isDiscouraged: Bool = false
    var isDummy: Bool = false
  }

  #if arch(arm64)
    public static let isArm64: Bool = true
  #else
    public static let isArm64: Bool = false
  #endif

  // This matches Displays to the right IOAVService
  public static func getServiceMatches(displayIDs: [CGDirectDisplayID]) -> [DisplayService] {
    let ioregServicesForMatching = self.getIoregServicesForMatching()
    var matchedDisplayServices: [DisplayService] = []
    var scoredCandidateDisplayServices: [Int: [DisplayService]] = [:]
    for displayID in displayIDs {
      for ioregServiceForMatching in ioregServicesForMatching {
        let score = self.ioregMatchScore(displayID: displayID, ioregEdidUUID: ioregServiceForMatching.edidUUID, ioregProductName: ioregServiceForMatching.productName, ioregSerialNumber: ioregServiceForMatching.serialNumber, serviceLocation: ioregServiceForMatching.serviceLocation)
        let isDiscouraged = self.checkIfDiscouraged(ioregService: ioregServiceForMatching)
        let isDummy = self.checkIfDummy(ioregService: ioregServiceForMatching)
        let displayService = DisplayService(displayID: displayID, service: ioregServiceForMatching.service, serviceLocation: ioregServiceForMatching.serviceLocation, isDiscouraged: isDiscouraged, isDummy: isDummy)
        if scoredCandidateDisplayServices[score] == nil {
          scoredCandidateDisplayServices[score] = []
        }
        scoredCandidateDisplayServices[score]?.append(displayService)
      }
    }
    var takenServiceLocations: [Int] = []
    var takenDisplayIDs: [CGDirectDisplayID] = []
    for score in stride(from: self.MAX_MATCH_SCORE, to: 0, by: -1) {
      if let scoredCandidateDisplayService = scoredCandidateDisplayServices[score] {
        for candidateDisplayService in scoredCandidateDisplayService {
          if !(takenDisplayIDs.contains(candidateDisplayService.displayID) || takenServiceLocations.contains(candidateDisplayService.serviceLocation)) {
            takenDisplayIDs.append(candidateDisplayService.displayID)
            takenServiceLocations.append(candidateDisplayService.serviceLocation)
            matchedDisplayServices.append(candidateDisplayService)
          }
        }
      }
    }
    return matchedDisplayServices
  }

  // Perform DDC read
  public static func read(service: IOAVService?, command: UInt8, tries: UInt8 = 3, minReplyDelay: UInt32 = 10000) -> (current: UInt16, max: UInt16)? {
    var values: (UInt16, UInt16)?
    var send: [UInt8] = [command]
    var reply = [UInt8](repeating: 0, count: 11)
    if Arm64DDC.performDDCCommunication(service: service, send: &send, reply: &reply, readSleepTime: minReplyDelay, numOfRetryAttemps: tries) {
      let max = UInt16(reply[6]) * 256 + UInt16(reply[7])
      let current = UInt16(reply[8]) * 256 + UInt16(reply[9])
      values = (current, max)
    } else {
      values = nil
    }
    return values
  }

  // Perform DDC write
  public static func write(service: IOAVService?, command: UInt8, value: UInt16) -> Bool {
    var send: [UInt8] = [command, UInt8(value >> 8), UInt8(value & 255)]
    var reply: [UInt8] = []
    return Arm64DDC.performDDCCommunication(service: service, send: &send, reply: &reply)
  }

  // Performs DDC read or write
  public static func performDDCCommunication(service: IOAVService?, send: inout [UInt8], reply: inout [UInt8], writeSleepTime: UInt32 = 10000, numofWriteCycles: UInt8 = 2, readSleepTime: UInt32 = 10000, numOfRetryAttemps: UInt8 = 3, retrySleepTime: UInt32 = 20000) -> Bool {
    var success: Bool = false
    guard service != nil else {
      return success
    }
    var checkedsend: [UInt8] = [UInt8(0x80 | (send.count + 1)), UInt8(send.count)] + send + [0]
    checkedsend[checkedsend.count - 1] = self.checksum(chk: send.count == 1 ? 0x6E : 0x6E ^ 0x51, data: &checkedsend, start: 0, end: checkedsend.count - 2)
    for _ in 1 ... numOfRetryAttemps {
      for _ in 1 ... numofWriteCycles {
        usleep(writeSleepTime)
        if IOAVServiceWriteI2C(service, 0x37, 0x51, &checkedsend, UInt32(checkedsend.count)) == 0 {
          success = true
        }
      }
      if reply.count > 0 {
        usleep(readSleepTime)
        if IOAVServiceReadI2C(service, 0x37, 0x51, &reply, UInt32(reply.count)) == 0 {
          if self.checksum(chk: 0x50, data: &reply, start: 0, end: reply.count - 2) == reply[reply.count - 1] {
            success = true
          } else {
            success = false
          }
        }
      }
      if success {
        return success
      }
      usleep(retrySleepTime)
    }
    return success
  }

  // -------

  private struct IOregService {
    var edidUUID: String = ""
    var manufacturerID: String = ""
    var productName: String = ""
    var serialNumber: Int64 = 0
    var location: String = ""
    var transportUpstream: String = ""
    var transportDownstream: String = ""
    var service: IOAVService?
    var serviceLocation: Int = 0
  }

  private static let MAX_MATCH_SCORE: Int = 13

  // DDC checksum calculator
  private static func checksum(chk: UInt8, data: inout [UInt8], start: Int, end: Int) -> UInt8 {
    var chkd: UInt8 = chk
    for i in start ... end {
      chkd ^= data[i]
    }
    return chkd
  }

  // Scores the likelihood of a display match based on EDID UUID, ProductName and SerialNumber from in ioreg, compared to DisplayCreateInfoDictionary.
  private static func ioregMatchScore(displayID: CGDirectDisplayID, ioregEdidUUID: String, ioregProductName: String = "", ioregSerialNumber: Int64 = 0, serviceLocation: Int = 0) -> Int {
    var matchScore: Int = 0
    if let dictionary = (CoreDisplay_DisplayCreateInfoDictionary(displayID))?.takeRetainedValue() as NSDictionary? {
      if let kDisplayYearOfManufacture = dictionary[kDisplayYearOfManufacture] as? Int64, let kDisplayWeekOfManufacture = dictionary[kDisplayWeekOfManufacture] as? Int64, let kDisplayVendorID = dictionary[kDisplayVendorID] as? Int64, let kDisplayProductID = dictionary[kDisplayProductID] as? Int64, let kDisplayVerticalImageSize = dictionary[kDisplayVerticalImageSize] as? Int64, let kDisplayHorizontalImageSize = dictionary[kDisplayHorizontalImageSize] as? Int64 {
        struct KeyLoc {
          var key: String
          var loc: Int
        }
        let edidUUIDSearchKeys: [KeyLoc] = [
          // Vendor ID
          KeyLoc(key: String(format: "%04x", UInt16(max(0, min(kDisplayVendorID, 256 * 256 - 1)))).uppercased(), loc: 0),
          // Product ID
          KeyLoc(key: String(format: "%02x", UInt8((UInt16(max(0, min(kDisplayProductID, 256 * 256 - 1))) >> (0 * 8)) & 0xFF)).uppercased()
            + String(format: "%02x", UInt8((UInt16(max(0, min(kDisplayProductID, 256 * 256 - 1))) >> (1 * 8)) & 0xFF)).uppercased(), loc: 4),
          // Manufacture date
          KeyLoc(key: String(format: "%02x", UInt8(max(0, min(kDisplayWeekOfManufacture, 256 - 1)))).uppercased()
            + String(format: "%02x", UInt8(max(0, min(kDisplayYearOfManufacture - 1990, 256 - 1)))).uppercased(), loc: 19),
          // Image size
          KeyLoc(key: String(format: "%02x", UInt8(max(0, min(kDisplayHorizontalImageSize / 10, 256 - 1)))).uppercased()
            + String(format: "%02x", UInt8(max(0, min(kDisplayVerticalImageSize / 10, 256 - 1)))).uppercased(), loc: 30),
        ]
        for searchKey in edidUUIDSearchKeys where searchKey.key != "0000" && searchKey.key == ioregEdidUUID.prefix(searchKey.loc + 4).suffix(4) {
          matchScore += 2
        }
      }
      if ioregProductName != "", let nameList = dictionary["DisplayProductName"] as? [String: String], let name = nameList["en_US"] ?? nameList.first?.value, name.lowercased() == ioregProductName.lowercased() {
        matchScore += 2
      }
      if ioregSerialNumber != 0, let serial = dictionary[kDisplaySerialNumber] as? Int64, serial == ioregSerialNumber {
        matchScore += 2
      }
      if serviceLocation == displayID {
        matchScore += 1
      }
    }
    return matchScore
  }

  // Iterate to the next AppleCLCD2 or DCPAVServiceProxy item in the ioreg tree and return the name and corresponding service
  private static func ioregIterateToNextObjectOfInterest(interests _: [String], iterator: inout io_iterator_t) -> (name: String, service: io_service_t)? {
    var objectName: String = ""
    var service: io_service_t = IO_OBJECT_NULL
    let name = UnsafeMutablePointer<CChar>.allocate(capacity: MemoryLayout<io_name_t>.size)
    defer {
      name.deallocate()
    }
    while true {
      service = IOIteratorNext(iterator)
      guard service != MACH_PORT_NULL else {
        service = IO_OBJECT_NULL
        break
      }
      guard IORegistryEntryGetName(service, name) == KERN_SUCCESS else {
        service = IO_OBJECT_NULL
        break
      }
      if String(cString: name) == "AppleCLCD2" || String(cString: name) == "DCPAVServiceProxy" {
        objectName = String(cString: name)
        return (objectName, service)
      }
    }
    return nil
  }

  // Returns EDID UUDI, Product Name and Serial Number in an IOregService if it is found using the provided io_service_t pointing to a AppleCDC2 item in the ioreg tree
  private static func getIORegServiceAppleCDC2Properties(service: io_service_t) -> IOregService {
    var ioregService = IOregService()
    if let unmanagedEdidUUID = IORegistryEntryCreateCFProperty(service, CFStringCreateWithCString(kCFAllocatorDefault, "EDID UUID", kCFStringEncodingASCII), kCFAllocatorDefault, IOOptionBits(kIORegistryIterateRecursively)), let edidUUID = unmanagedEdidUUID.takeRetainedValue() as? String {
      ioregService.edidUUID = edidUUID
    }
    if let unmanagedDisplayAttrs = IORegistryEntryCreateCFProperty(service, CFStringCreateWithCString(kCFAllocatorDefault, "DisplayAttributes", kCFStringEncodingASCII), kCFAllocatorDefault, IOOptionBits(kIORegistryIterateRecursively)), let displayAttrs = unmanagedDisplayAttrs.takeRetainedValue() as? NSDictionary, let productAttrs = displayAttrs.value(forKey: "ProductAttributes") as? NSDictionary {
      if let manufacturerID = productAttrs.value(forKey: "ManufacturerID") as? String {
        ioregService.manufacturerID = manufacturerID
      }
      if let productName = productAttrs.value(forKey: "ProductName") as? String {
        ioregService.productName = productName
      }
      if let serialNumber = productAttrs.value(forKey: "SerialNumber") as? Int64 {
        ioregService.serialNumber = serialNumber
      }
    }
    if let unmanagedTransport = IORegistryEntryCreateCFProperty(service, CFStringCreateWithCString(kCFAllocatorDefault, "Transport", kCFStringEncodingASCII), kCFAllocatorDefault, IOOptionBits(kIORegistryIterateRecursively)), let transport = unmanagedTransport.takeRetainedValue() as? NSDictionary {
      if let upstream = transport.value(forKey: "Upstream") as? String {
        ioregService.transportUpstream = upstream
      }
      if let downstream = transport.value(forKey: "Downstream") as? String {
        ioregService.transportDownstream = downstream
      }
    }
    return ioregService
  }

  // Sets up the service in an IOregService if it is found using the provided io_service_t pointing to a DCPAVServiceProxy item in the ioreg tree
  private static func setIORegServiceDCPAVServiceProxy(service: io_service_t, ioregService: inout IOregService) {
    if let unmanagedLocation = IORegistryEntryCreateCFProperty(service, CFStringCreateWithCString(kCFAllocatorDefault, "Location", kCFStringEncodingASCII), kCFAllocatorDefault, IOOptionBits(kIORegistryIterateRecursively)), let location = unmanagedLocation.takeRetainedValue() as? String {
      ioregService.location = location
      if location == "External" {
        ioregService.service = IOAVServiceCreateWithService(kCFAllocatorDefault, service)?.takeRetainedValue() as IOAVService
      }
    }
  }

  // Returns IOAVSerivces with associated display properties for matching logic
  private static func getIoregServicesForMatching() -> [IOregService] {
    var serviceLocation: Int = 0
    var ioregServicesForMatching: [IOregService] = []
    let ioregRoot: io_registry_entry_t = IORegistryGetRootEntry(kIOMasterPortDefault)
    var iterator = io_iterator_t()
    var ioregService = IOregService()
    guard IORegistryEntryCreateIterator(ioregRoot, "IOService", IOOptionBits(kIORegistryIterateRecursively), &iterator) == KERN_SUCCESS else {
      return ioregServicesForMatching
    }
    while true {
      if let objectOfInterest = ioregIterateToNextObjectOfInterest(interests: ["AppleCLCD2", "DCPAVServiceProxy"], iterator: &iterator) {
        if objectOfInterest.name == "AppleCLCD2", objectOfInterest.service != IO_OBJECT_NULL {
          ioregService = self.getIORegServiceAppleCDC2Properties(service: objectOfInterest.service)
          serviceLocation += 1
          ioregService.serviceLocation = serviceLocation
        }
        if objectOfInterest.name == "DCPAVServiceProxy", objectOfInterest.service != IO_OBJECT_NULL {
          self.setIORegServiceDCPAVServiceProxy(service: objectOfInterest.service, ioregService: &ioregService)
          ioregServicesForMatching.append(ioregService)
        }
      } else {
        break
      }
    }
    return ioregServicesForMatching
  }

  // Check if display is a dummy
  private static func checkIfDummy(ioregService: IOregService) -> Bool {
    // This is a well known dummy plug
    if ioregService.manufacturerID == "AOC", ioregService.productName == "28E850" {
      return true
    }
    return false
  }

  // Check if it is problematic to enable DDC on the display
  private static func checkIfDiscouraged(ioregService: IOregService) -> Bool {
    var modelIdentifier: String = ""
    let platformExpertDevice = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
    if let modelData = IORegistryEntryCreateCFProperty(platformExpertDevice, "model" as CFString, kCFAllocatorDefault, 0).takeRetainedValue() as? Data, let modelIdentifierCString = String(data: modelData, encoding: .utf8)?.cString(using: .utf8) {
      modelIdentifier = String(cString: modelIdentifierCString)
    }
    // First service location of Mac Mini HDMI is broken for DDC communication
    if ioregService.transportDownstream == "HDMI", ioregService.serviceLocation == 1, modelIdentifier == "Macmini9,1" {
      return true
    }
    return false
  }
}
