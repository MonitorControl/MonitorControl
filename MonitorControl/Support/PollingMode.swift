import Foundation

enum PollingMode {
  case none
  case minimal
  case normal
  case heavy
  case custom(value: Int)

  var value: Int {
    switch self {
    case .none:
      return 0
    case .minimal:
      return 3
    case .normal:
      return 6
    case .heavy:
      return 30
    case let .custom(val):
      return val
    }
  }
}
