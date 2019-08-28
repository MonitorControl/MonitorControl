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
      return 5
    case .normal:
      return 10
    case .heavy:
      return 100
    case let .custom(val):
      return val
    }
  }
}
