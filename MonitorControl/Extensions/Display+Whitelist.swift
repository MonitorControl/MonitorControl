extension Display {
  enum WhitelistReason: Equatable {
    case longerDelay
    case hideOsd
    case specificPollingMode(mode: PollingMode)
    //TODO: implement specificPollingMode into whitelist

    // make enum with associated values equatable
    static func == (lhs: Display.WhitelistReason, rhs: Display.WhitelistReason) -> Bool {
      switch (lhs, rhs) {
      case (.longerDelay, .longerDelay):
        return true
      case (.hideOsd, .hideOsd):
        return true
      case let (.specificPollingMode(p1), .specificPollingMode(p2)):
        return p1.value == p2.value
      default:
        return false
      }
    }
  }

  static let whitelist: [UInt32: [UInt32: [WhitelistReason]]] = [
    7789: [
      30460: [.hideOsd, .longerDelay], // LG 38UC99-W over DisplayPort
      30459: [.hideOsd, .longerDelay], // LG 38UC99-W over HDMI
    ],
  ]

  var hideOsd: Bool {
    guard let vendor = self.identifier.vendorNumber, let model = self.identifier.modelNumber else {
      return false
    }

    return Display.whitelist[vendor]?[model]?.contains(.hideOsd) ?? false
  }

  var needsLongerDelay: Bool {
    guard let vendor = self.identifier.vendorNumber, let model = self.identifier.modelNumber else {
      return false
    }

    return Display.whitelist[vendor]?[model]?.contains(.longerDelay) ?? false
  }
}
