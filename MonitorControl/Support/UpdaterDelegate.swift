//  Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others

import Foundation
import Sparkle

class UpdaterDelegate: NSObject, SPUUpdaterDelegate {
  func allowedChannels(for _: SPUUpdater) -> Set<String> {
    prefs.bool(forKey: PrefKey.isBetaChannel.rawValue) ? Set(["beta"]) : Set([])
  }
}
