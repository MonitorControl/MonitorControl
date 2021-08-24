import Foundation

extension Display: Equatable {
  static func == (lhs: Display, rhs: Display) -> Bool {
    return lhs.identifier == rhs.identifier
  }
}
