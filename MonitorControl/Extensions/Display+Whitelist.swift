extension Display {
  enum WhitelistReason {
    case longerDelay
    case hideOsd
  }

  static let whitelist: [UInt32: [UInt32: [WhitelistReason]]] = [
    7789: [30460: [.hideOsd, .longerDelay]], // LG 38UC99-W
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
