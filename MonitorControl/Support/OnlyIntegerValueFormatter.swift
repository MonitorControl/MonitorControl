import Cocoa

class OnlyIntegerValueFormatter: NumberFormatter {
  override func isPartialStringValid(_ partialString: String, newEditingString _: AutoreleasingUnsafeMutablePointer<NSString?>?, errorDescription _: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool {
    if partialString.isEmpty {
      return true
    }

    if partialString.count > 3 {
      return false
    }

    return Int(partialString) != nil
  }
}
